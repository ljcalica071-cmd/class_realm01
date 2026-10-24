import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:class_realm/core/config/env_config.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:class_realm/models/user_model.dart' as custom;
import 'package:class_realm/data/datasources/mock/mock_database.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/core/services/email_verification_service.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/services/firebase_auth_admin_service.dart';
import 'package:class_realm/core/services/rate_limit_service.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';

class FirstLoginOtpVerification {
  const FirstLoginOtpVerification({
    required this.verified,
    this.reason,
    this.attemptsRemaining,
    this.retryAfter = 0,
  });

  final bool verified;
  final String? reason;
  final int? attemptsRemaining;
  final int retryAfter;
}

class LoginAttemptException implements Exception {
  const LoginAttemptException(
    this.message, {
    this.invalidCredentials = false,
    this.providerRateLimited = false,
    this.retryAfterSeconds,
  });

  final String message;
  final bool invalidCredentials;
  final bool providerRateLimited;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}

class AdminTeacherException implements Exception {
  final String message;
  final int? failedAttempts;
  final int? remainingAttempts;
  final bool maxAttemptsExceeded;

  const AdminTeacherException(
    this.message, {
    this.failedAttempts,
    this.remainingAttempts,
    this.maxAttemptsExceeded = false,
  });

  @override
  String toString() => message;
}

class AuthRepository {
  static final AuthRepository instance = AuthRepository._internal();
  AuthRepository._internal();

  firebase.FirebaseAuth get _firebaseAuth => firebase.FirebaseAuth.instance;
  SupabaseClient get _supabaseClient => Supabase.instance.client;

  custom.UserModel? _currentUser;
  custom.UserModel? get currentUser =>
      _currentUser ?? MockDatabase.instance.currentUser ?? LocalStorageService.getCachedUser();

  void setCurrentUser(custom.UserModel user) {
    _currentUser = user;
    MockDatabase.instance.currentUser = user;
    LocalStorageService.saveUser(user);
  }

  /// Synchronously hydrates the cached user model before the first frame renders (e.g. on F5 refresh).
  /// Enforces wall-clock inactivity checks (>= 30 mins triggers expiration).
  custom.UserModel? hydrateCachedSessionSync() {
    final lastInteraction = LocalStorageService.getLastInteraction();
    if (lastInteraction != null) {
      final diff = DateTime.now().difference(lastInteraction);
      if (diff >= const Duration(minutes: 30)) {
        LocalStorageService.clearCachedUser();
        _currentUser = null;
        MockDatabase.instance.currentUser = null;
        clearWarmSession();
        return null;
      }
    }
    final cached = LocalStorageService.getCachedUser();
    if (cached != null) {
      _currentUser = cached;
      MockDatabase.instance.currentUser = cached;
      markWarmSession();
      return cached;
    }
    return null;
  }

