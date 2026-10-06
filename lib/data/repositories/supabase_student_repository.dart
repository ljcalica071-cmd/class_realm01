import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/student_repository.dart';

class StudentEnrollmentResult {
  final String studentId;
  final bool createdAccount;
  final String? tempPassword;

  const StudentEnrollmentResult({
    required this.studentId,
    required this.createdAccount,
    this.tempPassword,
  });
}

class SupabaseStudentRepository implements StudentRepository {
  final SupabaseClient _client;

  SupabaseStudentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  @override
  Future<List<UserModel>> getStudents({
    String? section,
    bool includeArchived = false,
  }) async {
    // This will be replaced by the specific teacher's logic later
    return [];
  }

  Future<List<UserModel>> getStudentsForTeacher(
    String teacherId, {
    String? subjectId,
    bool includeArchived = false,
  }) async {
    // Query student_enrollments joined with student_info, student_profile, and subjects
    var query = _client
        .from('student_enrollments')
        .select('''
        id, status, created_at,
        student_info ( 
            student_id, lrn, email, status,
            student_profile ( firstname, middlename, lastname, gender, birthday )
        ),
        subjects!inner ( id, teacher_id, subject_name, section_name )
      ''')
        .eq('subjects.teacher_id', teacherId);

    if (subjectId != null) {
      query = query.eq('subject_id', subjectId);
    }

    if (!includeArchived) {
      query = query.eq('status', 'Enrolled');
    }

    final response = await query;
    return (response as List).map<UserModel>((row) {
      final studentInfo = row['student_info'];
      // Handle the case where student_profile is an array (if one-to-many relationship inferred) or an object
      final dynamic profileRaw = studentInfo['student_profile'];
      final Map<String, dynamic> profile = (profileRaw is List)
          ? (profileRaw.isNotEmpty ? profileRaw.first : {})
          : (profileRaw ?? {});

      final subject = row['subjects'];
      return UserModel(
        id: studentInfo['student_id'],
        username: studentInfo['lrn'] ?? '',
        fullName:
            [profile['firstname'], profile['middlename'], profile['lastname']]
                .where(
                  (name) => name != null && name.toString().trim().isNotEmpty,
                )
                .map((name) => name.toString().trim())
                .join(' '),
        role: UserRole.student,
        email: studentInfo['email'] ?? '',
        firstName: profile['firstname'] ?? 'Unknown',
        middleName: profile['middlename'],
        lastName: profile['lastname'] ?? 'Unknown',
        gender: profile['gender'],
        birthday: profile['birthday'] != null
            ? DateTime.parse(profile['birthday'])
            : null,
        lrn: studentInfo['lrn'],
        departmentOrSection: subject['section_name'],
        enrolledSubjectId: subject['id'],
        enrolledSubjectName: subject['subject_name'],
        status: _parseStatus(studentInfo['status']),
        isArchived: row['status'] == 'Archived',
      );
    }).toList();
  }

  AccountStatus _parseStatus(String? dbStatus) {
    switch (dbStatus?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'active':
        return AccountStatus.active;
      case 'archived':
        return AccountStatus.archived;
      case 'pendingfirstlogin':
        return AccountStatus.pendingFirstLogin;
      case 'pending':
        return AccountStatus.pending;
      default:
        return AccountStatus.active;
    }
  }

  @override
  Future<UserModel?> getStudentById(String id) async {
    return null;
  }

  @override
  Future<String?> createStudentAccount({
    required String firstName,
    required String middleName,
    required String lastName,
    required DateTime birthday,
    required String email,
    required String studentId, // Using LRN as studentId passed here
    required String gender,
    required String contactNumber,
  }) async {
    return null; // Implemented inside add logic
  }

  Future<StudentEnrollmentResult> enrollStudent({
    required String lrn,
    required String firstName,
    required String middleName,
    required String lastName,
    required DateTime birthday,
    required String email,
    required String gender,
    required String subjectId,
  }) async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception(
        'Please sign in again before creating a student account.',
      );
    }
    final idToken = await authUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Unable to verify the teacher session. Please sign in again.',
      );
    }

    final response = await _client.functions.invoke(
      'provision-student',
      headers: {
        'x-firebase-token': idToken,
        'x-firebase-api-key':
            firebase_auth.FirebaseAuth.instance.app.options.apiKey,
      },
      body: {
        'lrn': lrn,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'birthday':
            '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}',
        'email': email,
        'gender': gender,
        'subjectId': subjectId,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw Exception(
        'Student account service returned an unexpected response.',
      );
    }

    return StudentEnrollmentResult(
      studentId: data['studentId'].toString(),
      createdAccount: data['createdAccount'] == true,
      tempPassword: data['tempPassword']?.toString(),
    );
  }

  @override
  Future<void> updateStudent(
    String id,
    String fullName,
    String studentId,
    String section,
  ) async {}

  @override
  Future<void> updateStudentFull({
    required String id,
    required String firstName,
    required String middleName,
    required String lastName,
    required String email,
    required String studentId,
    required String gender,
    required DateTime birthday,
    required String subjectId,
  }) async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception(
        'Please sign in again before updating a student account.',
      );
    }
    final idToken = await authUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Unable to verify the teacher session. Please sign in again.',
      );
    }

    final response = await _client.functions.invoke(
      'update-student',
      headers: {
        'x-firebase-token': idToken,
        'x-firebase-api-key':
            firebase_auth.FirebaseAuth.instance.app.options.apiKey,
      },
      body: {
        'studentId': id,
        'subjectId': subjectId,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'email': email,
        'lrn': studentId,
        'gender': gender,
        'birthday':
            '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}',
      },
    );
    if (response.data is Map && response.data['error'] != null) {
      throw Exception(response.data['error'].toString());
    }
  }

  @override
  Future<void> archiveStudent(String id, [String? subjectId]) async {
    if (subjectId != null) {
      await _client
          .from('student_enrollments')
          .update({'status': 'Archived'})
          .match({'student_id': id, 'subject_id': subjectId});
    }
  }

  @override
  Future<void> restoreStudent(String id, [String? subjectId]) async {
    if (subjectId != null) {
      await _client
          .from('student_enrollments')
          .update({'status': 'Enrolled'})
          .match({'student_id': id, 'subject_id': subjectId});
    }
  }

  @override
  Future<void> deactivateStudent(String id) async {}

  @override
  Future<void> reactivateStudent(String id) async {}

  @override
  Future<void> permanentlyDeleteStudent(String id, [String? subjectId]) async {
    if (subjectId != null) {
      await _client.from('student_enrollments').delete().match({
        'student_id': id,
        'subject_id': subjectId,
      });
    }
  }
}
