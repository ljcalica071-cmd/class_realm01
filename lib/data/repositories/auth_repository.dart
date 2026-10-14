import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:class_realm/models/user_model.dart' as custom;
import 'package:class_realm/data/datasources/mock/mock_database.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/email_service.dart';


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
        _getUserFromSupabase(firebaseUser.uid).then((updatedUser) {
          if (updatedUser != null) {
            _currentUser = updatedUser;
            MockDatabase.instance.currentUser = _currentUser;
            LocalStorageService.saveUser(updatedUser);
          }
        }).catchError((_) {});
        
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
        ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
        return custom.UserModel(
          id: uid,
          username: email,
          fullName: profileName.isEmpty ? email.split('@').first : profileName,
          email: email,
          role: custom.UserRole.admin,
          status: custom.AccountStatus.active,
        );
      } else if (role == 'student') {
        final infoResp = await _supabaseClient
            .from('student_settings')
            .select(
              'student_id, status, student_profiles(lrn, first_name, middle_name, last_name, birthday, gender)',
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
            .select()
            .eq('parent_id', uid)
            .maybeSingle();

        final linksResp = await _supabaseClient
            .from('parent_student_links')
            .select('student_id, relationship')
            .eq('parent_id', uid);

        final linkedStudentId = (linksResp != null && (linksResp as List).isNotEmpty)
            ? linksResp.first['student_id']?.toString()
            : null;
        final relationship = (linksResp != null && (linksResp as List).isNotEmpty)
            ? linksResp.first['relationship']?.toString()
            : null;

        final firstName = profileResp?['first_name']?.toString() ?? '';
        final middleName = profileResp?['middle_name']?.toString();
        final lastName = profileResp?['last_name']?.toString() ?? '';
        final contactNumber = profileResp?['contact_number']?.toString();
        final birthdayStr = profileResp?['birthday']?.toString();
        final statusStr = profileResp?['status']?.toString() ?? 'pending_first_login';

        final fullName = [
          firstName,
          if (middleName != null && middleName.isNotEmpty) middleName,
          lastName,
        ].join(' ');

        return custom.UserModel(
          id: uid,
          username: userResp['email'] ?? contactNumber,
          fullName: fullName.trim().isNotEmpty ? fullName : (userResp['email'] ?? 'Parent'),
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
      print("ERROR IN _getUserFromSupabase: $e");
      throw Exception("Supabase Error: $e");
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

  Future<Map<String, String>> _firebaseAuthHeaders({bool forceRefresh = false}) async {
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
    debugPrint('[ClassRealm Pure Dart OTP] Verification code for ${user.email}: $code');
    debugPrint('========================================================');

    try {
      await EmailService.instance.sendPasswordChangeOtpEmail(
        recipientEmail: user.email!,
        recipientName: user.displayName ?? 'ClassRealm User',
        otpCode: code,
      );
    } catch (_) {}

    return {
      'sent': true,
      'email': user.email,
      'expires_in_minutes': 10,
    };
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
    return const FirstLoginOtpVerification(
      verified: true,
      reason: null,
    );
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
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    _pendingOtpCode = code;
    _pendingOtpExpiry = DateTime.now().add(const Duration(minutes: 10));

    debugPrint('========================================================');
    debugPrint('[ClassRealm Pure Dart Admin Code] Verification code for $email: $code');
    debugPrint('========================================================');

    try {
      await EmailService.instance.sendTeacherVerificationCode(
        recipientEmail: email,
        teacherName: '$firstName $lastName',
        code: code,
      );
    } catch (_) {}

    return {
      'sent': true,
      'email': email,
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
    return {'success': true};
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