  // Login
  Future<custom.UserModel?> authenticate(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    // The parent prototype remains available until its real account flow is enabled.
    if (cleanEmail == 'parent') {
      _currentUser = custom.UserModel(
        id: 'usr_parent',
        username: email,
        fullName: 'Mock Parent',
        email: email,
        role: custom.UserRole.parent,
      );
      MockDatabase.instance.currentUser = _currentUser;
      return _currentUser;
    }

    // 1. Check Device-Wide Lockout (10 failed attempts within 5 minutes)
    final deviceLimit = await RateLimitService.instance.checkStatus(
      feature: 'login_device',
      targetIdentifier: 'device_only',
      maxAttempts: 10,
    );
    if (deviceLimit.isLocked) {
      throw LoginAttemptException(
        'Device locked due to multiple failed login attempts. Try again in ${deviceLimit.formattedCountdown}.',
        providerRateLimited: true,
        retryAfterSeconds: deviceLimit.remainingSeconds,
      );
    }

    // 2. Check Account-Specific Lockout on this Device (5 failed attempts within 5 minutes)
    final accountLimit = await RateLimitService.instance.checkStatus(
      feature: 'login_account',
      targetIdentifier: cleanEmail,
      maxAttempts: 5,
    );
    if (accountLimit.isLocked) {
      throw LoginAttemptException(
        'Account locked on this device due to multiple failed attempts. Try again in ${accountLimit.formattedCountdown}.',
        providerRateLimited: true,
        retryAfterSeconds: accountLimit.remainingSeconds,
      );
    }

    // Real Firebase Authentication for all users (Admin, Teacher, etc.)
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (userCredential.user != null) {
        _currentUser = await _getUserFromSupabase(userCredential.user!.uid);
        if (_currentUser == null) {
          throw Exception(
            "Firebase login succeeded, but user data was not found in Supabase Database. Please contact administrator.",
          );
        }
        if (_currentUser!.isArchived || _currentUser!.status == custom.AccountStatus.archived) {
          await _firebaseAuth.signOut();
          await LocalStorageService.clearAuth();
          _currentUser = null;
          throw const LoginAttemptException(
            'This account has been archived. Please contact your school administrator.',
            invalidCredentials: true,
          );
        }

        // Authentication succeeded! Reset failed attempt counters on this device
        unawaited(RateLimitService.instance.clearRateLimit(
          feature: 'login_account',
          targetIdentifier: cleanEmail,
        ));
        unawaited(RateLimitService.instance.clearRateLimit(
          feature: 'login_device',
          targetIdentifier: 'device_only',
        ));

        await LocalStorageService.saveUser(_currentUser!);
        MockDatabase.instance.currentUser = _currentUser;
        unawaited(startSessionLog(_currentUser!));
        return _currentUser;
      }
    } on firebase.FirebaseAuthException catch (e) {
      // Record failure on both account-level and device-level progressive trackers
      final accFail = await RateLimitService.instance.recordFailure(
        feature: 'login_account',
        targetIdentifier: cleanEmail,
        maxAttempts: 5,
      );
      final devFail = await RateLimitService.instance.recordFailure(
        feature: 'login_device',
        targetIdentifier: 'device_only',
        maxAttempts: 10,
      );

      if (accFail.isLocked) {
        throw LoginAttemptException(
          'Too many failed attempts. Account locked on this device for ${accFail.formattedCountdown}.',
          providerRateLimited: true,
          retryAfterSeconds: accFail.remainingSeconds,
        );
      }
      if (devFail.isLocked) {
        throw LoginAttemptException(
          'Too many failed attempts across accounts. Device locked for ${devFail.formattedCountdown}.',
          providerRateLimited: true,
          retryAfterSeconds: devFail.remainingSeconds,
        );
      }

      if (e.code == 'user-disabled') {
        throw const LoginAttemptException(
          'This account has been disabled or archived. Please contact your school administrator.',
          invalidCredentials: true,
        );
      }
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-email') {
        final remaining = accFail.attemptsRemaining;
        throw LoginAttemptException(
          'Invalid email or password. $remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout.',
          invalidCredentials: true,
        );
      }
      if (e.code == 'too-many-requests') {
        throw const LoginAttemptException(
          'Too many failed attempts. Try again after 5 minutes.',
          providerRateLimited: true,
        );
      }
      throw LoginAttemptException('Authentication Error: ${e.message}');
    } catch (e) {
      if (e is LoginAttemptException) rethrow;
      throw Exception(e.toString());
    }
    return null;
  }

  // Fast Login / Restore Session
  Future<custom.UserModel?> restoreSession() async {
    // Invalidate any legacy session with the purged old admin ID
    final cached = LocalStorageService.getCachedUser();
    if (cached != null && cached.id == 'uiR8FjHtAWezyZ2dADnOfsHfBz32') {
      await LocalStorageService.clearAuth();
    }

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      // 1. Check local cache first for instant load
      final cachedUser = LocalStorageService.getCachedUser();
      if (cachedUser != null && cachedUser.id == firebaseUser.uid) {
        _currentUser = cachedUser;
        MockDatabase.instance.currentUser = _currentUser;

        // 2. Refresh from Supabase to keep profile fields (e.g. gender, name, status) strictly synchronized
        try {
          final updatedUser = await _getUserFromSupabase(firebaseUser.uid);
          if (updatedUser != null) {
            _currentUser = updatedUser;
            MockDatabase.instance.currentUser = _currentUser;
            await LocalStorageService.saveUser(updatedUser);
          }
        } catch (_) {}

        if (_currentUser != null &&
            (_currentUser!.isArchived ||
                _currentUser!.status == custom.AccountStatus.archived)) {
          await _firebaseAuth.signOut();
          await LocalStorageService.clearAuth();
          _currentUser = null;
          return null;
        }

        unawaited(startSessionLog(_currentUser!));
        return _currentUser;
      }

      // If no cache, perform standard fetch
      try {
        _currentUser = await _getUserFromSupabase(firebaseUser.uid);
        if (_currentUser != null) {
          if (_currentUser!.isArchived ||
              _currentUser!.status == custom.AccountStatus.archived) {
            await _firebaseAuth.signOut();
            await LocalStorageService.clearAuth();
            _currentUser = null;
            return null;
          }
          await LocalStorageService.saveUser(_currentUser!);
          MockDatabase.instance.currentUser = _currentUser;
          unawaited(startSessionLog(_currentUser!));
          return _currentUser;
        }
      } catch (e) {
        debugPrint('Failed to restore session: $e');
        // Token might be expired or user deleted in Supabase
        await _firebaseAuth.signOut();
        await LocalStorageService.clearAuth();
      }
    }
    return null;
  }

  // Fetch User from Supabase
  Future<custom.UserModel?> _getUserFromSupabase(String uid) async {
    try {
      final userResp = await _supabaseClient
          .from('users')
          .select()
          .eq('id', uid)
          .single();

      final role = userResp['role'] as String;
      final bool isArchived = userResp['is_archived'] == true;

      if (role == 'teacher') {
        final results = await Future.wait([
          _supabaseClient
              .from('teacher_settings')
              .select()
              .eq('teacher_id', uid)
              .single(),
          _supabaseClient
              .from('teacher_profiles')
              .select()
              .eq('teacher_id', uid)
              .single(),
        ]);
        final infoResp = results[0];
        final profileResp = results[1];

        return custom.UserModel(
          id: uid,
          username: userResp['email'],
          fullName: '${profileResp['first_name']} ${profileResp['last_name']}',
          email: userResp['email'],
          role: custom.UserRole.teacher,
          firstName: profileResp['first_name'],
          lastName: profileResp['last_name'],
          middleName: profileResp['middle_name'],
          gender: profileResp['gender'],
          birthday: profileResp['birthday'] != null
              ? DateTime.parse(profileResp['birthday'].toString())
              : null,
          subjectSpecialization: infoResp['subject_specialization'],
          facebookLink: infoResp['facebook_link'],
          isFacebookPublic: infoResp['is_facebook_public'] ?? false,
          contactNumber: infoResp['contact_number'],
          isPhonePublic: infoResp['is_phone_public'] ?? false,
          consultationHours: infoResp['consultation_hours'],
          isSetupComplete: infoResp['is_setup_complete'],
          status: _parseStatus(infoResp['status']),
          isArchived: isArchived,
        );
      } else if (role == 'admin') {
        final email = userResp['email'] as String;
        final profileResp = await _supabaseClient
            .from('admin_profiles')
            .select('first_name, last_name')
            .eq('admin_id', uid)
            .maybeSingle();
        final profileName = [
          profileResp?['first_name'],
          profileResp?['last_name'],
        ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');

        return custom.UserModel(
          id: uid,
          username: email,
          fullName: profileName.isNotEmpty
              ? profileName
              : 'School Administrator',
          email: email,
          role: custom.UserRole.admin,
          status: custom.AccountStatus.active,
          isArchived: isArchived,
        );
      } else if (role == 'student') {
        final results = await Future.wait<dynamic>(<Future<dynamic>>[
          _supabaseClient
              .from('student_settings')
              .select(
                'student_id, status, student_profiles!inner(student_id, lrn, first_name, middle_name, last_name, birthday, gender)',
              )
              .eq('student_id', uid)
              .single(),
          _supabaseClient
              .from('student_enrollments')
              .select('subject_offerings(sections(section_name, grade_level))')
              .eq('student_id', uid)
              .eq('status', 'enrolled')
              .limit(1)
              .maybeSingle(),
        ]);
        final infoResp = results[0] as Map<String, dynamic>?;
        final profileRaw = infoResp?['student_profiles'];
        final Map<String, dynamic> profile = profileRaw is List
            ? (profileRaw.isNotEmpty
                  ? Map<String, dynamic>.from(profileRaw.first as Map)
                  : <String, dynamic>{})
            : Map<String, dynamic>.from(profileRaw as Map? ?? {});
        final enrollment = results[1] as Map<String, dynamic>?;
        final offeringRaw = enrollment?['subject_offerings'];
        final offering = offeringRaw is List
            ? (offeringRaw.isNotEmpty ? offeringRaw.first : null)
            : offeringRaw;
        final sectionRaw = offering?['sections'];
        final section = sectionRaw is List
            ? (sectionRaw.isNotEmpty ? sectionRaw.first : null)
            : sectionRaw;

        return custom.UserModel(
          id: uid,
          username: profile['lrn']?.toString() ?? userResp['email'],
          fullName: [
            profile['first_name'],
            profile['middle_name'],
            profile['last_name'],
          ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
          email: userResp['email'],
          role: custom.UserRole.student,
          studentId: uid,
          lrn: profile['lrn']?.toString(),
          departmentOrSection: section is Map
              ? section['section_name']?.toString()
              : null,
          firstName: profile['first_name']?.toString(),
          middleName: profile['middle_name']?.toString(),
          lastName: profile['last_name']?.toString(),
          gender: profile['gender']?.toString(),
          birthday: profile['birthday'] == null
              ? null
              : DateTime.tryParse(profile['birthday'].toString()),
          gradeLevel: section is Map
              ? section['grade_level']?.toString()
              : null,
          status: _parseStatus(infoResp?['status']?.toString() ?? 'active'),
          isArchived: isArchived,
        );
      } else if (role == 'parent') {
        final results = await Future.wait<dynamic>(<Future<dynamic>>[
          _supabaseClient
              .from('parent_profiles')
              .select(
                'parent_id, first_name, middle_name, last_name, contact_number, birthday, status',
              )
              .eq('parent_id', uid)
              .maybeSingle(),
          _supabaseClient
              .from('parent_student_links')
              .select('student_id, relationship')
              .eq('parent_id', uid),
        ]);
        final profileResp = results[0] as Map<String, dynamic>?;
        final linksResp = results[1];

        final links = (linksResp as List?) ?? [];
        final linkedStudentId = links.isNotEmpty
            ? links.first['student_id']?.toString()
            : null;
        final relationship = links.isNotEmpty
            ? links.first['relationship']?.toString()
            : null;

        final firstName = profileResp?['first_name']?.toString() ?? '';
        final middleName = profileResp?['middle_name']?.toString();
        final lastName = profileResp?['last_name']?.toString() ?? '';
        final contactNumber = profileResp?['contact_number']?.toString();
        final birthdayStr = profileResp?['birthday']?.toString();
        final statusStr =
            profileResp?['status']?.toString() ?? 'pending_first_login';

        final fullName = [
          firstName,
          if (middleName != null && middleName.isNotEmpty) middleName,
          lastName,
        ].join(' ');

        return custom.UserModel(
          id: uid,
          username: userResp['email'] ?? contactNumber,
          fullName: fullName.trim().isNotEmpty
              ? fullName
              : (userResp['email'] ?? 'Parent'),
          email: userResp['email'] ?? '',
          role: custom.UserRole.parent,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          contactNumber: contactNumber,
          birthday: birthdayStr != null ? DateTime.tryParse(birthdayStr) : null,
          parentGuardianRelationship: relationship,
          linkedStudentId: linkedStudentId,
          status: _parseStatus(statusStr),
          isArchived: isArchived,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Failed to load user profile from Supabase: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout([String? reason]) async {
    final userToLogOut = _currentUser;
    final sessionId = LocalStorageService.getActiveSessionId();
    await endSession(reason ?? 'manual', userToLogOut, sessionId);
    _currentUser = null;
    await LocalStorageService.clearAuth();
    clearWarmSession();
    AppDataCache.instance.clearAll();
    // Attempt to sign out of Firebase
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}

    // Also sign out of mock database just in case it was a student/parent
    MockDatabase.instance.logout();
  }

  // =========================================================================
  // Non-Blocking Session Logging for ALL Roles (Admin, Teacher, Student, Parent)
  // =========================================================================

  Future<void> startSessionLog(custom.UserModel user) async {
    try {
      final now = DateTime.now().toUtc();
      final roleStr = user.role.name;

      // Close any previous open session for this user before starting new one
      try {
        // Delete all dangling empty ghost sessions (0 seconds and not properly closed)
        await _supabaseClient
            .from('user_session_logs')
            .delete()
            .eq('user_id', user.id)
            .eq('is_active', false)
            .eq('duration_seconds', 0);
            
        // Find existing active sessions
        final oldSessions = await _supabaseClient
            .from('user_session_logs')
            .select('id, login_at, last_active_at')
            .eq('user_id', user.id)
            .eq('is_active', true);
            
        for (var old in oldSessions) {
          final loginTime = DateTime.parse(old['login_at']);
          final lastActiveTime = DateTime.parse(old['last_active_at'] ?? now.toIso8601String());
          final computedDuration = lastActiveTime.difference(loginTime).inSeconds.abs();
          
          if (computedDuration < 2) {
             // If they immediately refreshed (creating duplicate), delete the tiny ghost
             await _supabaseClient.from('user_session_logs').delete().eq('id', old['id']);
          } else {
             await _supabaseClient.from('user_session_logs').update({
              'is_active': false,
              'logout_at': lastActiveTime.toIso8601String(), // Use last known active time as logout
              'logout_reason': 'terminated',
              'duration_seconds': computedDuration,
            }).eq('id', old['id']);
          }
        }
      } catch (_) {}

      final res = await _supabaseClient
          .from('user_session_logs')
          .insert({
            'user_id': user.id,
            'role': roleStr,
            'session_date': now.toIso8601String().split('T').first,
            'login_at': now.toIso8601String(),
            'last_active_at': now.toIso8601String(),
            'is_active': true,
            'duration_seconds': 0,
          })
          .select('id')
          .single();
      final sessionLogId = res['id']?.toString();
      if (sessionLogId != null) {
        await LocalStorageService.saveActiveSessionId(sessionLogId);
      }
    } catch (e) {
      debugPrint('AuthRepository startSessionLog notice: $e');
    }
  }

  Future<void> recordHeartbeat([String? sessionId]) async {
    final user = currentUser;
    if (user == null) return;
    final id = sessionId ?? LocalStorageService.getActiveSessionId();
    if (id == null) return;
    final now = DateTime.now().toUtc();
    try {
      int? currentDuration;
      try {
        final sRow = await _supabaseClient
            .from('user_session_logs')
            .select('login_at')
            .eq('id', id)
            .maybeSingle();
        if (sRow != null && sRow['login_at'] != null) {
          final loginAt = DateTime.tryParse(sRow['login_at'].toString());
          if (loginAt != null) {
            currentDuration = now.difference(loginAt).inSeconds;
            if (currentDuration < 0) currentDuration = 0;
          }
        }
      } catch (_) {}

      final updateData = <String, dynamic>{
        'last_active_at': now.toIso8601String(),
      };
      if (currentDuration != null) {
        updateData['duration_seconds'] = currentDuration;
      }

      await _supabaseClient
          .from('user_session_logs')
          .update(updateData)
          .eq('id', id);
    } catch (e) {
      debugPrint('AuthRepository recordHeartbeat notice: $e');
    }
  }

  Future<void> endSession([
    String? reason,
    custom.UserModel? targetUser,
    String? targetSessionId,
  ]) async {
    final now = DateTime.now().toUtc();
    final cleanReason = (reason == null || reason.isEmpty || reason == 'manual_logout')
        ? 'manual'
        : (reason == 'session_superseded' || reason == 'app_closed'
            ? 'terminated'
            : (reason == 'inactivity_timeout' ? 'inactivity' : reason));
    try {
      final sessionId = targetSessionId ?? LocalStorageService.getActiveSessionId();
      final user = targetUser ?? currentUser;

      if (sessionId != null) {
        int? computedDuration;
        try {
          final sRow = await _supabaseClient
              .from('user_session_logs')
              .select('login_at')
              .eq('id', sessionId)
              .maybeSingle();
          if (sRow != null && sRow['login_at'] != null) {
            final loginAt = DateTime.tryParse(sRow['login_at'].toString());
            if (loginAt != null) {
              computedDuration = now.difference(loginAt).inSeconds;
              if (computedDuration < 0) computedDuration = 0;
            }
          }
        } catch (_) {}

        final updatePayload = <String, dynamic>{
          'logout_at': now.toIso8601String(),
          'logout_reason': cleanReason,
          'is_active': false,
          'last_active_at': now.toIso8601String(),
        };
        if (computedDuration != null) {
          updatePayload['duration_seconds'] = computedDuration;
        }

        await _supabaseClient
            .from('user_session_logs')
            .update(updatePayload)
            .eq('id', sessionId);
      }

      // FALLBACK & BULK CLEANUP:
      // Even if session ID is lost in local storage (due to hot reloads/tests),
      // force close ALL active sessions for this user to guarantee accuracy.
      if (user != null) {
        await _supabaseClient.from('user_session_logs').update({
          'logout_at': now.toIso8601String(),
          'logout_reason': cleanReason,
          'is_active': false,
          'last_active_at': now.toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('is_active', true);
      }
    } catch (e) {
      debugPrint('AuthRepository endSession notice: $e');
    } finally {
      await LocalStorageService.clearActiveSessionId();
    }
  }

  Future<String> _firebaseIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Your login session has expired. Please log in again.');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw Exception(
        'Unable to verify your login session. Please log in again.',
      );
    }
    return token;
  }

  Future<Map<String, String>> firebaseAuthHeaders({
    bool forceRefresh = false,
  }) async {
    final token = await _firebaseIdToken(forceRefresh: forceRefresh);
    final apiKey = _firebaseAuth.app.options.apiKey;
    return {
      'Authorization': 'Bearer $token',
      'x-firebase-token': token,
      'x-firebase-api-key': apiKey,
    };
  }

  String? _pendingOtpCode;
  DateTime? _pendingOtpExpiry;
  DateTime? _lastFirstLoginOtpSentAt;
  int _firstLoginResendCount = 0;
  int _otpAttempts = 0;

  Future<Map<String, dynamic>> sendFirstLoginOtp({bool isResend = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('A signed-in user session is required.');
    }

    final cleanEmail = user.email!.trim().toLowerCase();

    // 1. Check Progressive 4-Tier Lockout for First Login OTP
    final lockStatus = await RateLimitService.instance.checkStatus(
      feature: 'first_login_otp',
      targetIdentifier: cleanEmail,
      maxAttempts: 5,
    );
    if (lockStatus.isLocked) {
      throw Exception(
        'Too many failed attempts. Locked out for ${lockStatus.formattedCountdown}.',
      );
    }

    final now = DateTime.now().toUtc();

    // 2. Anti-spam & Persistence on F5/Back Navigation:
    // If not an explicit resend, check Supabase for active non-expired challenge within 5 minutes.
    if (!isResend) {
      // Check in-memory first
      if (_pendingOtpCode != null &&
          _pendingOtpExpiry != null &&
          now.isBefore(_pendingOtpExpiry!)) {
        final remainingExpiresIn =
            _pendingOtpExpiry!.difference(now).inSeconds.clamp(0, 300);
        final remainingCooldown = _lastFirstLoginOtpSentAt != null
            ? (60 - now.difference(_lastFirstLoginOtpSentAt!).inSeconds).clamp(0, 60)
            : 0;

        return {
          'sent': true,
          'reused': true,
          'email': cleanEmail,
          'expiresIn': remainingExpiresIn,
          'resendAfter': remainingCooldown,
          'resendCount': _firstLoginResendCount,
        };
      }

      // Check Supabase first_login_otp_verifications
      try {
        final existing = await _supabaseClient
            .from('first_login_otp_verifications')
            .select()
            .eq('user_id', user.uid)
            .maybeSingle();

        if (existing != null && existing['is_verified'] != true) {
          final expStr = existing['expires_at']?.toString();
          final expiresAt = expStr != null ? DateTime.tryParse(expStr)?.toUtc() : null;
          if (expiresAt != null && now.isBefore(expiresAt)) {
            final sentStr = existing['last_sent_at']?.toString();
            final lastSentAt = sentStr != null ? DateTime.tryParse(sentStr)?.toUtc() : null;

            _pendingOtpCode = existing['code_hash']?.toString();
            _pendingOtpExpiry = expiresAt;
            _lastFirstLoginOtpSentAt = lastSentAt ?? now;
            _firstLoginResendCount = (existing['resend_count'] as num?)?.toInt() ?? 0;

            final remainingExpiresIn = expiresAt.difference(now).inSeconds.clamp(0, 300);
            final remainingCooldown = lastSentAt != null
                ? (60 - now.difference(lastSentAt).inSeconds).clamp(0, 60)
                : 0;

            return {
              'sent': true,
              'reused': true,
              'email': cleanEmail,
              'expiresIn': remainingExpiresIn,
              'resendAfter': remainingCooldown,
              'resendCount': _firstLoginResendCount,
            };
          }
        }
      } catch (e) {
        debugPrint('[FirstLoginOTP] Supabase active session lookup notice: $e');
      }
    }

    // 3. If explicit resend, enforce 60s cooldown and max 4 resend attempts
    if (isResend) {
      if (_lastFirstLoginOtpSentAt != null &&
          now.difference(_lastFirstLoginOtpSentAt!).inSeconds < 60) {
        final remaining =
            60 - now.difference(_lastFirstLoginOtpSentAt!).inSeconds;
        throw Exception(
            'Please wait $remaining seconds before requesting another code.');
      }

      final resendStatus = await RateLimitService.instance.recordResend(
        feature: 'first_login_otp',
        targetIdentifier: cleanEmail,
        maxResends: 4,
        userId: user.uid,
      );

      if (resendStatus.isLocked) {
        throw Exception(
          'Maximum resend attempts reached (4/4). Locked out for ${resendStatus.formattedCountdown}.',
        );
      }
      _firstLoginResendCount = resendStatus.resendCount;
    } else {
      _firstLoginResendCount = 0;
      _otpAttempts = 0;
    }

    // Generate secure 6-digit OTP in pure Dart
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    _pendingOtpCode = code;
    _pendingOtpExpiry = now.add(const Duration(minutes: 5)); // Exactly 5 minutes
    _lastFirstLoginOtpSentAt = now;

    debugPrint('========================================================');
    debugPrint(
      '[ClassRealm Pure Dart OTP] Verification code for $cleanEmail: $code (Valid for 5 mins)',
    );
    debugPrint('========================================================');

    try {
      await EmailService.instance.sendPasswordChangeOtpEmail(
        recipientEmail: cleanEmail,
        recipientName: user.displayName ?? 'ClassRealm User',
        otpCode: code,
      );
    } catch (_) {}

    // Persist OTP challenge in Supabase first_login_otp_verifications table
    try {
      await _supabaseClient.from('first_login_otp_verifications').upsert({
        'user_id': user.uid,
        'email': cleanEmail,
        'code_hash': code,
        'expires_at': _pendingOtpExpiry!.toUtc().toIso8601String(),
        'last_sent_at': now.toUtc().toIso8601String(),
        'resend_count': _firstLoginResendCount,
        'failed_attempts': _otpAttempts,
        'is_verified': false,
        'updated_at': now.toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[FirstLoginOTP] Supabase storage notice: $e');
    }

    return {
      'sent': true,
      'reused': false,
      'email': cleanEmail,
      'expiresIn': 300, // Exactly 5 minutes
      'resendAfter': 60, // 60 seconds
      'resendCount': _firstLoginResendCount,
    };
  }

  Future<FirstLoginOtpVerification> verifyFirstLoginOtp(String code) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email?.trim().toLowerCase() ?? '';

    if (email.isNotEmpty) {
      final lockStatus = await RateLimitService.instance.checkStatus(
        feature: 'first_login_otp',
        targetIdentifier: email,
        maxAttempts: 5,
      );
      if (lockStatus.isLocked) {
        return FirstLoginOtpVerification(
          verified: false,
          reason: 'locked',
          attemptsRemaining: 0,
          retryAfter: lockStatus.remainingSeconds,
        );
      }
    }

    // Fallback: restore active OTP from Supabase if in-memory cleared (e.g. on F5)
    final now = DateTime.now().toUtc();
    if (_pendingOtpCode == null && user != null) {
      try {
        final existing = await _supabaseClient
            .from('first_login_otp_verifications')
            .select()
            .eq('user_id', user.uid)
            .maybeSingle();
        if (existing != null) {
          final expStr = existing['expires_at']?.toString();
          final expiresAt = expStr != null ? DateTime.tryParse(expStr)?.toUtc() : null;
          if (expiresAt != null && now.isBefore(expiresAt)) {
            _pendingOtpCode = existing['code_hash']?.toString();
            _pendingOtpExpiry = expiresAt;
          }
        }
      } catch (_) {}
    }

    final cleanCode = code.trim();
    if (_pendingOtpCode == null || _pendingOtpExpiry == null) {
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'No verification code requested. Please request a new code.',
      );
    }

    if (now.isAfter(_pendingOtpExpiry!)) {
      _pendingOtpCode = null;
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'expired',
      );
    }

    if (cleanCode != _pendingOtpCode) {
      final failStatus = await RateLimitService.instance.recordFailure(
        feature: 'first_login_otp',
        targetIdentifier: email,
        maxAttempts: 5,
        userId: user?.uid,
      );

      _otpAttempts = failStatus.failedAttempts;

      try {
        await _supabaseClient
            .from('first_login_otp_verifications')
            .update({
              'failed_attempts': _otpAttempts,
              'updated_at': now.toIso8601String(),
            })
            .eq('user_id', user?.uid ?? '');
      } catch (_) {}

      if (failStatus.isLocked) {
        _pendingOtpCode = null;
        return FirstLoginOtpVerification(
          verified: false,
          reason: 'locked',
          attemptsRemaining: 0,
          retryAfter: failStatus.remainingSeconds,
        );
      }

      return FirstLoginOtpVerification(
        verified: false,
        reason: 'Invalid verification code. Please check and try again.',
        attemptsRemaining: failStatus.attemptsRemaining,
      );
    }

    // Code matched!
    try {
      await _supabaseClient
          .from('first_login_otp_verifications')
          .update({
            'is_verified': true,
            'updated_at': now.toIso8601String(),
          })
          .eq('user_id', user?.uid ?? '');
    } catch (_) {}

    _pendingOtpCode = null;
    _pendingOtpExpiry = null;
    _lastFirstLoginOtpSentAt = null;
    _firstLoginResendCount = 0;
    _otpAttempts = 0;

    if (email.isNotEmpty) {
      await RateLimitService.instance.clearRateLimit(
        feature: 'first_login_otp',
        targetIdentifier: email,
      );
    }
    return const FirstLoginOtpVerification(verified: true, reason: null);
  }

  // Complete first-login password setup in Pure Dart
  Future<String?> completeFirstLogin(String userId, String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      final currentAppUser = _currentUser;
      if ((user == null || user.uid != userId) &&
          (currentAppUser == null || currentAppUser.id != userId)) {
        return "No matching authenticated user found.";
      }

      bool updated = false;

      // 1. Try updating password via Firebase Client SDK
      if (user != null && user.uid == userId) {
        try {
          await user.updatePassword(newPassword);
          updated = true;
          debugPrint('[AuthRepository] Password updated via client SDK.');
        } catch (clientErr) {
          debugPrint(
              '[AuthRepository] Client updatePassword failed ($clientErr), falling back to Service Account Admin API...');
        }
      }

      // 2. If client SDK threw requires-recent-login or was stale, update via Service Account Admin API
      if (!updated) {
        final adminOk = await FirebaseAuthAdminService.updateUserPassword(
          uid: userId,
          newPassword: newPassword,
        );
        if (adminOk) {
          updated = true;
          debugPrint(
              '[AuthRepository] Password updated via FirebaseAuthAdminService.');
          try {
            await _firebaseAuth.currentUser?.reload();
          } catch (_) {}
        }
      }

      // 3. Fallback: Edge Function reset-password
      if (!updated) {
        final userEmail = user?.email ?? currentAppUser?.email;
        if (userEmail != null && userEmail.isNotEmpty) {
          final supabaseUrl = EnvConfig.supabaseUrl;
          final supabaseAnonKey = EnvConfig.supabaseAnonKey;
          if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
            try {
              final resetUrl =
                  Uri.parse('$supabaseUrl/functions/v1/reset-password');
              final resp = await http.post(
                resetUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'apikey': supabaseAnonKey,
                  'Authorization': 'Bearer $supabaseAnonKey',
                },
                body: jsonEncode({
                  'email': userEmail.trim().toLowerCase(),
                  'new_password': newPassword,
                }),
              );
              final respData =
                  jsonDecode(resp.body) as Map<String, dynamic>?;
              if (resp.statusCode == 200 && respData?['success'] == true) {
                updated = true;
                debugPrint(
                    '[AuthRepository] Password updated via reset-password edge function.');
              }
            } catch (edgeErr) {
              debugPrint(
                  '[AuthRepository] Edge function fallback notice: $edgeErr');
            }
          }
        }
      }

      if (!updated) {
        return "Security check failed due to an inactive session. Please click 'Back to Login', re-enter your temporary credentials, and try setting your new password again.";
      }

      // Direct Pure Dart Supabase profile updates
      try {
        await _supabaseClient
            .from('users')
            .update({'status': 'active'})
            .eq('id', userId);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('student_settings')
            .update({'status': 'active'})
            .eq('student_id', userId);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('teacher_settings')
            .update({'status': 'active'})
            .eq('teacher_id', userId);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('parent_profiles')
            .update({'status': 'active'})
            .eq('parent_id', userId);
      } catch (_) {}

      // Clean up single-use OTP verification record from Supabase after successful completion
      try {
        await _supabaseClient
            .from('first_login_otp_verifications')
            .delete()
            .eq('user_id', userId);
      } catch (_) {}

      final current = _currentUser;
      if (current != null && current.id == userId) {
        _currentUser = current.copyWith(status: custom.AccountStatus.active);
        MockDatabase.instance.currentUser = _currentUser;
      }
      await LocalStorageService.updateSavedPasswordIfRemembered(newPassword);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // --- FORGOT PASSWORD STATE & FLOW ---
  String? _forgotPasswordOtpCode;
  DateTime? _forgotPasswordOtpExpiry;
  DateTime? _lastForgotPasswordOtpSentAt;
  int _forgotPasswordResendCount = 0;
  String? _forgotPasswordEmail;
  int _forgotPasswordAttempts = 0;
  bool _forgotPasswordVerified = false;

  /// Look up a user profile by email across Supabase and MockDatabase.
  Future<custom.UserModel?> getUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      final userResp = await _supabaseClient
          .from('users')
          .select('id')
          .eq('email', cleanEmail)
          .maybeSingle();

      if (userResp != null && userResp['id'] != null) {
        final uid = userResp['id'].toString();
        return await _getUserFromSupabase(uid);
      }
    } catch (e) {
      debugPrint('[AuthRepository] getUserByEmail Supabase error: $e');
    }

    try {
      return MockDatabase.instance.users.firstWhere(
        (u) => u.email.trim().toLowerCase() == cleanEmail,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sends a secure pure Dart 6-digit OTP code to the requested email for password restorey.
  Future<Map<String, dynamic>> sendForgotPasswordOtp({
    required String email,
    String? recipientName,
    bool isResend = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw Exception('A valid email address is required.');
    }

    if (ParentCredentialHelper.isParentDomain(cleanEmail)) {
      throw Exception(
        'Parent accounts (@classrealm.com) do not use email OTP codes. Please contact your student\'s teacher to reset your password.',
      );
    }

    // 1. Check 4-Tier Progressive Lockout for Forgot Password
    final lockStatus = await RateLimitService.instance.checkStatus(
      feature: 'forgot_password',
      targetIdentifier: cleanEmail,
      maxAttempts: 5,
    );
    if (lockStatus.isLocked) {
      throw Exception(
        'Too many failed attempts. Locked out for ${lockStatus.formattedCountdown}.',
      );
    }

    // Strict email check
    final verifyResult = await EmailVerificationService.instance.verifyEmail(cleanEmail);
    if (!verifyResult.isValid) {
      throw Exception(verifyResult.reason ?? 'Please provide a valid deliverable email address.');
    }

    // Verify user exists
    final user = await getUserByEmail(cleanEmail);
    if (user == null) {
      throw Exception('No account found with this email address.');
    }

    if (user.role == custom.UserRole.parent) {
      throw Exception(
        'Parent accounts do not use email OTP codes. Please contact your student\'s teacher to reset your password.',
      );
    }

    final now = DateTime.now().toUtc();

    // 2. Anti-spam & Persistence on F5/Back Navigation:
    // Check Supabase password_reset_otps for active non-expired challenge within 5 minutes.
    if (!isResend) {
      // In-memory check first
      if (_forgotPasswordOtpCode != null &&
          _forgotPasswordEmail == cleanEmail &&
          _forgotPasswordOtpExpiry != null &&
          now.isBefore(_forgotPasswordOtpExpiry!)) {
        final remainingExpiresIn =
            _forgotPasswordOtpExpiry!.difference(now).inSeconds.clamp(0, 300);
        final remainingCooldown = _lastForgotPasswordOtpSentAt != null
            ? (60 - now.difference(_lastForgotPasswordOtpSentAt!).inSeconds).clamp(0, 60)
            : 0;

        return {
          'sent': true,
          'reused': true,
          'email': cleanEmail,
          'expiresIn': remainingExpiresIn,
          'resendAfter': remainingCooldown,
          'resendCount': _forgotPasswordResendCount,
        };
      }

      // Check Supabase password_reset_otps table
      try {
        final existing = await _supabaseClient
            .from('password_reset_otps')
            .select()
            .eq('email', cleanEmail)
            .maybeSingle();

        if (existing != null && existing['is_verified'] != true) {
          final expStr = existing['expires_at']?.toString();
          final expiresAt = expStr != null ? DateTime.tryParse(expStr)?.toUtc() : null;
          if (expiresAt != null && now.isBefore(expiresAt)) {
            final sentStr = existing['last_sent_at']?.toString();
            final lastSentAt = sentStr != null ? DateTime.tryParse(sentStr)?.toUtc() : null;

            _forgotPasswordOtpCode = existing['code_hash']?.toString();
            _forgotPasswordOtpExpiry = expiresAt;
            _lastForgotPasswordOtpSentAt = lastSentAt ?? now;
            _forgotPasswordEmail = cleanEmail;
            _forgotPasswordResendCount = (existing['resend_count'] as num?)?.toInt() ?? 0;

            final remainingExpiresIn = expiresAt.difference(now).inSeconds.clamp(0, 300);
            final remainingCooldown = lastSentAt != null
                ? (60 - now.difference(lastSentAt).inSeconds).clamp(0, 60)
                : 0;

            return {
              'sent': true,
              'reused': true,
              'email': cleanEmail,
              'expiresIn': remainingExpiresIn,
              'resendAfter': remainingCooldown,
              'resendCount': _forgotPasswordResendCount,
            };
          }
        }
      } catch (e) {
        debugPrint('[ForgotPasswordOTP] Supabase active session lookup notice: $e');
      }
    }

    if (isResend) {
      if (_lastForgotPasswordOtpSentAt != null &&
          now.difference(_lastForgotPasswordOtpSentAt!).inSeconds < 60) {
        final remaining =
            60 - now.difference(_lastForgotPasswordOtpSentAt!).inSeconds;
        throw Exception(
            'Please wait $remaining seconds before requesting another code.');
      }

      final resendStatus = await RateLimitService.instance.recordResend(
        feature: 'forgot_password',
        targetIdentifier: cleanEmail,
        maxResends: 4,
        userId: user.id,
      );

      if (resendStatus.isLocked) {
        throw Exception(
          'Maximum resend attempts reached (4/4). Locked out for ${resendStatus.formattedCountdown}.',
        );
      }
      _forgotPasswordResendCount = resendStatus.resendCount;
    } else {
      _forgotPasswordResendCount = 0;
      _forgotPasswordAttempts = 0;
    }

    // Generate secure 6-digit OTP in pure Dart
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    _forgotPasswordOtpCode = code;
    _forgotPasswordOtpExpiry = now.add(const Duration(minutes: 5)); // Exactly 5 minutes
    _lastForgotPasswordOtpSentAt = now;
    _forgotPasswordEmail = cleanEmail;
    _forgotPasswordVerified = false;

    debugPrint('========================================================');
    debugPrint(
      '[ClassRealm Pure Dart Forgot Password OTP] Verification code for $cleanEmail: $code (Valid for 5 mins)',
    );
    debugPrint('========================================================');

    try {
      await EmailService.instance.sendPasswordChangeOtpEmail(
        recipientEmail: cleanEmail,
        recipientName: recipientName ?? user.fullName,
        otpCode: code,
      );
    } catch (e) {
      debugPrint('[AuthRepository] EmailService send error: $e');
    }

    // Persist OTP challenge in Supabase password_reset_otps table
    try {
      await _supabaseClient.from('password_reset_otps').upsert({
        'email': cleanEmail,
        'code_hash': code,
        'expires_at': _forgotPasswordOtpExpiry!.toUtc().toIso8601String(),
        'last_sent_at': now.toUtc().toIso8601String(),
        'resend_count': _forgotPasswordResendCount,
        'failed_attempts': _forgotPasswordAttempts,
        'is_verified': false,
        'updated_at': now.toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[ForgotPasswordOTP] Supabase storage notice: $e');
    }

    return {
      'sent': true,
      'reused': false,
      'email': cleanEmail,
      'expiresIn': 300, // Exactly 5 minutes
      'resendAfter': 60, // 60 seconds
      'resendCount': _forgotPasswordResendCount,
    };
  }

  /// Verifies the 6-digit OTP code entered by the user during password restorey.
  Future<FirstLoginOtpVerification> verifyForgotPasswordOtp(String code) async {
    final cleanCode = code.trim();
    final email = _forgotPasswordEmail ?? '';

    if (email.isNotEmpty) {
      final lockStatus = await RateLimitService.instance.checkStatus(
        feature: 'forgot_password',
        targetIdentifier: email,
        maxAttempts: 5,
      );
      if (lockStatus.isLocked) {
        return FirstLoginOtpVerification(
          verified: false,
          reason: 'locked',
          attemptsRemaining: 0,
          retryAfter: lockStatus.remainingSeconds,
        );
      }
    }

    final now = DateTime.now().toUtc();

    // Fallback: restore active OTP from Supabase if in-memory cleared (e.g. on F5)
    if (_forgotPasswordOtpCode == null && email.isNotEmpty) {
      try {
        final existing = await _supabaseClient
            .from('password_reset_otps')
            .select()
            .eq('email', email)
            .maybeSingle();
        if (existing != null) {
          final expStr = existing['expires_at']?.toString();
          final expiresAt = expStr != null ? DateTime.tryParse(expStr)?.toUtc() : null;
          if (expiresAt != null && now.isBefore(expiresAt)) {
            _forgotPasswordOtpCode = existing['code_hash']?.toString();
            _forgotPasswordOtpExpiry = expiresAt;
          }
        }
      } catch (_) {}
    }

    if (_forgotPasswordOtpCode == null || _forgotPasswordOtpExpiry == null) {
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'No verification code requested. Please request a new code.',
      );
    }

    if (now.isAfter(_forgotPasswordOtpExpiry!)) {
      _forgotPasswordOtpCode = null;
      _forgotPasswordVerified = false;
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'expired',
      );
    }

    if (cleanCode != _forgotPasswordOtpCode) {
      final failStatus = await RateLimitService.instance.recordFailure(
        feature: 'forgot_password',
        targetIdentifier: email,
        maxAttempts: 5,
      );

      _forgotPasswordAttempts = failStatus.failedAttempts;

      try {
        await _supabaseClient
            .from('password_reset_otps')
            .update({
              'failed_attempts': _forgotPasswordAttempts,
              'updated_at': now.toIso8601String(),
            })
            .eq('email', email);
      } catch (_) {}

      if (failStatus.isLocked) {
        _forgotPasswordOtpCode = null;
        _forgotPasswordVerified = false;
        return FirstLoginOtpVerification(
          verified: false,
          reason: 'locked',
          attemptsRemaining: 0,
          retryAfter: failStatus.remainingSeconds,
        );
      }

      return FirstLoginOtpVerification(
        verified: false,
        reason: 'Invalid verification code. Please check and try again.',
        attemptsRemaining: failStatus.attemptsRemaining,
      );
    }

    // Code matched!
    try {
      await _supabaseClient
          .from('password_reset_otps')
          .update({
            'is_verified': true,
            'updated_at': now.toIso8601String(),
          })
          .eq('email', email);
    } catch (_) {}

    _forgotPasswordOtpCode = null;
    _forgotPasswordVerified = true;
    _forgotPasswordAttempts = 0;

    if (email.isNotEmpty) {
      await RateLimitService.instance.clearRateLimit(
        feature: 'forgot_password',
        targetIdentifier: email,
      );
    }
    return const FirstLoginOtpVerification(verified: true, reason: null);
  }

  /// Updates password after successful OTP verification with strict security gate.
  Future<String?> updateForgottenPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Verify through Supabase password_reset_otps or in-memory gate
    bool isAuthorized = _forgotPasswordVerified && _forgotPasswordEmail == cleanEmail;
    if (!isAuthorized) {
      try {
        final existing = await _supabaseClient
            .from('password_reset_otps')
            .select()
            .eq('email', cleanEmail)
            .maybeSingle();
        if (existing != null && existing['is_verified'] == true) {
          final expStr = existing['expires_at']?.toString();
          final expiresAt = expStr != null ? DateTime.tryParse(expStr)?.toUtc() : null;
          if (expiresAt != null && DateTime.now().toUtc().isBefore(expiresAt)) {
            isAuthorized = true;
          }
        }
      } catch (_) {}
    }

    if (!isAuthorized) {
      return 'Unauthorized: OTP verification must be completed before updating your password.';
    }

    try {
      final user = await getUserByEmail(cleanEmail);
      if (user == null) {
        return 'User account not found.';
      }

      // 1. Primary: Use FirebaseAuthAdminService to update password directly via Service Account
      bool updated = await FirebaseAuthAdminService.updateUserPassword(
        uid: user.id,
        newPassword: newPassword,
      );

      // 2. Fallback: Invoke Supabase Edge Function to update password in Firebase Authentication
      if (!updated) {
        final supabaseUrl = EnvConfig.supabaseUrl;
        final supabaseAnonKey = EnvConfig.supabaseAnonKey;

        final resetUrl = Uri.parse('$supabaseUrl/functions/v1/reset-password');
        final resp = await http.post(
          resetUrl,
          headers: {
            'Content-Type': 'application/json',
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
          },
          body: jsonEncode({
            'email': cleanEmail,
            'new_password': newPassword,
          }),
        );

        final respData = jsonDecode(resp.body) as Map<String, dynamic>?;
        if (resp.statusCode == 200 && respData?['success'] == true) {
          updated = true;
        } else {
          final err = respData?['error'] ?? 'Failed to update password in Firebase Auth.';
          debugPrint('[AuthRepository] reset-password failed: $err');
          return err.toString();
        }
      }

      // 2. Update Supabase status to active
      try {
        await _supabaseClient
            .from('users')
            .update({'status': 'active'})
            .eq('id', user.id);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('teacher_settings')
            .update({'status': 'active'})
            .eq('teacher_id', user.id);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('student_settings')
            .update({'status': 'active'})
            .eq('student_id', user.id);
      } catch (_) {}

      // 3. Clear verified OTP record after successful password change
      try {
        await _supabaseClient.from('password_reset_otps').delete().eq('email', cleanEmail);
      } catch (_) {}

      // 4. Update local session or mock database if applicable
      final mockIndex = MockDatabase.instance.users.indexWhere(
        (u) => u.email.trim().toLowerCase() == cleanEmail,
      );
      if (mockIndex != -1) {
        final mockUser = MockDatabase.instance.users[mockIndex];
        MockDatabase.instance.users[mockIndex] = mockUser.copyWith(
          status: custom.AccountStatus.active,
        );
      }

      await LocalStorageService.updateSavedPasswordIfRemembered(
        newPassword,
        forEmail: cleanEmail,
      );

      // Reset OTP security state
      _forgotPasswordVerified = false;
      _forgotPasswordEmail = null;
      _forgotPasswordOtpCode = null;
      _forgotPasswordOtpExpiry = null;
      _forgotPasswordAttempts = 0;

      return null; // Success
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // Admin: Get teacher accounts created by an administrator.
  Future<List<custom.UserModel>> getTeachers() async {
    try {
      final List<dynamic> infoResp = await _supabaseClient
          .from('teacher_settings')
          .select();

      List<custom.UserModel> teachers = [];
      for (var info in infoResp) {
        final u = await _supabaseClient
            .from('users')
            .select()
            .eq('id', info['teacher_id'])
            .single();

        final profile = await _supabaseClient
            .from('teacher_profiles')
            .select()
            .eq('teacher_id', info['teacher_id'])
            .single();

        teachers.add(
          custom.UserModel(
            id: u['id'],
            username: u['email'],
            fullName: '${profile['first_name']} ${profile['last_name']}',
            email: u['email'],
            role: custom.UserRole.teacher,
            firstName: profile['first_name'],
            lastName: profile['last_name'],
            middleName: profile['middle_name'],
            gender: profile['gender'],
            birthday: profile['birthday'] != null
                ? DateTime.parse(profile['birthday'].toString())
                : null,
            isSetupComplete: info['is_setup_complete'] ?? false,
            status: _parseStatus(info['status'] ?? 'pending_first_login'),
            isArchived: (u['is_archived'] == true) || (info['status'] == 'archived'),
          ),
        );
      }
      return teachers;
    } catch (e) {
      return [];
    }
  }

  // =========================================================================
  // Admin: Account Recovery and Email Fixes
  // =========================================================================

  /// Action A: Update Email Only (For fixing typos, doesn't reset password)
  Future<void> updateTeacherEmailOnly({required String teacherId, required String newEmail}) async {
    final cleanEmail = newEmail.trim().toLowerCase();
    
    // 1. Verify if email exists
    final exists = await _supabaseClient.from('users').select('id').eq('email', cleanEmail).maybeSingle();
    if (exists != null && exists['id'] != teacherId) {
      throw Exception('This email is already in use by another account.');
    }

    // 2. Try updating Firebase Auth Email via Edge Function or Admin SDK
    final adminOk = await FirebaseAuthAdminService.updateUserEmail(uid: teacherId, newEmail: cleanEmail);
    if (!adminOk) {
      throw Exception('Failed to update email in Firebase Authentication. Check service account permissions.');
    }

    // 3. Update Supabase Database Email
    await _supabaseClient.from('users').update({'email': cleanEmail, 'updated_at': DateTime.now().toIso8601String()}).eq('id', teacherId);
  }

  /// Action B: Full Reset & Recover Account (Updates Email, Generates Temp Password, Forces First Login)
  Future<void> recoverTeacherAccount({required String teacherId, required String newEmail}) async {
    final cleanEmail = newEmail.trim().toLowerCase();
    
    // 1. Verify if email exists
    final exists = await _supabaseClient.from('users').select('id').eq('email', cleanEmail).maybeSingle();
    if (exists != null && exists['id'] != teacherId) {
      throw Exception('This email is already in use by another account.');
    }

    // 2. Generate a secure temporary password
    final tempPassword = 'Realm-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}x';

    // 3. Update Firebase Auth (Email and Password)
    final emailOk = await FirebaseAuthAdminService.updateUserEmail(uid: teacherId, newEmail: cleanEmail);
    final passOk = await FirebaseAuthAdminService.updateUserPassword(uid: teacherId, newPassword: tempPassword);

    if (!emailOk || !passOk) {
      throw Exception('Failed to recover account in Firebase Authentication.');
    }

    // 4. Reset Supabase Status to pending_first_login
    await _supabaseClient.from('users').update({'email': cleanEmail, 'status': 'pending_first_login', 'updated_at': DateTime.now().toIso8601String()}).eq('id', teacherId);
    await _supabaseClient.from('teacher_settings').update({'status': 'pending_first_login'}).eq('teacher_id', teacherId);

    // 5. Send Email with the new credentials
    try {
      final res = await _supabaseClient.from('teacher_profiles').select('first_name').eq('teacher_id', teacherId).maybeSingle();
      final name = res?['first_name']?.toString() ?? 'Teacher';
      await EmailService.instance.sendTeacherWelcomeEmail(recipientEmail: cleanEmail, teacherName: name, tempPassword: tempPassword);
    } catch (e) {
      debugPrint('Warning: Recovery completed but failed to send email: $e');
    }
  }

  // Admin: Update Teacher Status (with cascading archive & student/parent active check)
  Future<bool> updateTeacherStatus(
    String uid,
    String newStatus, {
    String? currentStatusHint,
  }) async {
    try {
      if (newStatus == 'archived') {
        // 1. Preserve current teacher status before archiving
        try {
          final cur = await _supabaseClient
              .from('teacher_settings')
              .select('status')
              .eq('teacher_id', uid)
              .maybeSingle();
          final currentStatus = cur?['status']?.toString();
          final statusToSave = (currentStatus != null &&
                  currentStatus.isNotEmpty &&
                  currentStatus != 'archived')
              ? currentStatus
              : (currentStatusHint ?? 'active');

          await _supabaseClient
              .from('teacher_settings')
              .update({'previous_status': statusToSave, 'status': 'archived'})
              .eq('teacher_id', uid);
        } catch (_) {}

        // 2. Mark as archived in users table (primary indicator)
        await _supabaseClient
            .from('users')
            .update({'is_archived': true})
            .eq('id', uid);

        // Disable account in Firebase Auth so they cannot log in
        try {
          await FirebaseAuthAdminService.setUserDisabled(uid: uid, disabled: true);
        } catch (_) {}

        // Soft-archive subject offerings taught by this teacher (without touching students or parents)
        try {
          await _supabaseClient
              .from('subject_offerings')
              .update({'is_archived': true})
              .eq('teacher_id', uid);
        } catch (e) {
          debugPrint('Error soft-archiving teacher subject offerings: $e');
        }
      } else if (newStatus == 'active') {
        try {
          await _supabaseClient
              .from('users')
              .update({'is_archived': false})
              .eq('id', uid);

          final settings = await _supabaseClient
              .from('teacher_settings')
              .select('previous_status')
              .eq('teacher_id', uid)
              .maybeSingle();

          final prev = settings?['previous_status']?.toString();
          // STRICT RULE: Restore the exact previous status (e.g. active).
          // Default to 'active'. NEVER revert to pending_first_login unless it was genuinely pending_first_login!
          final targetStatus = (prev != null && prev.isNotEmpty && prev != 'archived')
              ? prev
              : 'active';

          await _supabaseClient
              .from('teacher_settings')
              .update({'status': targetStatus, 'previous_status': null})
              .eq('teacher_id', uid);

          // Re-enable account in Firebase Auth
          try {
            await FirebaseAuthAdminService.setUserDisabled(uid: uid, disabled: false);
          } catch (_) {}
        } catch (_) {}

        // Restore subject offerings taught by this teacher (without touching students or parents)
        try {
          await _supabaseClient
              .from('subject_offerings')
              .update({'is_archived': false})
              .eq('teacher_id', uid);
        } catch (e) {
          debugPrint('Error restoring teacher subject offerings: $e');
        }
      } else {
        await _supabaseClient
            .from('teacher_settings')
            .update({'status': newStatus})
            .eq('teacher_id', uid);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating teacher status $uid to $newStatus: $e');
      return false;
    }
  }

  // Admin: Delete Teacher Record Permanently
  Future<bool> deleteTeacherRecord(String teacherId) async {
    try {
      // 1. Find all subject offerings taught by this teacher
      final offerings = await _supabaseClient
          .from('subject_offerings')
          .select('id')
          .eq('teacher_id', teacherId);

      final Set<String> affectedStudentIds = {};

      for (var off in offerings) {
        final offId = off['id'];

        // Get enrolled students
        final enr = await _supabaseClient
            .from('student_enrollments')
            .select('student_id')
            .eq('subject_offering_id', offId);
        for (var row in enr) {
          if (row['student_id'] != null) {
            affectedStudentIds.add(row['student_id'].toString());
          }
        }

        // Delete dependencies under this subject offering
        try {
          await _supabaseClient
              .from('teacher_schedule')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        try {
          await _supabaseClient
              .from('attendance_records')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        try {
          await _supabaseClient
              .from('term_grades')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        try {
          await _supabaseClient
              .from('gradebook_term_sheets')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        // Digital assessments
        try {
          final assessments = await _supabaseClient
              .from('digital_assessments')
              .select('id')
              .eq('subject_offering_id', offId);
          for (var a in assessments) {
            final aId = a['id'];
            final attempts = await _supabaseClient
                .from('assessment_attempts')
                .select('id')
                .eq('assessment_id', aId);
            for (var att in attempts) {
              await _supabaseClient
                  .from('anti_cheating_logs')
                  .delete()
                  .eq('assessment_attempt_id', att['id']);
              await _supabaseClient
                  .from('assessment_responses')
                  .delete()
                  .eq('attempt_id', att['id']);
            }
            await _supabaseClient
                .from('assessment_attempts')
                .delete()
                .eq('assessment_id', aId);

            final questions = await _supabaseClient
                .from('assessment_questions')
                .select('id')
                .eq('assessment_id', aId);
            for (var q in questions) {
              await _supabaseClient
                  .from('assessment_question_options')
                  .delete()
                  .eq('question_id', q['id']);
            }
            await _supabaseClient
                .from('assessment_questions')
                .delete()
                .eq('assessment_id', aId);
            await _supabaseClient
                .from('digital_assessment_extensions')
                .delete()
                .eq('assessment_id', aId);
          }
          await _supabaseClient
              .from('digital_assessments')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        // Classwork items
        try {
          final classworks = await _supabaseClient
              .from('classwork_items')
              .select('id')
              .eq('subject_offering_id', offId);
          for (var cw in classworks) {
            final cwId = cw['id'];
            final subs = await _supabaseClient
                .from('student_classwork_submissions')
                .select('id')
                .eq('classwork_id', cwId);
            for (var s in subs) {
              await _supabaseClient
                  .from('submission_attachments')
                  .delete()
                  .eq('submission_id', s['id']);
            }
            await _supabaseClient
                .from('student_classwork_submissions')
                .delete()
                .eq('classwork_id', cwId);
            await _supabaseClient
                .from('classwork_attachments')
                .delete()
                .eq('classwork_id', cwId);
            await _supabaseClient
                .from('classwork_extensions')
                .delete()
                .eq('classwork_id', cwId);
          }
          await _supabaseClient
              .from('classwork_items')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        // Folders and materials
        try {
          final folders = await _supabaseClient
              .from('folders')
              .select('id')
              .eq('subject_offering_id', offId);
          for (var f in folders) {
            await _supabaseClient
                .from('learning_materials')
                .delete()
                .eq('folder_id', f['id']);
          }
          await _supabaseClient
              .from('folders')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        // Delete enrollments
        try {
          await _supabaseClient
              .from('student_enrollments')
              .delete()
              .eq('subject_offering_id', offId);
        } catch (_) {}

        // Delete offering
        try {
          await _supabaseClient
              .from('subject_offerings')
              .delete()
              .eq('id', offId);
        } catch (_) {}
      }

      // Note: Students and parents are preserved in the school directory even if a teacher is permanently deleted.

      // 4. Delete Teacher records
      String? teacherEmail;
      try {
        final u = await _supabaseClient
            .from('users')
            .select('email')
            .eq('id', teacherId)
            .maybeSingle();
        teacherEmail = u?['email']?.toString();
      } catch (_) {}

      try {
        await _supabaseClient
            .from('first_login_otp_verifications')
            .delete()
            .eq('user_id', teacherId);
      } catch (_) {}

      if (teacherEmail != null && teacherEmail.isNotEmpty) {
        try {
          await _supabaseClient
              .from('admin_teacher_email_challenges')
              .delete()
              .eq('email', teacherEmail);
        } catch (_) {}
      }

      try {
        await _supabaseClient
            .from('admin_teacher_email_challenges')
            .delete()
            .eq('created_by', teacherId);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('teacher_settings')
            .delete()
            .eq('teacher_id', teacherId);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('teacher_profiles')
            .delete()
            .eq('teacher_id', teacherId);
      } catch (_) {}

      try {
        await _supabaseClient
            .from('users')
            .delete()
            .eq('id', teacherId);
      } catch (_) {}

      // Delete from Firebase Authentication
      try {
        await FirebaseAuthAdminService.deleteUser(
          uid: teacherId,
          email: teacherEmail,
        );
      } catch (fbErr) {
        debugPrint('Firebase Auth deletion notice for teacher $teacherId: $fbErr');
      }

      return true;
    } catch (e) {
      debugPrint('Error permanently deleting teacher $teacherId: $e');
      return false;
    }
  }

  // Admin: Update Teacher Profile Details
  Future<bool> updateTeacherProfile({
    required String teacherId,
    required String firstName,
    String? middleName,
    required String lastName,
    required String gender,
    required DateTime birthday,
  }) async {
    try {
      final bdayStr =
          '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
      await _supabaseClient.from('teacher_profiles').update({
        'first_name': firstName.trim(),
        'middle_name': (middleName == null || middleName.trim().isEmpty)
            ? null
            : middleName.trim(),
        'last_name': lastName.trim(),
        'gender': gender,
        'birthday': bdayStr,
      }).eq('teacher_id', teacherId);
      return true;
    } catch (e) {
      debugPrint('Error updating teacher profile: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> sendAdminTeacherVerification({
    required String email,
    required String firstName,
    required String middleName,
    required String lastName,
    required String gender,
    required DateTime birthday,
    bool isResend = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 0. Verify domain deliverability (Ensure domain exists and can receive email)
    final deliverability =
        await AppValidators.checkDomainDeliverability(cleanEmail);
    if (!deliverability.isDeliverable) {
      throw AdminTeacherException(
        deliverability.error ??
            "The email domain is undeliverable (Address not found). Please verify the email address.",
      );
    }

    // 1. Check if email is already registered in users table
    try {
      final existing = await _supabaseClient
          .from('users')
          .select('id')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (existing != null) {
        throw const AdminTeacherException('This email is already registered.');
      }
    } catch (e) {
      if (e is AdminTeacherException) rethrow;
      debugPrint('Supabase user check notice: $e');
    }

    // 2. Check rate limit & lockout status
    final rateStatus = await RateLimitService.instance.checkStatus(
      feature: 'admin_add_teacher_otp',
      targetIdentifier: cleanEmail,
      maxAttempts: 5,
    );
    if (rateStatus.isLocked) {
      throw AdminTeacherException(
        'Too many failed attempts. Account temporarily locked for ${rateStatus.formattedCountdown}.',
        maxAttemptsExceeded: true,
        failedAttempts: rateStatus.failedAttempts,
      );
    }

    // 3. Check for existing active challenge in admin_teacher_email_challenges
    Map<String, dynamic>? priorChallenge;
    try {
      final res = await _supabaseClient
          .from('admin_teacher_email_challenges')
          .select()
          .eq('email', cleanEmail)
          .maybeSingle();
      if (res != null) {
        priorChallenge = Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Supabase challenge lookup notice: $e');
    }

    final now = DateTime.now().toUtc();

    if (priorChallenge != null) {
      final priorResendCount =
          (priorChallenge['resend_count'] as num?)?.toInt() ?? 0;
      final priorFailedAttempts = rateStatus.failedAttempts;

      final lastSentAtStr = priorChallenge['last_sent_at']?.toString();
      final lastSentAt =
          lastSentAtStr != null ? DateTime.tryParse(lastSentAtStr)?.toUtc() : null;

      // Accurately compute seconds since last sent in UTC
      int secondsSinceLastSent = 999;
      if (lastSentAt != null) {
        final diff = now.difference(lastSentAt).inSeconds;
        if (diff >= 0 && diff <= 300) {
          secondsSinceLastSent = diff;
        }
      }

      final expiresAtStr = priorChallenge['expires_at']?.toString();
      final priorExpiresAt =
          expiresAtStr != null ? DateTime.tryParse(expiresAtStr)?.toUtc() : null;
      final isChallengeStillValid =
          priorExpiresAt != null && now.isBefore(priorExpiresAt);

      if (isResend) {
        if (priorResendCount >= 4) {
          final lockStatus = await RateLimitService.instance.recordFailure(
            feature: 'admin_add_teacher_otp',
            targetIdentifier: cleanEmail,
            maxAttempts: 0, // force lockout on 4th resend
          );
          throw AdminTeacherException(
            'Maximum 4 resends reached. Please wait ${lockStatus.formattedCountdown} before requesting a new code.',
            maxAttemptsExceeded: true,
            failedAttempts: 5,
          );
        }

        if (secondsSinceLastSent < 60) {
          final waitSec = (60 - secondsSinceLastSent).clamp(1, 60);
          throw AdminTeacherException(
              'Please wait ${waitSec}s before requesting another code.');
        }
      } else {
        // Anti-spam / Anti-F5: If user navigates Back and clicks Send again while an active code is still valid within 5 minutes:
        if (isChallengeStillValid) {
          final remainingCooldown = (60 - secondsSinceLastSent).clamp(0, 60);
          final remainingOtpSeconds =
              priorExpiresAt.difference(now).inSeconds.clamp(0, 300);
          return {
            'sent': false,
            'reused': true,
            'email': cleanEmail,
            'remainingCooldownSeconds': remainingCooldown,
            'remainingOtpSeconds': remainingOtpSeconds,
            'failedAttempts': priorFailedAttempts,
            'resendCount': priorResendCount,
            'expiresAt': priorExpiresAt.toIso8601String(),
          };
        }
      }
    }

    // 4. Generate a fresh 6-digit OTP code (strictly valid for 5 minutes / 300 seconds)
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    final expiresAt = now.add(const Duration(minutes: 5));
    final currentResendCount = isResend
        ? (((priorChallenge?['resend_count'] as num?)?.toInt() ?? 0) + 1)
        : 0;

    debugPrint('========================================================');
    debugPrint(
        '[ClassRealm Teacher OTP] Code for $cleanEmail: $code (Valid for 5 mins)');
    debugPrint('========================================================');

    // 5. Dispatch verification code via EmailService
    final fullName = [firstName.trim(), middleName.trim(), lastName.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    try {
      await EmailService.instance.sendTeacherVerificationCode(
        recipientEmail: cleanEmail,
        teacherName: fullName,
        code: code,
      );
    } catch (e) {
      debugPrint('Email delivery failed: $e');
      try {
        await _supabaseClient
            .from('admin_teacher_email_challenges')
            .delete()
            .eq('email', cleanEmail);
      } catch (_) {}
      final msg = e is EmailDeliveryException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      throw AdminTeacherException(msg);
    }

    // 6. Persist challenge in Supabase admin_teacher_email_challenges
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
    final deviceId = LocalStorageService.getSyncDeviceId();

    try {
      await _supabaseClient.from('admin_teacher_email_challenges').upsert({
        'email': cleanEmail,
        'code_hash': code,
        'first_name': firstName.trim(),
        'middle_name': middleName.trim().isEmpty ? null : middleName.trim(),
        'last_name': lastName.trim(),
        'gender': gender,
        'birthday': bdayStr,
        'created_by': currentUser?.id ?? 'admin',
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'last_sent_at': now.toUtc().toIso8601String(),
        'failed_attempts': rateStatus.failedAttempts,
        'resend_count': currentResendCount,
        'device_id': deviceId,
        'locked_until': null,
      });
    } catch (e) {
      debugPrint('Supabase challenge upsert notice: $e');
    }

    return {
      'sent': true,
      'email': cleanEmail,
      'remainingCooldownSeconds': 60,
      'remainingOtpSeconds': 300,
      'failedAttempts': rateStatus.failedAttempts,
      'resendCount': currentResendCount,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> sendAdminTeacherVerificationCode({
    required String email,
    required String firstName,
    required String middleName,
    required String lastName,
    required String gender,
    required DateTime birthday,
    bool isResend = false,
  }) =>
      sendAdminTeacherVerification(
        email: email,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        gender: gender,
        birthday: birthday,
        isResend: isResend,
      );

  Future<Map<String, dynamic>> createTeacherDirectlyByAdmin({
    required String email,
    required String firstName,
    required String middleName,
    required String lastName,
    required String gender,
    required DateTime birthday,
  }) async {
    final teacherId = 'tch_${DateTime.now().millisecondsSinceEpoch}';
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
    final tempPassword =
        '${lastName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}${birthday.year}${birthday.month.toString().padLeft(2, '0')}${birthday.day.toString().padLeft(2, '0')}';

    try {
      await _supabaseClient.from('users').upsert({
        'id': teacherId,
        'email': email.trim().toLowerCase(),
        'role': 'teacher',
        'is_archived': false,
      });

      await _supabaseClient.from('teacher_profiles').upsert({
        'teacher_id': teacherId,
        'first_name': firstName.trim(),
        'middle_name': middleName.trim().isEmpty ? null : middleName.trim(),
        'last_name': lastName.trim(),
        'gender': gender,
        'birthday': bdayStr,
      });

      await _supabaseClient.from('teacher_settings').upsert({
        'teacher_id': teacherId,
        'status': 'pending_first_login',
        'is_setup_complete': false,
        'is_facebook_public': false,
        'is_phone_public': false,
      });
    } catch (e) {
      debugPrint('Pure Dart create teacher notice: $e');
    }

    return {
      'success': true,
      'teacherId': teacherId,
      'tempPassword': tempPassword,
    };
  }

  Future<Map<String, dynamic>> verifyAdminTeacherAndCreate({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    // 1. Check progressive lockout status
    final rateStatus = await RateLimitService.instance.checkStatus(
      feature: 'admin_add_teacher_otp',
      targetIdentifier: cleanEmail,
      maxAttempts: 5,
    );
    if (rateStatus.isLocked) {
      throw AdminTeacherException(
        'Too many incorrect codes. Please try again after ${rateStatus.formattedCountdown}.',
        maxAttemptsExceeded: true,
        failedAttempts: rateStatus.failedAttempts,
      );
    }

    // 2. Fetch challenge from admin_teacher_email_challenges
    final challenge = await _supabaseClient
        .from('admin_teacher_email_challenges')
        .select()
        .eq('email', cleanEmail)
        .maybeSingle();

    if (challenge == null) {
      throw const AdminTeacherException(
        'The verification code is invalid or has expired. Please request a new code.',
      );
    }

    final now = DateTime.now().toUtc();

    // 3. Check expiration (5 minutes / 300 seconds)
    final expiresAtStr = challenge['expires_at']?.toString();
    final expiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr)?.toUtc() : null;
    if (expiresAt == null || now.isAfter(expiresAt)) {
      throw const AdminTeacherException(
        'The verification code has expired (valid for 5 minutes). Please click Resend.',
      );
    }

    // 4. Verify code match
    final expectedCode = challenge['code_hash']?.toString().trim();
    if (cleanCode != expectedCode) {
      final failStatus = await RateLimitService.instance.recordFailure(
        feature: 'admin_add_teacher_otp',
        targetIdentifier: cleanEmail,
        maxAttempts: 5,
      );

      try {
        await _supabaseClient
            .from('admin_teacher_email_challenges')
            .update({
              'failed_attempts': failStatus.failedAttempts,
            })
            .eq('email', cleanEmail);
      } catch (e) {
        debugPrint('Supabase failed attempts update notice: $e');
      }

      if (failStatus.isLocked) {
        throw AdminTeacherException(
          'Too many incorrect codes. Please try again after ${failStatus.formattedCountdown}.',
          maxAttemptsExceeded: true,
          failedAttempts: failStatus.failedAttempts,
        );
      }

      final remaining = failStatus.attemptsRemaining;
      throw AdminTeacherException(
        'Incorrect verification code. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
        failedAttempts: failStatus.failedAttempts,
        remainingAttempts: remaining,
      );
    }

    // Code is valid! Clear rate limit for this email
    unawaited(RateLimitService.instance.clearRateLimit(
      feature: 'admin_add_teacher_otp',
      targetIdentifier: cleanEmail,
    ));

    // 5. Code is VALID! Extract details and create teacher account
    final firstName = challenge['first_name']?.toString() ?? '';
    final middleName = challenge['middle_name']?.toString();
    final lastName = challenge['last_name']?.toString() ?? '';
    final gender = challenge['gender']?.toString() ?? 'Male';
    final birthdayStr = challenge['birthday']?.toString() ?? '2000-01-01';
    final fullName = [
      firstName,
      if (middleName != null && middleName.isNotEmpty) middleName,
      lastName
    ].join(' ');

    // Temporary password: lastname + birthdate digits (e.g. yuri19990101)
    final bdayDigits = birthdayStr.replaceAll('-', '');
    final tempPassword =
        '${lastName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}$bdayDigits';

    // 6. Attempt Firebase Auth creation via Service Account Admin API (100% reliable)
    String? fbUid;
    try {
      fbUid = await FirebaseAuthAdminService.createUser(
        email: cleanEmail,
        password: tempPassword,
        displayName: fullName,
      );
    } catch (e) {
      if (e is AdminTeacherException) rethrow;
      debugPrint('Firebase Admin createUser notice: $e');
    }

    if (fbUid == null || fbUid.isEmpty) {
      throw const AdminTeacherException(
        'Failed to provision teacher in Firebase Authentication. Please check internet connection/credentials and try again.',
      );
    }

    final teacherId = fbUid;

    // 7. Insert/Upsert into Supabase tables
    await _supabaseClient.from('users').upsert({
      'id': teacherId,
      'email': cleanEmail,
      'role': 'teacher',
      'is_archived': false,
    });

    await _supabaseClient.from('teacher_profiles').upsert({
      'teacher_id': teacherId,
      'first_name': firstName,
      'middle_name':
          (middleName == null || middleName.isEmpty) ? null : middleName,
      'last_name': lastName,
      'gender': gender,
      'birthday': birthdayStr,
    });

    await _supabaseClient.from('teacher_settings').upsert({
      'teacher_id': teacherId,
      'status': 'pending_first_login',
      'is_setup_complete': false,
      'is_facebook_public': false,
      'is_phone_public': false,
    });

    // 8. Delete the challenge
    try {
      await _supabaseClient
          .from('admin_teacher_email_challenges')
          .delete()
          .eq('email', cleanEmail);
    } catch (e) {
      debugPrint('Supabase challenge delete notice: $e');
    }

    // 9. Dispatch welcome email with credentials
    try {
      await EmailService.instance.sendTeacherWelcomeEmail(
        recipientEmail: cleanEmail,
        teacherName: fullName,
        tempPassword: tempPassword,
      );
    } catch (mailErr) {
      debugPrint('Welcome email notice: $mailErr');
    }

    return {
      'success': true,
      'created': true,
      'email': cleanEmail,
      'fullName': fullName,
      'temporaryPassword': tempPassword,
      'teacherId': teacherId,
    };
  }

  // Teacher: Complete Academic Setup
  Future<bool> completeAcademicSetup({
    required String uid,
    required String gradeLevel,
    required String subjectName,
    required List<String> sections,
    required String schoolYear,
    required double wwWeight,
    required double ptWeight,
    required double exWeight,
  }) async {
    try {
      // 1. Get Subject ID
      final subjectResp = await _supabaseClient
          .from('subjects')
          .select('id')
          .eq('subject_name', subjectName)
          .limit(1)
          .maybeSingle();

      // If subject not found in catalog, we shouldn't fail completely, but for now we require it.
      if (subjectResp == null) return false;

      final subjectId = subjectResp['id'];

      // 2. Parse grade level
      final gradeLevelInt = gradeLevel.contains('11') ? 11 : 12;

      // 3. For each section, insert into `sections`
      for (final sec in sections) {
        final secResp = await _supabaseClient
            .from('sections')
            .insert({
              'name': sec,
              'grade_level': gradeLevelInt,
              'adviser_id': uid,
              'school_year': schoolYear,
            })
            .select('id')
            .single();
        final sectionId = secResp['id'];

        // 4. Create a dummy schedule
        final schedResp = await _supabaseClient
            .from('schedules')
            .insert({
              'teacher_id': uid,
              'section_id': sectionId,
              'subject_id': subjectId,
              'start_time': '08:00:00',
              'end_time': '09:00:00',
            })
            .select('id')
            .single();
        final schedId = schedResp['id'];

        // 5. Create gradebook_settings
        await _supabaseClient.from('gradebook_settings').insert({
          'schedule_id': schedId,
          'ww_weight': wwWeight,
          'pt_weight': ptWeight,
          'ex_weight': exWeight,
        });
      }

      await _supabaseClient
          .from('teacher_settings')
          .update({'is_setup_complete': true})
          .eq('teacher_id', uid);

      if (_currentUser != null && _currentUser!.id == uid) {
        _currentUser = _currentUser!.copyWith(
          isSetupComplete: true,
          departmentOrSection: subjectName,
          gradeLevel: gradeLevel,
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  custom.AccountStatus _parseStatus(String status) {
    switch (status.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'pending':
      case 'pendingfirstlogin':
        return custom.AccountStatus.pendingFirstLogin;
      case 'active':
        return custom.AccountStatus.active;
      case 'rejected':
        return custom.AccountStatus.rejected;
      case 'archived':
        return custom.AccountStatus.archived;
      case 'deactivated':
        return custom.AccountStatus.deactivated;
      default:
        return custom.AccountStatus.active;
    }
  }
}
