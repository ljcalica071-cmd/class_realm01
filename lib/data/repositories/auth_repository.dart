import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:class_realm/models/user_model.dart' as custom;
import 'package:class_realm/data/datasources/mock/mock_database.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/core/services/email_verification_service.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/firebase_options.dart';

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
  });

  final String message;
  final bool invalidCredentials;
  final bool providerRateLimited;

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

  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  custom.UserModel? _currentUser;
  custom.UserModel? get currentUser =>
      _currentUser ?? MockDatabase.instance.currentUser;

  void setCurrentUser(custom.UserModel user) {
    _currentUser = user;
    MockDatabase.instance.currentUser = user;
    LocalStorageService.saveUser(user);
  }

  // Sign In
  Future<custom.UserModel?> authenticate(String email, String password) async {
    // The parent prototype remains available until its real account flow is enabled.
    if (email == 'parent') {
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

    // Attempt Firebase Authentication for Teacher
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        _currentUser = await _getUserFromSupabase(userCredential.user!.uid);
        if (_currentUser == null) {
          throw Exception(
            "Firebase login succeeded, but user data was not found in Supabase Database. Please contact administrator.",
          );
        }
        await LocalStorageService.saveUser(_currentUser!);
        MockDatabase.instance.currentUser = _currentUser;
        return _currentUser;
      }
    } on firebase.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-email') {
        throw const LoginAttemptException(
          'Invalid email or password. Please check your credentials.',
          invalidCredentials: true,
        );
      }
      if (e.code == 'too-many-requests') {
        throw const LoginAttemptException(
          'Too many failed attempts. Try again after 15 minutes.',
          providerRateLimited: true,
        );
      }
      throw LoginAttemptException('Authentication Error: ${e.message}');
    } catch (e) {
      throw Exception(e.toString());
    }
    return null;
  }

  // Fast Login / Restore Session
  Future<custom.UserModel?> restoreSession() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      // 1. Check local cache first for instant load
      final cachedUser = LocalStorageService.getCachedUser();
      if (cachedUser != null && cachedUser.id == firebaseUser.uid) {
        _currentUser = cachedUser;
        MockDatabase.instance.currentUser = _currentUser;

        // 2. Quietly update from Supabase in the background
        _getUserFromSupabase(firebaseUser.uid)
            .then((updatedUser) {
              if (updatedUser != null) {
                _currentUser = updatedUser;
                MockDatabase.instance.currentUser = _currentUser;
                LocalStorageService.saveUser(updatedUser);
              }
            })
            .catchError((_) {});

        return _currentUser;
      }

      // If no cache, perform standard fetch
      try {
        _currentUser = await _getUserFromSupabase(firebaseUser.uid);
        if (_currentUser != null) {
          await LocalStorageService.saveUser(_currentUser!);
          MockDatabase.instance.currentUser = _currentUser;
          return _currentUser;
        }
      } catch (e) {
        print('Failed to restore session: $e');
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

      if (role == 'teacher') {
        final infoResp = await _supabaseClient
            .from('teacher_settings')
            .select()
            .eq('teacher_id', uid)
            .single();

        final profileResp = await _supabaseClient
            .from('teacher_profiles')
            .select()
            .eq('teacher_id', uid)
            .single();

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
        );
      } else if (role == 'student') {
        final infoResp = await _supabaseClient
            .from('student_settings')
            .select(
              'student_id, status, student_profiles!inner(student_id, lrn, first_name, middle_name, last_name, birthday, gender)',
            )
            .eq('student_id', uid)
            .single();
        final profileRaw = infoResp['student_profiles'];
        final Map<String, dynamic> profile = profileRaw is List
            ? (profileRaw.isNotEmpty
                  ? Map<String, dynamic>.from(profileRaw.first as Map)
                  : <String, dynamic>{})
            : Map<String, dynamic>.from(profileRaw as Map? ?? {});
        final enrollment = await _supabaseClient
            .from('student_enrollments')
            .select('subject_offerings(sections(section_name, grade_level))')
            .eq('student_id', uid)
            .eq('status', 'enrolled')
            .limit(1)
            .maybeSingle();
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
          status: _parseStatus(infoResp['status']?.toString() ?? 'active'),
        );
      } else if (role == 'parent') {
        final profileResp = await _supabaseClient
            .from('parent_profiles')
            .select(
              'parent_id, first_name, middle_name, last_name, contact_number, birthday, status',
            )
            .eq('parent_id', uid)
            .maybeSingle();

        final linksResp = await _supabaseClient
            .from('parent_student_links')
            .select('student_id, relationship')
            .eq('parent_id', uid);

        final links = linksResp as List;
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
        );
      }
      return null;
    } catch (e) {
      debugPrint('Failed to load user profile from Supabase: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    _currentUser = null;
    // Attempt to sign out of Firebase
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}

    // Also sign out of mock database just in case it was a student/parent
    MockDatabase.instance.logout();
  }

  Future<String> _firebaseIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Your sign-in session has expired. Please log in again.');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw Exception(
        'Unable to verify your sign-in session. Please log in again.',
      );
    }
    return token;
  }

  Future<Map<String, String>> _firebaseAuthHeaders({
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
  int _otpAttempts = 0;

  Future<Map<String, dynamic>> sendFirstLoginOtp() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('A signed-in user session is required.');
    }

    // Generate secure 6-digit OTP in pure Dart
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    _pendingOtpCode = code;
    _pendingOtpExpiry = DateTime.now().add(const Duration(minutes: 10));
    _otpAttempts = 0;

    debugPrint('========================================================');
    debugPrint(
      '[ClassRealm Pure Dart OTP] Verification code for ${user.email}: $code',
    );
    debugPrint('========================================================');

    try {
      await EmailService.instance.sendPasswordChangeOtpEmail(
        recipientEmail: user.email!,
        recipientName: user.displayName ?? 'ClassRealm User',
        otpCode: code,
      );
    } catch (_) {}

    return {'sent': true, 'email': user.email, 'expires_in_minutes': 10};
  }

  Future<FirstLoginOtpVerification> verifyFirstLoginOtp(String code) async {
    final cleanCode = code.trim();
    if (_pendingOtpCode == null || _pendingOtpExpiry == null) {
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'No verification code requested. Please request a new code.',
      );
    }

    if (DateTime.now().isAfter(_pendingOtpExpiry!)) {
      _pendingOtpCode = null;
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'Verification code has expired. Please request a new code.',
      );
    }

    _otpAttempts++;
    if (_otpAttempts > 5) {
      _pendingOtpCode = null;
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'Maximum verification attempts exceeded. Please request a new code.',
      );
    }

    if (cleanCode != _pendingOtpCode) {
      return FirstLoginOtpVerification(
        verified: false,
        reason: 'Invalid verification code. Please check and try again.',
        attemptsRemaining: 5 - _otpAttempts,
      );
    }

    _pendingOtpCode = null;
    return const FirstLoginOtpVerification(verified: true, reason: null);
  }

  // Complete first-login password setup in Pure Dart
  Future<String?> completeFirstLogin(String userId, String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.uid != userId) {
        return "No matching authenticated user found.";
      }
      await user.updatePassword(newPassword);

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

      final current = _currentUser;
      if (current != null && current.id == userId) {
        _currentUser = current.copyWith(status: custom.AccountStatus.active);
        MockDatabase.instance.currentUser = _currentUser;
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // --- FORGOT PASSWORD STATE & FLOW ---
  String? _forgotPasswordOtpCode;
  DateTime? _forgotPasswordOtpExpiry;
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

  /// Sends a secure pure Dart 6-digit OTP code to the requested email for password recovery.
  Future<Map<String, dynamic>> sendForgotPasswordOtp({
    required String email,
    String? recipientName,
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

    // Generate secure 6-digit OTP in pure Dart
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    _forgotPasswordOtpCode = code;
    _forgotPasswordOtpExpiry = DateTime.now().add(const Duration(minutes: 10));
    _forgotPasswordEmail = cleanEmail;
    _forgotPasswordAttempts = 0;
    _forgotPasswordVerified = false;

    debugPrint('========================================================');
    debugPrint(
      '[ClassRealm Pure Dart Forgot Password OTP] Verification code for $cleanEmail: $code',
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

    return {
      'sent': true,
      'email': cleanEmail,
      'expiresIn': 600,
      'resendAfter': 60,
      'resendCount': 0,
    };
  }

  /// Verifies the 6-digit OTP code entered by the user during password recovery.
  Future<FirstLoginOtpVerification> verifyForgotPasswordOtp(String code) async {
    final cleanCode = code.trim();
    if (_forgotPasswordOtpCode == null || _forgotPasswordOtpExpiry == null) {
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'No verification code requested. Please request a new code.',
      );
    }

    if (DateTime.now().isAfter(_forgotPasswordOtpExpiry!)) {
      _forgotPasswordOtpCode = null;
      _forgotPasswordVerified = false;
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'Verification code has expired. Please request a new code.',
      );
    }

    _forgotPasswordAttempts++;
    if (_forgotPasswordAttempts > 5) {
      _forgotPasswordOtpCode = null;
      _forgotPasswordVerified = false;
      return const FirstLoginOtpVerification(
        verified: false,
        reason: 'Maximum verification attempts exceeded. Please request a new code.',
        retryAfter: 900,
      );
    }

    if (cleanCode != _forgotPasswordOtpCode) {
      return FirstLoginOtpVerification(
        verified: false,
        reason: 'Invalid verification code. Please check and try again.',
        attemptsRemaining: 5 - _forgotPasswordAttempts,
      );
    }

    _forgotPasswordOtpCode = null;
    _forgotPasswordVerified = true;
    return const FirstLoginOtpVerification(verified: true, reason: null);
  }

  /// Updates password after successful OTP verification with strict security gate.
  Future<String?> updateForgottenPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Strict Security Gate
    if (!_forgotPasswordVerified || _forgotPasswordEmail != cleanEmail) {
      return 'Unauthorized: OTP verification must be completed before updating your password.';
    }

    try {
      final user = await getUserByEmail(cleanEmail);
      if (user == null) {
        return 'User account not found.';
      }

      // 1. Invoke Supabase Edge Function to update password in Firebase Authentication
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://wfilyatkfgqtybujmahf.supabase.co';
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

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
      if (resp.statusCode != 200 || respData?['success'] != true) {
        final err = respData?['error'] ?? 'Failed to update password in Firebase Auth.';
        debugPrint('[AuthRepository] reset-password failed: $err');
        return err.toString();
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

      // 3. Update local session or mock database if applicable
      final mockIndex = MockDatabase.instance.users.indexWhere(
        (u) => u.email.trim().toLowerCase() == cleanEmail,
      );
      if (mockIndex != -1) {
        final mockUser = MockDatabase.instance.users[mockIndex];
        MockDatabase.instance.users[mockIndex] = mockUser.copyWith(
          status: custom.AccountStatus.active,
        );
      }

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
            birthday: profile['birthday'] != null
                ? DateTime.parse(profile['birthday'].toString())
                : null,
            isSetupComplete: info['is_setup_complete'],
            status: _parseStatus(info['status']),
          ),
        );
      }
      return teachers;
    } catch (e) {
      return [];
    }
  }

  // Admin: Update Teacher Status
  Future<bool> updateTeacherStatus(String uid, String newStatus) async {
    try {
      await _supabaseClient
          .from('teacher_settings')
          .update({'status': newStatus})
          .eq('teacher_id', uid);
      return true;
    } catch (e) {
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

    // 2. Check for existing active challenge in admin_teacher_email_challenges
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

    final now = DateTime.now();

    if (priorChallenge != null) {
      // Check lockout
      final lockedUntilStr = priorChallenge['locked_until']?.toString();
      if (lockedUntilStr != null && lockedUntilStr.isNotEmpty) {
        final lockedUntil = DateTime.tryParse(lockedUntilStr);
        if (lockedUntil != null && now.isBefore(lockedUntil)) {
          throw const AdminTeacherException(
            'Too many incorrect codes. Please try again after 15 minutes.',
            maxAttemptsExceeded: true,
            failedAttempts: 5,
          );
        }
      }

      final priorFailedAttempts =
          (priorChallenge['failed_attempts'] as num?)?.toInt() ?? 0;
      if (priorFailedAttempts >= 5) {
        throw const AdminTeacherException(
          'Maximum verification attempts exceeded (5/5). Please click Back to recheck teacher details.',
          maxAttemptsExceeded: true,
          failedAttempts: 5,
        );
      }

      final expiresAtStr = priorChallenge['expires_at']?.toString();
      final expiresAt =
          expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
      final isChallengeActive = expiresAt != null && now.isBefore(expiresAt);

      final lastSentAtStr = priorChallenge['last_sent_at']?.toString();
      final lastSentAt =
          lastSentAtStr != null ? DateTime.tryParse(lastSentAtStr) : null;
      final secondsSinceLastSent =
          lastSentAt != null ? now.difference(lastSentAt).inSeconds : 999;

      // If an explicit resend, enforce 60s cooldown
      if (isResend && secondsSinceLastSent < 58) {
        final waitSec = (60 - secondsSinceLastSent).clamp(1, 60);
        throw AdminTeacherException(
            'Please wait ${waitSec}s before requesting another code.');
      }
    }

    // 3. Generate a fresh 6-digit OTP code (valid for 10 minutes)
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    final expiresAt = now.add(const Duration(minutes: 10));
    final currentFailedAttempts = isResend
        ? ((priorChallenge?['failed_attempts'] as num?)?.toInt() ?? 0)
        : 0;

    debugPrint('========================================================');
    debugPrint(
        '[ClassRealm Teacher OTP] Code for $cleanEmail: $code (Valid for 10 mins)');
    debugPrint('========================================================');

    // 4. Dispatch verification code via EmailService
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

    // 5. Persist challenge in Supabase admin_teacher_email_challenges
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';

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
        'expires_at': expiresAt.toIso8601String(),
        'last_sent_at': now.toIso8601String(),
        'failed_attempts': currentFailedAttempts,
        'locked_until': null,
      });
    } catch (e) {
      debugPrint('Supabase challenge upsert notice: $e');
    }

    return {
      'sent': true,
      'email': cleanEmail,
      'remainingCooldownSeconds': 60,
      'failedAttempts': currentFailedAttempts,
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
        'status': 'pendingFirstLogin',
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
        'status': 'pendingFirstLogin',
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

    // 1. Fetch challenge from admin_teacher_email_challenges
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

    final now = DateTime.now();

    // 2. Check lockout
    final lockedUntilStr = challenge['locked_until']?.toString();
    if (lockedUntilStr != null && lockedUntilStr.isNotEmpty) {
      final lockedUntil = DateTime.tryParse(lockedUntilStr);
      if (lockedUntil != null && now.isBefore(lockedUntil)) {
        throw const AdminTeacherException(
          'Too many incorrect codes. Please try again after 15 minutes.',
          maxAttemptsExceeded: true,
          failedAttempts: 5,
        );
      }
    }

    final failedAttempts =
        (challenge['failed_attempts'] as num?)?.toInt() ?? 0;
    if (failedAttempts >= 5) {
      throw const AdminTeacherException(
        'Maximum verification attempts exceeded (5/5). Please click Back to recheck teacher details.',
        maxAttemptsExceeded: true,
        failedAttempts: 5,
      );
    }

    // 3. Check expiration (10 minutes)
    final expiresAtStr = challenge['expires_at']?.toString();
    final expiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
    if (expiresAt == null || now.isAfter(expiresAt)) {
      throw const AdminTeacherException(
        'The verification code has expired (valid for 10 minutes). Please click Resend.',
      );
    }

    // 4. Verify code match
    final expectedCode = challenge['code_hash']?.toString().trim();
    if (cleanCode != expectedCode) {
      final newFailedAttempts = failedAttempts + 1;
      final lockedUntil = newFailedAttempts >= 5
          ? now.add(const Duration(minutes: 15)).toIso8601String()
          : null;

      try {
        await _supabaseClient
            .from('admin_teacher_email_challenges')
            .update({
              'failed_attempts': newFailedAttempts,
              'locked_until': lockedUntil,
            })
            .eq('email', cleanEmail);
      } catch (e) {
        debugPrint('Supabase failed attempts update notice: $e');
      }

      if (newFailedAttempts >= 5) {
        throw const AdminTeacherException(
          'Maximum verification attempts exceeded (5/5). Please click Back to recheck teacher details.',
          maxAttemptsExceeded: true,
          failedAttempts: 5,
        );
      }

      final remaining = 5 - newFailedAttempts;
      throw AdminTeacherException(
        'Incorrect verification code. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
        failedAttempts: newFailedAttempts,
        remainingAttempts: remaining,
      );
    }

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

    String teacherId = 'tch_${DateTime.now().millisecondsSinceEpoch}';

    // 6. Attempt Firebase Auth creation via Identity Toolkit REST API
    try {
      final apiKey = DefaultFirebaseOptions.web.apiKey;
      final fbRes = await http.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': tempPassword,
          'returnSecureToken': true,
        }),
      );
      if (fbRes.statusCode == 200) {
        final fbData = jsonDecode(fbRes.body);
        if (fbData is Map && fbData['localId'] != null) {
          teacherId = fbData['localId'].toString();
          final idToken = fbData['idToken']?.toString();
          if (idToken != null) {
            try {
              await http.post(
                Uri.parse(
                    'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$apiKey'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'idToken': idToken,
                  'displayName': fullName,
                }),
              );
            } catch (_) {}
          }
        }
      } else {
        final fbData = jsonDecode(fbRes.body);
        if (fbData is Map && fbData['error']?['message'] == 'EMAIL_EXISTS') {
          throw const AdminTeacherException(
              'This email is already registered in Firebase Authentication.');
        }
      }
    } catch (e) {
      if (e is AdminTeacherException) rethrow;
      debugPrint('Firebase Identity Toolkit notice: $e');
    }

    // 7. Insert/Upsert into Supabase tables
    await _supabaseClient.from('users').upsert({
      'id': teacherId,
      'email': cleanEmail,
      'role': 'teacher',
      'status': 'pendingFirstLogin',
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
      'status': 'pendingFirstLogin',
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

  // Admin: Delete Teacher Record (100% Pure Dart)
  Future<bool> deleteTeacherRecord(String uid) async {
    try {
      await _supabaseClient.from('users').delete().eq('id', uid);
      return true;
    } catch (e) {
      return false;
    }
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
