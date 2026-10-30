import 'package:class_realm/core/services/app_data_cache.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/student_repository.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/core/services/firebase_auth_admin_service.dart';

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
    void Function(List<UserModel> fresh)? onFreshData,
  }) async {
    final cacheKey = 'teacher_students_${teacherId}_${subjectId ?? "all"}_$includeArchived';
    final cached = AppDataCache.instance.getCached<List<UserModel>>(
      cacheKey,
      (json) => (json as List)
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    if (cached != null && AppDataCache.instance.isFresh(cacheKey)) {
      return cached;
    }
    // 1. Fetch live cloud students first to ensure real registered email and Supabase status
    try {
      final cloudStudents = await _syncStudentsFromCloud(
        teacherId: teacherId,
        subjectId: subjectId,
        includeArchived: includeArchived,
      );
      if (cloudStudents.isNotEmpty || includeArchived) {
        unawaited(AppDataCache.instance.setCache(
          cacheKey,
          cloudStudents.map((u) => u.toJson()).toList(),
        ));
        onFreshData?.call(cloudStudents);
        return cloudStudents;
      }
    } catch (e) {
      debugPrint(
        'Cloud sync error in getStudentsForTeacher, falling back to local: $e',
      );
    }

    // 2. FAST LOCAL DRIFT SQLITE READ (offline fallback)
    try {
      final List<LocalStudent> localStudents;
      if (subjectId != null && subjectId.isNotEmpty) {
        localStudents = await AppDatabase.instance.getStudentsForOffering(
          subjectId,
        );
      } else {
        localStudents = await AppDatabase.instance.getAllStudents();
      }

      if (localStudents.isNotEmpty) {
        return localStudents.map((st) {
          final fullName = [
            st.firstName,
            st.middleName,
            st.lastName,
          ].where((name) => name != null && name.trim().isNotEmpty).join(' ');

          return UserModel(
            id: st.studentId,
            username: st.lrn ?? '',
            fullName: fullName.isEmpty ? 'Student' : fullName,
            role: UserRole.student,
            email: '',
            firstName: st.firstName,
            middleName: st.middleName,
            lastName: st.lastName,
            gender: st.gender,
            lrn: st.lrn,
            departmentOrSection: st.departmentOrSection,
            status: AccountStatus.active,
            isArchived: false,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Drift local students read notice: $e');
    }

    return [];
  }

  Future<List<UserModel>> _syncStudentsFromCloud({
    required String teacherId,
    String? subjectId,
    bool includeArchived = false,
  }) async {
    try {
      var query = _client
          .from('student_enrollments')
          .select('''
            id, status, created_at,
            student_profiles!inner ( 
              student_id, lrn, first_name, middle_name, last_name, gender, birthday,
              users ( email, is_archived )
            ),
            subject_offerings!inner ( 
              id, teacher_id,
              subjects ( id, subject_name ),
              sections ( id, section_name )
            )
          ''')
          .eq('subject_offerings.teacher_id', teacherId);

      if (subjectId != null) {
        query = query.eq('subject_offerings.id', subjectId);
      }

      if (!includeArchived) {
        query = query.ilike('status', 'enrolled');
      } else {
        query = query.ilike('status', 'archived');
      }

      final response = await query;
      if ((response as List).isEmpty) {
        return [];
      }

      // Collect student IDs to query student_settings for authoritative status
      final studentIds = (response as List)
          .map(
            (r) => (r['student_profiles'] as Map?)?['student_id']?.toString(),
          )
          .whereType<String>()
          .toSet()
          .toList();

      final Map<String, String> studentSettingsStatus = {};
      if (studentIds.isNotEmpty) {
        try {
          final settingsRes = await _client
              .from('student_settings')
              .select('student_id, status')
              .inFilter('student_id', studentIds);
          for (final row in (settingsRes as List)) {
            final sid = row['student_id']?.toString();
            final st = row['status']?.toString();
            if (sid != null && st != null) {
              studentSettingsStatus[sid] = st;
            }
          }
        } catch (settingsErr) {
          debugPrint('student_settings fetch notice: $settingsErr');
        }
      }

      final mapped = (response as List).map<UserModel>((row) {
        final profile = row['student_profiles'] as Map<String, dynamic>? ?? {};
        final offering =
            row['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
        final sec = offering['sections'] as Map<String, dynamic>? ?? {};

        final fullName =
            [
                  profile['first_name'],
                  profile['middle_name'],
                  profile['last_name'],
                ]
                .where(
                  (name) => name != null && name.toString().trim().isNotEmpty,
                )
                .join(' ');

        final usersData = profile['users'] as Map<String, dynamic>? ?? {};
        final studentId = profile['student_id']?.toString() ?? '';
        final realEmail = usersData['email']?.toString() ?? '';

        final enrollmentStatus = row['status']?.toString().toLowerCase();
        final isEnrollmentArchived = enrollmentStatus == 'archived';
        final isUserArchived = usersData['is_archived'] == true;
        final isArchived = isEnrollmentArchived || isUserArchived;

        AccountStatus accountStatus;
        if (isArchived) {
          accountStatus = AccountStatus.archived;
        } else {
          final rawStatus =
              (studentSettingsStatus[studentId] ??
                      usersData['status']?.toString() ??
                      'pending_first_login')
                  .toLowerCase()
                  .replaceAll(RegExp(r'[\s_-]'), '');
          if (rawStatus == 'active') {
            accountStatus = AccountStatus.active;
          } else if (rawStatus == 'pending' ||
              rawStatus == 'pendingfirstlogin') {
            accountStatus = AccountStatus.pendingFirstLogin;
          } else if (rawStatus == 'deactivated') {
            accountStatus = AccountStatus.deactivated;
          } else {
            accountStatus = AccountStatus.pendingFirstLogin;
          }
        }

        return UserModel(
          id: studentId,
          username: profile['lrn']?.toString() ?? realEmail,
          fullName: fullName.isEmpty ? 'Student' : fullName,
          role: UserRole.student,
          email: realEmail,
          firstName: profile['first_name']?.toString() ?? 'Unknown',
          middleName: profile['middle_name']?.toString(),
          lastName: profile['last_name']?.toString() ?? 'Unknown',
          gender: profile['gender']?.toString(),
          birthday: profile['birthday'] != null
              ? DateTime.tryParse(profile['birthday'].toString())
              : null,
          lrn: profile['lrn']?.toString(),
          departmentOrSection: sec['section_name']?.toString(),
          enrolledSubjectId:
              sub['id']?.toString() ?? offering['id']?.toString(),
          enrolledSubjectName: sub['subject_name']?.toString(),
          status: accountStatus,
          isArchived: isArchived,
        );
      }).toList();

      // Batch persist to Drift SQLite safely without blocking data return on web
      try {
        final companions = mapped
            .map(
              (u) => LocalStudentsCompanion.insert(
                studentId: u.id,
                lrn: Value(u.lrn),
                firstName: u.firstName ?? 'Student',
                middleName: Value(u.middleName),
                lastName: u.lastName ?? '',
                gender: Value(u.gender ?? 'unspecified'),
                departmentOrSection: Value(u.departmentOrSection),
              ),
            )
            .toList();

        await AppDatabase.instance.batch((b) {
          b.insertAllOnConflictUpdate(
            AppDatabase.instance.localStudents,
            companions,
          );
        });
      } catch (dbErr) {
        debugPrint('Drift local students save notice on web: $dbErr');
      }

      return mapped;
    } catch (e) {
      debugPrint('Error getting students for teacher: $e');
      return [];
    }
  }

  @override
  Future<UserModel?> getStudentById(String id) async {
    try {
      final row = await _client
          .from('users')
          .select('''
            id,
            email,
            first_name,
            middle_name,
            last_name,
            role,
            account_status,
            is_archived,
            student_profiles ( lrn, gender, birthdate, grade_level )
          ''')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      final profile = row['student_profiles'] is Map
          ? row['student_profiles'] as Map
          : (row['student_profiles'] is List &&
                    (row['student_profiles'] as List).isNotEmpty
                ? (row['student_profiles'] as List).first as Map
                : const <String, dynamic>{});
      final fName = row['first_name']?.toString() ?? '';
      final mName = row['middle_name']?.toString();
      final lName = row['last_name']?.toString() ?? '';
      return UserModel(
        id: row['id'].toString(),
        username: row['email']?.toString() ?? '',
        fullName: [
          fName,
          mName,
          lName,
        ].where((s) => s != null && s.isNotEmpty).join(' '),
        email: row['email']?.toString() ?? '',
        role: UserRole.student,
        firstName: fName,
        middleName: mName,
        lastName: lName,
        lrn: profile['lrn']?.toString(),
        gender: profile['gender']?.toString(),
        birthday: profile['birthdate'] != null
            ? DateTime.tryParse(profile['birthdate'].toString())
            : null,
        gradeLevel: profile['grade_level'] != null
            ? 'Grade ${profile['grade_level']}'
            : null,
        isArchived: row['is_archived'] == true,
      );
    } catch (e) {
      debugPrint('Error fetching student by id $id: $e');
      return null;
    }
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
    bool skipEmail = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
    final cleanLastName = lastName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final tempPassword =
        '$cleanLastName${birthday.year}${birthday.month.toString().padLeft(2, '0')}${birthday.day.toString().padLeft(2, '0')}';
    final studentFullName = [
      firstName,
      middleName,
      lastName,
    ].where((s) => s.isNotEmpty).join(' ');

    // 0. Check if student already exists globally by LRN (ClassRealm Cross-Teacher Reuse)
    String? existingStudentId;
    try {
      final existingProfile = await _client
          .from('student_profiles')
          .select('student_id, first_name, last_name, lrn')
          .eq('lrn', lrn)
          .maybeSingle();

      if (existingProfile != null && existingProfile['student_id'] != null) {
        final existingFirst = (existingProfile['first_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final existingLast = (existingProfile['last_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final inputFirst = firstName.trim().toLowerCase();
        final inputLast = lastName.trim().toLowerCase();

        // Security / Data Integrity: If LRN exists but name does not match, reject as conflict
        if (existingFirst != inputFirst || existingLast != inputLast) {
          final registeredName =
              '${existingProfile['first_name']} ${existingProfile['last_name']}'
                  .trim();
          throw Exception(
            'LRN Conflict: LRN $lrn is already registered to "$registeredName". '
            'You cannot register this LRN with a different name ("$studentFullName"). '
            'Please verify the student\'s LRN with the school registrar or previous teacher.',
          );
        }

        existingStudentId = existingProfile['student_id'].toString();
      }
    } catch (e) {
      if (e.toString().contains('LRN Conflict')) rethrow;
      debugPrint('LRN lookup notice: $e');
    }

    if (existingStudentId != null && existingStudentId.isNotEmpty) {
      // Re-use global identity without touching credentials or recreating auth
      try {
        await _client.from('student_enrollments').upsert({
          'student_id': existingStudentId,
          'subject_offering_id': subjectId,
          'status': 'enrolled',
        });
      } catch (e) {
        debugPrint('Cross-teacher enrollment error: $e');
      }

      // Persist locally to Drift SQLite
      try {
        await AppDatabase.instance
            .into(AppDatabase.instance.localStudents)
            .insertOnConflictUpdate(
              LocalStudentsCompanion.insert(
                studentId: existingStudentId,
                lrn: Value(lrn),
                firstName: firstName,
                middleName: Value(middleName),
                lastName: lastName,
                gender: Value(gender),
              ),
            );
      } catch (_) {}

      AppDataCache.instance.invalidatePrefix('teacher_students_');
    return StudentEnrollmentResult(
        studentId: existingStudentId,
        createdAccount: false,
        tempPassword: null,
      );
    }

    // New student candidate
    String? fbUid;
    try {
      fbUid = await FirebaseAuthAdminService.createUser(
        email: cleanEmail,
        password: tempPassword,
        displayName: studentFullName,
      );
    } catch (e) {
      debugPrint('Firebase student creation error: $e');
    }

    final studentId = fbUid ?? 'std_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // 1. Direct Pure Dart insert into Supabase users, profiles, and settings
      await _client.from('users').upsert({
        'id': studentId,
        'email': cleanEmail,
        'role': 'student',
        'is_archived': false,
      });

      await _client.from('student_profiles').upsert({
        'student_id': studentId,
        'lrn': lrn,
        'first_name': firstName,
        'middle_name': middleName.isEmpty ? null : middleName,
        'last_name': lastName,
        'gender': gender,
        'birthday': bdayStr,
      });

      await _client.from('student_settings').upsert({
        'student_id': studentId,
        'status': 'pending_first_login',
      });

      await _client.from('student_enrollments').upsert({
        'student_id': studentId,
        'subject_offering_id': subjectId,
        'status': 'enrolled',
      });
    } catch (e) {
      debugPrint('Pure Dart enroll notice: $e');
      // Concurrency / Race Condition Handler:
      // If another teacher registered this student at the exact same millisecond,
      // re-query student_profiles by LRN to recover their global student_id and enroll.
      try {
        final doubleCheck = await _client
            .from('student_profiles')
            .select('student_id')
            .eq('lrn', lrn)
            .maybeSingle();
        if (doubleCheck != null && doubleCheck['student_id'] != null) {
          final winnerId = doubleCheck['student_id'].toString();
          await _client.from('student_enrollments').upsert({
            'student_id': winnerId,
            'subject_offering_id': subjectId,
            'status': 'enrolled',
          });
          return StudentEnrollmentResult(
            studentId: winnerId,
            createdAccount: false,
            tempPassword: null,
          );
        }
      } catch (raceErr) {
        debugPrint('Race condition resolution error: $raceErr');
      }
    }

    // 2. Persist locally to Drift SQLite
    try {
      await AppDatabase.instance
          .into(AppDatabase.instance.localStudents)
          .insertOnConflictUpdate(
            LocalStudentsCompanion.insert(
              studentId: studentId,
              lrn: Value(lrn),
              firstName: firstName,
              middleName: Value(middleName),
              lastName: lastName,
              gender: Value(gender),
            ),
          );
    } catch (_) {}

    // Send welcome email with student credentials if not skipped (e.g. In bulk queues)
    if (!skipEmail) {
      try {
        await EmailService.instance.sendStudentWelcomeEmail(
          recipientEmail: cleanEmail,
          studentName: studentFullName,
          tempPassword: tempPassword,
        );
      } catch (e) {
        debugPrint(
          '[SupabaseStudentRepository] Student welcome email error: $e',
        );
      }
    }

    return StudentEnrollmentResult(
      studentId: studentId,
      createdAccount: true,
      tempPassword: tempPassword,
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
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
    try {
      await _client
          .from('student_profiles')
          .update({
            'lrn': studentId,
            'first_name': firstName,
            'middle_name': middleName.isEmpty ? null : middleName,
            'last_name': lastName,
            'gender': gender,
            'birthday': bdayStr,
          })
          .eq('student_id', id);

      await _client.from('users').update({'email': email}).eq('id', id);
    } catch (e) {
      debugPrint('Pure Dart student update notice: $e');
    }
  }

  @override
  Future<void> archiveStudent(
    String id, [
    String? subjectId,
    String? currentStatusHint,
  ]) async {
    if (subjectId != null) {
      await _client
          .from('student_enrollments')
          .update({'status': 'Archived'})
          .match({'student_id': id, 'subject_offering_id': subjectId});
    } else {
      await _client
          .from('student_enrollments')
          .update({'status': 'Archived'})
          .eq('student_id', id);
    }

    // Only perform global user account archival if this is a school-wide archive (subjectId == null)
    if (subjectId == null) {
      try {
        await _client.from('users').update({'is_archived': true}).eq('id', id);
        try {
          final cur = await _client
              .from('student_settings')
              .select('status')
              .eq('student_id', id)
              .maybeSingle();
          final currentStatus = cur?['status']?.toString();
          final statusToSave =
              (currentStatus != null &&
                  currentStatus.isNotEmpty &&
                  currentStatus != 'archived')
              ? currentStatus
              : (currentStatusHint ?? 'active');

          await _client
              .from('student_settings')
              .update({'previous_status': statusToSave, 'status': 'archived'})
              .eq('student_id', id);
        } catch (_) {}
        try {
          await FirebaseAuthAdminService.setUserDisabled(
            uid: id,
            disabled: true,
          );
        } catch (_) {}
      } catch (e) {
        debugPrint('Error archiving global student account: $e');
      }
    }
    AppDataCache.instance.invalidatePrefix('teacher_students_');
  }

  @override
  Future<void> restoreStudent(String id, [String? subjectId]) async {
    if (subjectId != null) {
      await _client
          .from('student_enrollments')
          .update({'status': 'Enrolled'})
          .match({'student_id': id, 'subject_offering_id': subjectId});
    } else {
      await _client
          .from('student_enrollments')
          .update({'status': 'Enrolled'})
          .eq('student_id', id);
    }

    // Always re-enable root user and Firebase Auth on restore
    try {
      await _client.from('users').update({'is_archived': false}).eq('id', id);
      try {
        final cur = await _client
            .from('student_settings')
            .select('previous_status')
            .eq('student_id', id)
            .maybeSingle();
        final prev = cur?['previous_status']?.toString();
        // Restore exact status before archive, default to active, NEVER pending_first_login unless it was genuinely pending
        final targetStatus =
            (prev != null && prev.isNotEmpty && prev != 'archived')
            ? prev
            : 'active';

        await _client
            .from('student_settings')
            .update({'status': targetStatus, 'previous_status': null})
            .eq('student_id', id);
      } catch (_) {}
      try {
        await FirebaseAuthAdminService.setUserDisabled(
          uid: id,
          disabled: false,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Error restoring student account: $e');
    }
    AppDataCache.instance.invalidatePrefix('teacher_students_');
  }

  @override
  Future<void> deactivateStudent(String id) async {}

  @override
  Future<void> reactivateStudent(String id) async {}

  @override
  Future<void> permanentlyDeleteStudent(String id, [String? subjectId]) async {
    try {
      // 1. Delete enrollment from specified subject offering or all enrollments
      if (subjectId != null) {
        await _client.from('student_enrollments').delete().match({
          'student_id': id,
          'subject_offering_id': subjectId,
        });

        // Check if student still has remaining enrollments in any other subject
        final remaining = await _client
            .from('student_enrollments')
            .select('id')
            .eq('student_id', id);

        if (remaining.isNotEmpty) {
          // Student is still enrolled in other classes! Do not delete root profile or Auth account.
          return;
        }
      } else {
        await _client.from('student_enrollments').delete().eq('student_id', id);
      }

      // 2. Unlink parents before deleting student record
      try {
        await _client
            .from('parent_student_links')
            .delete()
            .eq('student_id', id);
      } catch (_) {}

      // 3. Delete student settings, profile, and users record
      try {
        await _client.from('student_settings').delete().eq('student_id', id);
      } catch (_) {}
      try {
        await _client.from('student_profiles').delete().eq('student_id', id);
      } catch (_) {}
      try {
        await _client.from('users').delete().eq('id', id);
      } catch (_) {}

      // 4. Delete student from Firebase Authentication
      try {
        await FirebaseAuthAdminService.deleteUser(uid: id);
      } catch (fbErr) {
        debugPrint('Firebase Auth deletion notice for student $id: $fbErr');
      }

      // Note: Linked parents are unlinked from this student above, but their parent accounts are preserved.
    } catch (e) {
      debugPrint('Error permanently deleting student $id: $e');
    }
  }
}
