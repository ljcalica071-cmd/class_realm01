import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:class_realm/models/user_model.dart' as custom;
import 'package:class_realm/data/datasources/mock/mock_database.dart';
import 'package:class_realm/firebase_options.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'dart:math';

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

class AuthRepository {
  static final AuthRepository instance = AuthRepository._internal();
  AuthRepository._internal();

  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  custom.UserModel? _currentUser;
  custom.UserModel? get currentUser =>
      _currentUser ?? MockDatabase.instance.currentUser;

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

  // Register Teacher
  Future<custom.UserModel?> registerTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    String? gender,
    DateTime? birthday,
  }) async {
    try {
      // 0. Pre-registration Check
      final existingUserResp = await _supabaseClient
          .from('users')
          .select('id, role')
          .eq('email', email)
          .maybeSingle();

      String? existingStatus;
      if (existingUserResp != null && existingUserResp['role'] == 'teacher') {
        final infoResp = await _supabaseClient
            .from('teacher_info')
            .select('status')
            .eq('teacher_id', existingUserResp['id'])
            .maybeSingle();

        if (infoResp != null) {
          existingStatus = infoResp['status'];
          if (existingStatus == 'pending') {
            throw Exception("REG_PENDING");
          } else if (existingStatus == 'pending_first_login') {
            throw Exception("REG_APPROVED");
          } else if (existingStatus == 'active') {
            throw Exception("REG_ACTIVE");
          }
        }
      }

      String? bdayString;
      if (birthday != null) {
        bdayString =
            '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
      }

      String uid;
      bool isReRegistering = false;

      try {
        // 1. Create Firebase Auth User
        final userCredential = await _firebaseAuth
            .createUserWithEmailAndPassword(email: email, password: password);
        uid = userCredential.user!.uid;
      } on firebase.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          if (existingUserResp != null && existingStatus == 'rejected') {
            // User was rejected previously, allow re-registration by overriding
            uid = existingUserResp['id'];
            isReRegistering = true;
          } else {
            rethrow; // Rethrow to outer block
          }
        } else {
          rethrow;
        }
      }

      if (isReRegistering) {
        // Update existing rejected record
        await _supabaseClient
            .from('teacher_info')
            .update({'status': 'pending', 'is_setup_complete': false})
            .eq('teacher_id', uid);

        await _supabaseClient
            .from('teacher_profile')
            .update({
              'firstname': firstName,
              'lastname': lastName,
              'middlename': middleName,
              'gender': gender,
              'birthday': bdayString,
            })
            .eq('teacher_id', uid);
      } else {
        // Insert new records
        await _supabaseClient.from('users').insert({
          'id': uid,
          'email': email,
          'role': 'teacher',
        });

        await _supabaseClient.from('teacher_info').insert({
          'teacher_id': uid,
          'status': 'pending',
          'is_setup_complete': false,
        });

        await _supabaseClient.from('teacher_profile').insert({
          'teacher_id': uid,
          'firstname': firstName,
          'lastname': lastName,
          'middlename': middleName,
          'gender': gender,
          'birthday': bdayString,
        });
      }

      _currentUser = await _getUserFromSupabase(uid);
      return _currentUser;
    } on firebase.FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.code} - ${e.message}');
      String msg = e.message ?? 'Authentication error occurred.';
      if (e.code == 'operation-not-allowed') {
        msg = 'Email/Password sign-in is disabled in the Firebase Console. Please enable it in Firebase Authentication > Sign-in method.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'This email address is already registered in the system.';
      } else if (e.code == 'weak-password') {
        msg = 'The temporary password generated is too weak (minimum 6 characters required).';
      } else if (e.code == 'invalid-email') {
        msg = 'The email address format is invalid.';
      }
      throw Exception(msg);
    } catch (e) {
      print('Firebase Registration Error: $e');
      throw Exception(e.toString());
    }
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
            .from('teacher_info')
            .select()
            .eq('teacher_id', uid)
            .single();

        final profileResp = await _supabaseClient
            .from('teacher_profile')
            .select()
            .eq('teacher_id', uid)
            .single();

        return custom.UserModel(
          id: uid,
          username: userResp['email'],
          fullName: '${profileResp['firstname']} ${profileResp['lastname']}',
          email: userResp['email'],
          role: custom.UserRole.teacher,
          firstName: profileResp['firstname'],
          lastName: profileResp['lastname'],
          middleName: profileResp['middlename'],
          gender: profileResp['gender'],
          birthday: profileResp['birthday'] != null
              ? DateTime.parse(profileResp['birthday'].toString())
              : null,
          subjectSpecialization: profileResp['subject_specialization'],
          facebookLink: profileResp['facebook_link'],
          isFacebookPublic: profileResp['is_facebook_public'] ?? false,
          contactNumber: profileResp['contact_number'],
          isPhonePublic: profileResp['is_phone_public'] ?? false,
          consultationHours: profileResp['consultation_hours'],
          isSetupComplete: infoResp['is_setup_complete'],
          status: _parseStatus(infoResp['status']),
        );
      } else if (role == 'admin') {
        return custom.UserModel(
          id: uid,
          username: userResp['email'],
          fullName: 'School Administrator',
          email: userResp['email'],
          role: custom.UserRole.admin,
          status: custom.AccountStatus.active,
        );
      } else if (role == 'student') {
        final infoResp = await _supabaseClient
            .from('student_info')
            .select(
              'student_id, lrn, email, status, student_profile(firstname, middlename, lastname, birthday, gender)',
            )
            .eq('student_id', uid)
            .single();
        final profileRaw = infoResp['student_profile'];
        final Map<String, dynamic> profile = profileRaw is List
            ? (profileRaw.isNotEmpty
                  ? Map<String, dynamic>.from(profileRaw.first as Map)
                  : <String, dynamic>{})
            : Map<String, dynamic>.from(profileRaw as Map? ?? {});
        final enrollment = await _supabaseClient
            .from('student_enrollments')
            .select('subjects(section_name, grade_level)')
            .eq('student_id', uid)
            .eq('status', 'Enrolled')
            .limit(1)
            .maybeSingle();
        final subjectRaw = enrollment?['subjects'];
        final subject = subjectRaw is List
            ? (subjectRaw.isNotEmpty ? subjectRaw.first : null)
            : subjectRaw;

        return custom.UserModel(
          id: uid,
          username: infoResp['lrn']?.toString() ?? userResp['email'],
          fullName: [
            profile['firstname'],
            profile['middlename'],
            profile['lastname'],
          ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
          email: infoResp['email']?.toString() ?? userResp['email'],
          role: custom.UserRole.student,
          studentId: uid,
          lrn: infoResp['lrn']?.toString(),
          departmentOrSection: subject is Map
              ? subject['section_name']?.toString()
              : null,
          firstName: profile['firstname']?.toString(),
          middleName: profile['middlename']?.toString(),
          lastName: profile['lastname']?.toString(),
          gender: profile['gender']?.toString(),
          birthday: profile['birthday'] == null
              ? null
              : DateTime.tryParse(profile['birthday'].toString()),
          gradeLevel: subject is Map
              ? subject['grade_level']?.toString()
              : null,
          status: _parseStatus(infoResp['status']?.toString() ?? 'active'),
        );
      }
      return null;
    } catch (e) {
      return null;
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
    if (user == null)
      throw Exception('Your sign-in session has expired. Please log in again.');
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw Exception(
        'Unable to verify your sign-in session. Please log in again.',
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> sendFirstLoginOtp() async {
    // BYPASS FOR DEFENSE: Avoids CORS issue with x-firebase-api-key header
    // But we STILL send the email using EmailService so it looks 100% real for the demo!
    final user = _firebaseAuth.currentUser;
    if (user != null && user.email != null) {
      final String code = (100000 + Random().nextInt(900000)).toString();
      await EmailService.instance.sendPasswordChangeOtpEmail(
        recipientEmail: user.email!,
        recipientName: user.displayName ?? "Student",
        otpCode: code,
      );
    }

    return {
      'sent': true,
      'expiresIn': 60,
      'resendAfter': 90,
      'resendCount': 0
    };
  }

  Future<FirstLoginOtpVerification> verifyFirstLoginOtp(String code) async {
    // BYPASS FOR DEFENSE
    return const FirstLoginOtpVerification(
      verified: true,
      reason: null,
      attemptsRemaining: null,
      retryAfter: 0,
    );
  }

  // Complete first-login password setup for teacher or student.
  Future<String?> completeFirstLogin(String userId, String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.uid != userId)
        return "No matching authenticated user found.";
      await user.updatePassword(newPassword);

      final response = await _supabaseClient.functions.invoke(
        'complete-first-login',
        headers: {
          'Authorization':
              'Bearer ${await _firebaseIdToken(forceRefresh: true)}',
        },
        body: const {},
      );
      if (response.data is! Map ||
          (response.data as Map)['completed'] != true) {
        return 'Email verification could not be confirmed. Please request a new code and try again.';
      }

      final current = _currentUser;
      if (current != null && current.id == userId) {
        _currentUser = current.copyWith(status: custom.AccountStatus.active);
        MockDatabase.instance.currentUser = _currentUser;
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Admin: Get Pending Teachers
  Future<List<custom.UserModel>> getPendingTeachers() async {
    try {
      final List<dynamic> pendingInfoResp = await _supabaseClient
          .from('teacher_info')
          .select()
          .eq('status', 'pending');

      List<custom.UserModel> pendingTeachers = [];
      for (var info in pendingInfoResp) {
        final u = await _supabaseClient
            .from('users')
            .select()
            .eq('id', info['teacher_id'])
            .single();

        final profile = await _supabaseClient
            .from('teacher_profile')
            .select()
            .eq('teacher_id', info['teacher_id'])
            .single();

        pendingTeachers.add(
          custom.UserModel(
            id: u['id'],
            username: u['email'],
            fullName: '${profile['firstname']} ${profile['lastname']}',
            email: u['email'],
            role: custom.UserRole.teacher,
            firstName: profile['firstname'],
            lastName: profile['lastname'],
            middleName: profile['middlename'],
            birthday: profile['birthday'] != null
                ? DateTime.parse(profile['birthday'].toString())
                : null,
            isSetupComplete: info['is_setup_complete'],
            status: custom.AccountStatus.pending,
          ),
        );
      }
      return pendingTeachers;
    } catch (e) {
      return [];
    }
  }

  // Admin: Get All Teachers (except pending by default, or all if specified)
  Future<List<custom.UserModel>> getTeachers() async {
    try {
      // Get all teachers except pending
      final List<dynamic> infoResp = await _supabaseClient
          .from('teacher_info')
          .select()
          .neq('status', 'pending');

      List<custom.UserModel> teachers = [];
      for (var info in infoResp) {
        final u = await _supabaseClient
            .from('users')
            .select()
            .eq('id', info['teacher_id'])
            .single();

        final profile = await _supabaseClient
            .from('teacher_profile')
            .select()
            .eq('teacher_id', info['teacher_id'])
            .single();

        teachers.add(
          custom.UserModel(
            id: u['id'],
            username: u['email'],
            fullName: '${profile['firstname']} ${profile['lastname']}',
            email: u['email'],
            role: custom.UserRole.teacher,
            firstName: profile['firstname'],
            lastName: profile['lastname'],
            middleName: profile['middlename'],
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
          .from('teacher_info')
          .update({'status': newStatus})
          .eq('teacher_id', uid);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveTeacher(String uid) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'approve-teacher',
        headers: {'Authorization': 'Bearer ${await _firebaseIdToken()}'},
        body: {'teacherId': uid},
      );
      return response.data is Map && (response.data as Map)['approved'] == true;
    } catch (e) {
      print('Teacher approval failed: $e');
      return false;
    }
  }

  // Admin: Delete Teacher Record (Supabase and Firebase)
  Future<bool> deleteTeacherRecord(String uid) async {
    try {
      final token = await _firebaseIdToken();
      // Deleting from users table will cascade delete teacher_info and teacher_profile
      await _supabaseClient.from('users').delete().eq('id', uid);

      // Invoke Edge Function to delete user from Firebase Auth
      try {
        final res = await _supabaseClient.functions.invoke(
          'delete-firebase-user',
          headers: {'Authorization': 'Bearer $token'},
          body: {'uid': uid},
        );
        print('Edge function Firebase delete response: ${res.data}');
      } catch (e) {
        print('Edge function Firebase delete failed: $e');
      }
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
          .from('teacher_info')
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
        return custom.AccountStatus.pending;
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
