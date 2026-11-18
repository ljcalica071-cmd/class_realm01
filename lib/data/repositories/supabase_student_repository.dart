import 'dart:async';

import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/core/services/firebase_auth_admin_service.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/data/repositories/student_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Map<String, String> _readLocalRfidOverrides() {
    final raw = LocalStorageService.getJson('local_student_rfid_map');
    if (raw is Map) {
      final result = <String, String>{};
      raw.forEach((key, value) {
        final k = key?.toString() ?? '';
        final v = value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) {
          result[k] = v.toUpperCase();
        }
      });
      return result;
    }
    return const <String, String>{};
  }

  static bool _isMissingRfidColumnError(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').toUpperCase();
      final msg = error.message.toLowerCase();
      if (code == '42703' || code == 'PGRST204') return true;
      if (msg.contains('rfid_uid') &&
          (msg.contains('does not exist') || msg.contains('schema cache'))) {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('rfid_uid') &&
        (text.contains('42703') ||
            text.contains('pgrst204') ||
            text.contains('does not exist'));
  }

  @override
  Future<List<UserModel>> getStudents({
    String? section,
    bool includeArchived = false,
  }) async {
    return [];
  }

  Future<List<UserModel>> getStudentsForTeacher(
    String teacherId, {
    String? subjectId,
    bool includeArchived = false,
    void Function(List<UserModel> fresh)? onFreshData,
  }) async {
    final cacheKey =
        'teacher_students_${teacherId}_${subjectId ?? "all"}_$includeArchived';
    final cached = AppDataCache.instance.getCached<List<UserModel>>(
      cacheKey,
      (json) => (json as List)
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    if (cached != null && AppDataCache.instance.isFresh(cacheKey)) {
      return cached;
    }

    // 1. Fetch live cloud students first to ensure real registered email, RFID UID, and Supabase status
    try {
      final cloudStudents = await _syncStudentsFromCloud(
        teacherId: teacherId,
        subjectId: subjectId,
        includeArchived: includeArchived,
      );
      if (cloudStudents.isNotEmpty || includeArchived) {
        unawaited(
          AppDataCache.instance.setCache(
            cacheKey,
            cloudStudents.map((u) => u.toJson()).toList(),
          ),
        );
        onFreshData?.call(cloudStudents);
        return cloudStudents;
      }
    } catch (e) {
      debugPrint(
        'Cloud sync error in getStudentsForTeacher, falling back to local: $e',
      );
    }

    // 2. FAST LOCAL DRIFT SQLITE READ (offline fallback)
    if (!kIsWeb) {
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
          final localRfidMap = _readLocalRfidOverrides();
          return localStudents.map((st) {
            final fullName = [
              st.firstName,
              st.middleName,
              st.lastName,
            ].where((name) => name != null && name.trim().isNotEmpty).join(' ');

            final resolvedRfid =
                (st.rfidUid != null && st.rfidUid!.trim().isNotEmpty)
                ? st.rfidUid!.trim().toUpperCase()
                : localRfidMap[st.studentId];

            return UserModel(
              id: st.studentId,
              studentId: st.studentId,
              username: st.lrn ?? '',
              fullName: fullName.isEmpty ? 'Student' : fullName,
              role: UserRole.student,
              email: '',
              firstName: st.firstName,
              middleName: st.middleName,
              lastName: st.lastName,
              gender: st.gender,
              lrn: st.lrn,
              rfidUid: resolvedRfid,
              departmentOrSection: st.departmentOrSection,
              status: AccountStatus.active,
              isArchived: false,
            );
          }).toList();
        }
      } catch (e) {
        debugPrint('Drift local students read notice: $e');
      }
    }

    if (cached != null) return cached;
    return [];
  }

  Future<List<dynamic>> _queryTeacherEnrollments({
    required String teacherId,
    required String? subjectId,
    required bool includeArchived,
    required bool includeRfidColumn,
  }) async {
    final profileColumns = includeRfidColumn
        ? 'student_id, lrn, rfid_uid, first_name, middle_name, last_name, gender, birthday, users ( email, is_archived )'
        : 'student_id, lrn, first_name, middle_name, last_name, gender, birthday, users ( email, is_archived )';

    var query = _client
        .from('student_enrollments')
        .select('''
          id, status, created_at,
          student_profiles!inner (
            $profileColumns
          ),
          subject_offerings!inner (
            id, teacher_id,
            subjects ( id, subject_name ),
            sections ( id, section_name )
          )
        ''')
        .eq('subject_offerings.teacher_id', teacherId);

    if (subjectId != null && subjectId.isNotEmpty) {
      query = query.eq('subject_offerings.id', subjectId);
    }

    if (!includeArchived) {
      query = query.neq('status', 'archived');
    }

    final res = await query;
    return res as List<dynamic>;
  }

  Future<List<UserModel>> _syncStudentsFromCloud({
    required String teacherId,
    String? subjectId,
    bool includeArchived = false,
  }) async {
    try {
      bool cloudHasRfidColumn = true;
      List<dynamic> response;
      try {
        response = await _queryTeacherEnrollments(
          teacherId: teacherId,
          subjectId: subjectId,
          includeArchived: includeArchived,
          includeRfidColumn: true,
        );
      } catch (err) {
        if (_isMissingRfidColumnError(err)) {
          cloudHasRfidColumn = false;
          response = await _queryTeacherEnrollments(
            teacherId: teacherId,
            subjectId: subjectId,
            includeArchived: includeArchived,
            includeRfidColumn: false,
          );
        } else {
          rethrow;
        }
      }

      if (response.isEmpty) {
        return [];
      }

      final localRfidFallback = cloudHasRfidColumn
          ? const <String, String>{}
          : _readLocalRfidOverrides();

      // Collect student IDs to query student_settings for authoritative status
      final studentIds = response
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

      final enrollmentCompanions = <LocalEnrollmentsCompanion>[];

      final mapped = response
          .map<UserModel?>((row) {
            final profile =
                row['student_profiles'] as Map<String, dynamic>? ?? {};
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
                      (name) =>
                          name != null && name.toString().trim().isNotEmpty,
                    )
                    .join(' ');

            final usersData = profile['users'] as Map<String, dynamic>? ?? {};
            final studentId = profile['student_id']?.toString() ?? '';
            final realEmail = usersData['email']?.toString() ?? '';

            final rawRfid = profile['rfid_uid']?.toString().trim();
            final resolvedRfidUid = (rawRfid != null && rawRfid.isNotEmpty)
                ? rawRfid.toUpperCase()
                : localRfidFallback[studentId];

            final enrollmentId = row['id']?.toString() ?? '';
            final offeringId = offering['id']?.toString() ?? '';
            if (enrollmentId.isNotEmpty &&
                studentId.isNotEmpty &&
                offeringId.isNotEmpty) {
              enrollmentCompanions.add(
                LocalEnrollmentsCompanion.insert(
                  id: enrollmentId,
                  studentId: studentId,
                  subjectOfferingId: offeringId,
                  status: Value(row['status']?.toString() ?? 'enrolled'),
                ),
              );
            }

            final enrollmentStatus =
                row['status']?.toString().trim().toLowerCase() ?? '';
            final isEnrollmentArchived = enrollmentStatus == 'archived';
            final isUserArchived = usersData['is_archived'] == true;
            final isSettingsArchived =
                studentSettingsStatus[studentId]?.toLowerCase() == 'archived';
            // Isolate archive state per subject enrollment when status is explicit
            final isArchived = enrollmentStatus.isNotEmpty
                ? isEnrollmentArchived
                : (isUserArchived || isSettingsArchived);

            if (!includeArchived && isArchived) return null;
            if (includeArchived && !isArchived) return null;

            AccountStatus accountStatus;
            if (isArchived) {
              accountStatus = AccountStatus.archived;
            } else {
              final settingsCandidate = studentSettingsStatus[studentId];
              final effectiveStatus =
                  (settingsCandidate != null &&
                      settingsCandidate.toLowerCase() != 'archived')
                  ? settingsCandidate
                  : (usersData['status']?.toString() ?? 'pending_first_login');
              final rawStatus = effectiveStatus.toLowerCase().replaceAll(
                RegExp(r'[\s_-]'),
                '',
              );
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
              studentId: studentId,
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
              rfidUid: resolvedRfidUid,
              departmentOrSection: sec['section_name']?.toString(),
              enrolledSubjectId:
                  offering['id']?.toString() ?? sub['id']?.toString(),
              enrolledSubjectName: sub['subject_name']?.toString(),
              status: accountStatus,
              isArchived: isArchived,
            );
          })
          .whereType<UserModel>()
          .toList();

      // Batch persist to Drift SQLite safely on native platforms
      if (!kIsWeb) {
        try {
          final companions = mapped
              .map(
                (u) => LocalStudentsCompanion.insert(
                  studentId: u.id,
                  lrn: Value(u.lrn),
                  rfidUid: cloudHasRfidColumn
                      ? Value(u.rfidUid)
                      : (u.rfidUid != null
                            ? Value(u.rfidUid)
                            : const Value.absent()),
                  firstName: u.firstName ?? 'Student',
                  middleName: Value(u.middleName),
                  lastName: u.lastName ?? '',
                  gender: Value(u.gender ?? 'unspecified'),
                  departmentOrSection: Value(u.departmentOrSection),
                ),
              )
              .toList();

          await AppDatabase.instance.upsertStudents(companions);
          if (enrollmentCompanions.isNotEmpty) {
            await AppDatabase.instance.upsertEnrollments(enrollmentCompanions);
          }
        } catch (dbErr) {
          debugPrint('Drift local students save notice: $dbErr');
        }
      }

      return mapped;
    } catch (e) {
      debugPrint('Error getting students for teacher: $e');
      rethrow;
    }
  }

  @override
  Future<UserModel?> getStudentById(String id) async {
    try {
      Map<String, dynamic>? profileRow;
      try {
        profileRow = await _client
            .from('student_profiles')
            .select('''
              student_id,
              lrn,
              rfid_uid,
              first_name,
              middle_name,
              last_name,
              gender,
              birthday,
              users ( id, email, role, is_archived )
            ''')
            .eq('student_id', id)
            .maybeSingle();
      } catch (err) {
        if (_isMissingRfidColumnError(err)) {
          profileRow = await _client
              .from('student_profiles')
              .select('''
                student_id,
                lrn,
                first_name,
                middle_name,
                last_name,
                gender,
                birthday,
                users ( id, email, role, is_archived )
              ''')
              .eq('student_id', id)
              .maybeSingle();
        } else {
          rethrow;
        }
      }

      if (profileRow == null) return null;

      final usersData = profileRow['users'] is Map
          ? Map<String, dynamic>.from(profileRow['users'] as Map)
          : const <String, dynamic>{};

      final fName = profileRow['first_name']?.toString() ?? '';
      final mName = profileRow['middle_name']?.toString();
      final lName = profileRow['last_name']?.toString() ?? '';
      final rawRfid = profileRow['rfid_uid']?.toString().trim();
      final localRfid = _readLocalRfidOverrides()[id];

      return UserModel(
        id: profileRow['student_id'].toString(),
        studentId: profileRow['student_id'].toString(),
        username:
            profileRow['lrn']?.toString() ??
            usersData['email']?.toString() ??
            '',
        fullName: [
          fName,
          mName,
          lName,
        ].where((s) => s != null && s.trim().isNotEmpty).join(' '),
        email: usersData['email']?.toString() ?? '',
        role: UserRole.student,
        firstName: fName,
        middleName: mName,
        lastName: lName,
        lrn: profileRow['lrn']?.toString(),
        rfidUid: (rawRfid != null && rawRfid.isNotEmpty)
            ? rawRfid.toUpperCase()
            : localRfid,
        gender: profileRow['gender']?.toString(),
        birthday: profileRow['birthday'] != null
            ? DateTime.tryParse(profileRow['birthday'].toString())
            : null,
        isArchived: usersData['is_archived'] == true,
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
    required String studentId,
    required String gender,
    required String contactNumber,
  }) async {
    return null;
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
    String? preResolvedExistingStudentId,
  }) async {
    final properFirst = AppValidators.toProperCase(firstName);
    final properLast = AppValidators.toProperCase(lastName);
    final cleanMiddleName =
        AppValidators.normalizeMiddleInitial(middleName) ?? '';
    final cleanEmail = email.trim().toLowerCase();
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
    final cleanLastName = properLast.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final tempPassword =
        '$cleanLastName${birthday.year}${birthday.month.toString().padLeft(2, '0')}${birthday.day.toString().padLeft(2, '0')}';
    final studentFullName = [
      properFirst,
      if (cleanMiddleName.isNotEmpty) cleanMiddleName,
      properLast,
    ].join(' ');

    // 0. Check if student already exists globally by LRN (ClassRealm Cross-Teacher Reuse)
    String? existingStudentId =
        (preResolvedExistingStudentId != null &&
            preResolvedExistingStudentId.trim().isNotEmpty)
        ? preResolvedExistingStudentId.trim()
        : null;
    String? existingRfidUid;
    if (existingStudentId == null) {
      try {
        Map<String, dynamic>? existingProfile;
        try {
          existingProfile = await _client
              .from('student_profiles')
              .select('student_id, first_name, last_name, lrn, rfid_uid')
              .eq('lrn', lrn)
              .maybeSingle();
        } catch (err) {
          if (_isMissingRfidColumnError(err)) {
            existingProfile = await _client
                .from('student_profiles')
                .select('student_id, first_name, last_name, lrn')
                .eq('lrn', lrn)
                .maybeSingle();
          } else {
            rethrow;
          }
        }

        if (existingProfile != null && existingProfile['student_id'] != null) {
          final existingFirst = (existingProfile['first_name'] ?? '')
              .toString()
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ')
              .toLowerCase();
          final existingLast = (existingProfile['last_name'] ?? '')
              .toString()
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ')
              .toLowerCase();
          final inputFirst = firstName
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ')
              .toLowerCase();
          final inputLast = lastName
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ')
              .toLowerCase();

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
          final rawRfid = existingProfile['rfid_uid']?.toString().trim();
          if (rawRfid != null && rawRfid.isNotEmpty) {
            existingRfidUid = rawRfid.toUpperCase();
          }
        }
      } catch (e) {
        if (e.toString().contains('LRN Conflict')) rethrow;
        debugPrint('LRN lookup notice: $e');
      }
    }

    if (existingStudentId != null && existingStudentId.isNotEmpty) {
      // Re-use global identity without touching credentials or recreating auth
      try {
        await _client.from('student_enrollments').upsert({
          'student_id': existingStudentId,
          'subject_offering_id': subjectId,
          'status': 'enrolled',
        }, onConflict: 'student_id,subject_offering_id');
      } catch (e) {
        debugPrint('Cross-teacher enrollment error: $e');
        rethrow;
      }

      // Persist locally to Drift SQLite
      if (!kIsWeb) {
        try {
          await AppDatabase.instance.upsertStudents([
            LocalStudentsCompanion.insert(
              studentId: existingStudentId,
              lrn: Value(lrn),
              rfidUid: existingRfidUid != null
                  ? Value(existingRfidUid)
                  : const Value.absent(),
              firstName: properFirst,
              middleName: Value(cleanMiddleName),
              lastName: properLast,
              gender: Value(gender),
            ),
          ]);
        } catch (_) {}
      }

      AppDataCache.instance.invalidatePrefix('teacher_students_');
      AppDataCache.instance.invalidatePrefix('attendance_');
      return StudentEnrollmentResult(
        studentId: existingStudentId,
        createdAccount: false,
        tempPassword: null,
      );
    }

    // Pre-check if email already exists in Supabase users table
    try {
      final existingUser = await _client
          .from('users')
          .select('id, email, role')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (existingUser != null) {
        final existingRole =
            (existingUser['role']?.toString().toUpperCase() ?? 'USER');
        throw Exception(
          'Email Already in Use: The email address "$cleanEmail" is already registered to an existing $existingRole account. Please use a different, unique email address for this student.',
        );
      }
    } catch (e) {
      if (e.toString().contains('Email Already in Use')) rethrow;
      debugPrint('Supabase email pre-check notice: $e');
    }

    // New student candidate: provision authentication credentials via Firebase
    final fbResult = await FirebaseAuthAdminService.createUserDetailed(
      email: cleanEmail,
      password: tempPassword,
      displayName: studentFullName,
    );

    if (!fbResult.isSuccess || fbResult.uid == null || fbResult.uid!.isEmpty) {
      if (fbResult.errorCode == 'EMAIL_EXISTS') {
        throw Exception(
          'Email Already in Use: The email address "$cleanEmail" is already registered to an existing account. Please enter a different, unique email address for this student.',
        );
      } else if (fbResult.errorCode == 'INVALID_EMAIL') {
        throw Exception(
          'Invalid Email Address: The email address "$cleanEmail" is invalid or formatted incorrectly. Please check the spelling.',
        );
      } else if (fbResult.errorCode == 'TOO_MANY_ATTEMPTS_TRY_LATER') {
        throw Exception(
          'Too Many Attempts: Authentication requests are temporarily throttled. Please wait a few moments and try again.',
        );
      }
      throw Exception(
        fbResult.errorMessage ??
            'Failed to provision authentication credentials for student account ($cleanEmail). Please verify that the email address is valid and active.',
      );
    }

    final studentId = fbResult.uid!;

    try {
      // 1. Direct Pure Dart insert into Supabase users, profiles, settings, and enrollments
      await _client.from('users').upsert({
        'id': studentId,
        'email': cleanEmail,
        'role': 'student',
        'is_archived': false,
      });

      await _client.from('student_profiles').upsert({
        'student_id': studentId,
        'lrn': lrn,
        'first_name': properFirst,
        'middle_name': cleanMiddleName.isEmpty ? null : cleanMiddleName,
        'last_name': properLast,
        'gender': gender,
        'birthday': bdayStr,
      });

      await Future.wait([
        _client.from('student_settings').upsert({
          'student_id': studentId,
          'status': 'pending_first_login',
        }),
        _client.from('student_enrollments').upsert({
          'student_id': studentId,
          'subject_offering_id': subjectId,
          'status': 'enrolled',
        }, onConflict: 'student_id,subject_offering_id'),
      ]);
    } catch (e) {
      debugPrint('Pure Dart enroll notice: $e');
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
          }, onConflict: 'student_id,subject_offering_id');
          AppDataCache.instance.invalidatePrefix('teacher_students_');
          AppDataCache.instance.invalidatePrefix('attendance_');
          return StudentEnrollmentResult(
            studentId: winnerId,
            createdAccount: false,
            tempPassword: null,
          );
        }
      } catch (raceErr) {
        debugPrint('Race condition resolution error: $raceErr');
      }
      rethrow;
    }

    // 2. Persist locally to Drift SQLite
    if (!kIsWeb) {
      try {
        await AppDatabase.instance.upsertStudents([
          LocalStudentsCompanion.insert(
            studentId: studentId,
            lrn: Value(lrn),
            firstName: properFirst,
            middleName: Value(cleanMiddleName),
            lastName: properLast,
            gender: Value(gender),
          ),
        ]);
      } catch (_) {}
    }

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

    AppDataCache.instance.invalidatePrefix('teacher_students_');
    AppDataCache.instance.invalidatePrefix('attendance_');

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
    final properFirst = AppValidators.toProperCase(firstName);
    final properLast = AppValidators.toProperCase(lastName);
    final cleanMiddleName =
        AppValidators.normalizeMiddleInitial(middleName) ?? '';
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
    try {
      await _client
          .from('student_profiles')
          .update({
            'lrn': studentId,
            'first_name': properFirst,
            'middle_name': cleanMiddleName.isEmpty ? null : cleanMiddleName,
            'last_name': properLast,
            'gender': gender,
            'birthday': bdayStr,
          })
          .eq('student_id', id);

      await _client.from('users').update({'email': email}).eq('id', id);
    } catch (e) {
      debugPrint('Pure Dart student update notice: $e');
    }

    if (!kIsWeb) {
      try {
        await (AppDatabase.instance.update(
          AppDatabase.instance.localStudents,
        )..where((t) => t.studentId.equals(id))).write(
          LocalStudentsCompanion(
            lrn: Value(studentId),
            firstName: Value(properFirst),
            middleName: Value(cleanMiddleName.isEmpty ? null : cleanMiddleName),
            lastName: Value(properLast),
            gender: Value(gender),
          ),
        );
      } catch (_) {}
    }

    AppDataCache.instance.invalidatePrefix('teacher_students_');
    AppDataCache.instance.invalidatePrefix('attendance_');
  }

  Future<void> _updateEnrollmentStatusForSubject(
    String studentId,
    String? subjectId,
    String targetStatus,
  ) async {
    if (subjectId != null && subjectId.isNotEmpty) {
      final updated = await _client
          .from('student_enrollments')
          .update({'status': targetStatus})
          .match({'student_id': studentId, 'subject_offering_id': subjectId})
          .select('id');

      if ((updated as List).isEmpty) {
        // Fallback when subjectId is a subjects.id rather than subject_offering_id
        final offerings = await _client
            .from('subject_offerings')
            .select('id')
            .eq('subject_id', subjectId);
        final offeringIds = (offerings as List)
            .map((o) => o['id']?.toString())
            .whereType<String>()
            .toList();
        if (offeringIds.isNotEmpty) {
          await _client
              .from('student_enrollments')
              .update({'status': targetStatus})
              .eq('student_id', studentId)
              .inFilter('subject_offering_id', offeringIds);
        }
      }
    } else {
      await _client
          .from('student_enrollments')
          .update({'status': targetStatus})
          .eq('student_id', studentId);
    }
  }

  Future<void> _restoreGlobalStudentAccount(String id) async {
    try {
      await _client.from('users').update({'is_archived': false}).eq('id', id);
    } catch (e) {
      debugPrint('Error restoring users record for student $id: $e');
    }

    try {
      final cur = await _client
          .from('student_settings')
          .select('status, previous_status')
          .eq('student_id', id)
          .maybeSingle();
      if (cur?['status']?.toString().toLowerCase() == 'archived') {
        final prev = cur?['previous_status']?.toString();
        final targetStatus =
            (prev != null && prev.isNotEmpty && prev != 'archived')
            ? prev
            : 'active';
        await _client
            .from('student_settings')
            .update({'status': targetStatus, 'previous_status': null})
            .eq('student_id', id);
      }
    } catch (e) {
      debugPrint('Error restoring student_settings for student $id: $e');
    }

    try {
      await FirebaseAuthAdminService.setUserDisabled(uid: id, disabled: false);
    } catch (_) {}
  }

  @override
  Future<void> archiveStudent(
    String id, [
    String? subjectId,
    String? currentStatusHint,
  ]) async {
    // 1. Archive student enrollment row only for the targeted subject
    try {
      await _updateEnrollmentStatusForSubject(id, subjectId, 'archived');
    } catch (e) {
      debugPrint('Error updating student_enrollments to archived: $e');
    }

    // 2. Archive global account/settings/auth ONLY if no enrolled subjects remain
    bool hasRemainingEnrolled = false;
    try {
      final remaining = await _client
          .from('student_enrollments')
          .select('id')
          .eq('student_id', id)
          .eq('status', 'enrolled')
          .limit(1);
      hasRemainingEnrolled = (remaining as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking remaining enrollments during archive: $e');
    }

    if (!hasRemainingEnrolled) {
      try {
        await _client.from('users').update({'is_archived': true}).eq('id', id);
      } catch (e) {
        debugPrint('Error archiving users record for student $id: $e');
      }

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
      } catch (e) {
        debugPrint('Error archiving student_settings for student $id: $e');
      }

      try {
        await FirebaseAuthAdminService.setUserDisabled(uid: id, disabled: true);
      } catch (_) {}
    }

    AppDataCache.instance.invalidatePrefix('teacher_students_');
    AppDataCache.instance.invalidatePrefix('attendance_');
  }

  @override
  Future<void> restoreStudent(String id, [String? subjectId]) async {
    // 1. Restore student enrollment status to enrolled
    try {
      await _updateEnrollmentStatusForSubject(id, subjectId, 'enrolled');
    } catch (e) {
      debugPrint('Error restoring student_enrollments to enrolled: $e');
    }

    // 2. Ensure global account, student_settings, and Firebase Auth are active
    await _restoreGlobalStudentAccount(id);

    AppDataCache.instance.invalidatePrefix('teacher_students_');
    AppDataCache.instance.invalidatePrefix('attendance_');
  }

  @override
  Future<void> deactivateStudent(String id) async {}

  @override
  Future<void> reactivateStudent(String id) async {}

  Future<String?> _resolveSubjectOfferingId(String? subjectOrOfferingId) async {
    if (subjectOrOfferingId == null || subjectOrOfferingId.isEmpty) return null;
    try {
      final byOffering = await _client
          .from('subject_offerings')
          .select('id')
          .eq('id', subjectOrOfferingId)
          .maybeSingle();
      if (byOffering != null && byOffering['id'] != null) {
        return byOffering['id'].toString();
      }
      final bySubject = await _client
          .from('subject_offerings')
          .select('id')
          .eq('subject_id', subjectOrOfferingId)
          .limit(1);
      if ((bySubject as List).isNotEmpty) {
        return bySubject.first['id']?.toString();
      }
    } catch (_) {}
    return subjectOrOfferingId;
  }

  bool _hasRealAttendanceRows(List<dynamic> rows) {
    return rows.any((raw) {
      final row = raw as Map;
      final st = (row['status']?.toString() ?? '').trim().toLowerCase();
      final timeIn = row['time_in'];
      final hasTimeIn = timeIn != null && timeIn.toString().trim().isNotEmpty;
      return (st.isNotEmpty && st != 'absent') || hasTimeIn;
    });
  }

  bool _hasRealTermGrades(List<dynamic> rows) {
    return rows.any((raw) {
      final row = raw as Map;
      final isFinalized = row['is_finalized'] == true;
      final initGrade = (row['initial_grade'] as num?)?.toDouble() ?? 0.0;
      final transGrade = (row['transmuted_grade'] as num?)?.toDouble() ?? 0.0;
      return isFinalized || initGrade > 0 || transGrade > 0;
    });
  }

  bool _hasPositiveSheetScores(List<dynamic> sheetRows, String studentId) {
    for (final rawSheet in sheetRows) {
      final scoresJson = (rawSheet as Map)['scores_json'];
      if (scoresJson is! Map) continue;
      final studentEntry = scoresJson[studentId];
      if (studentEntry is! Map) continue;
      for (final catKey in const ['ww', 'pt', 'ex']) {
        final catMap = studentEntry[catKey];
        if (catMap is Map) {
          for (final val in catMap.values) {
            final numVal = val is num
                ? val.toDouble()
                : double.tryParse(val?.toString() ?? '');
            if (numVal != null && numVal > 0) return true;
          }
        }
      }
    }
    return false;
  }

  bool _hasRealClassworkSubmissions(List<dynamic> rows) {
    const submittedStatuses = {'submitted', 'late_submitted', 'graded'};
    return rows.any((raw) {
      final row = raw as Map;
      final score = row['score'] as num?;
      final status = (row['status']?.toString() ?? '').trim().toLowerCase();
      return (score != null && score > 0) || submittedStatuses.contains(status);
    });
  }

  bool _hasRealAssessmentAttempts(List<dynamic> rows) {
    const submittedStatuses = {'submitted', 'auto_submitted'};
    return rows.any((raw) {
      final row = raw as Map;
      final score = row['score_earned'] as num?;
      final status = (row['status']?.toString() ?? '').trim().toLowerCase();
      return (score != null && score > 0) || submittedStatuses.contains(status);
    });
  }

  void _invalidateStudentRelatedCaches() {
    AppDataCache.instance.invalidatePrefix('teacher_students_');
    AppDataCache.instance.invalidatePrefix('attendance_');
    AppDataCache.instance.invalidatePrefix('gradebook_');
  }

  Future<void> _cleanupOfferingPlaceholderRecords(
    String studentId,
    String offeringId,
  ) async {
    // 1. Delete placeholder/auto-absent attendance rows first (FK RESTRICT on student_enrollments)
    try {
      await _client.from('attendance_records').delete().match({
        'student_id': studentId,
        'subject_offering_id': offeringId,
      });
    } catch (_) {}

    // 2. Delete placeholder term_grades
    try {
      await _client.from('term_grades').delete().match({
        'student_id': studentId,
        'subject_offering_id': offeringId,
      });
    } catch (_) {}

    // 3. Delete zero/pending classwork submissions belonging to this offering
    try {
      final cwItems = await _client
          .from('classwork_items')
          .select('id')
          .eq('subject_offering_id', offeringId);
      final cwIds = (cwItems as List)
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .toList();
      if (cwIds.isNotEmpty) {
        await _client
            .from('student_classwork_submissions')
            .delete()
            .eq('student_id', studentId)
            .inFilter('classwork_id', cwIds);
      }
    } catch (_) {}

    // 4. Delete unsubmitted/abandoned assessment attempts belonging to this offering
    try {
      final daItems = await _client
          .from('digital_assessments')
          .select('id')
          .eq('subject_offering_id', offeringId);
      final daIds = (daItems as List)
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .toList();
      if (daIds.isNotEmpty) {
        final attempts = await _client
            .from('assessment_attempts')
            .select('id')
            .eq('student_id', studentId)
            .inFilter('assessment_id', daIds);
        final attemptIds = (attempts as List)
            .map((e) => e['id']?.toString())
            .whereType<String>()
            .toList();
        if (attemptIds.isNotEmpty) {
          await _client
              .from('assessment_responses')
              .delete()
              .inFilter('attempt_id', attemptIds);
          await _client
              .from('assessment_attempts')
              .delete()
              .inFilter('id', attemptIds);
        }
      }
    } catch (_) {}

    // 5. Remove student key from gradebook_term_sheets.scores_json if present
    try {
      final sheets = await _client
          .from('gradebook_term_sheets')
          .select('id, term_number, scores_json')
          .eq('subject_offering_id', offeringId);
      for (final raw in (sheets as List)) {
        final row = raw as Map;
        final sheetId = row['id'];
        final termNum = (row['term_number'] as num?)?.toInt();
        final scoresJson = row['scores_json'];
        if (scoresJson is Map && scoresJson.containsKey(studentId)) {
          final updatedScores = Map<String, dynamic>.from(scoresJson);
          updatedScores.remove(studentId);
          await _client
              .from('gradebook_term_sheets')
              .update({
                'scores_json': updatedScores,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', sheetId);
          if (termNum != null) {
            await LocalStorageService.clearGradebookSheet(offeringId, termNum);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<StudentDeletionEligibility> checkStudentDeletionEligibility(
    String id, [
    String? subjectId,
  ]) async {
    try {
      final resolvedOfferingId = await _resolveSubjectOfferingId(subjectId);

      // 1. Check if student has actual records in THIS subject offering
      if (resolvedOfferingId != null && resolvedOfferingId.isNotEmpty) {
        // Attendance check (ignore system-generated absent rows with no time_in)
        final att = await _client
            .from('attendance_records')
            .select('id, status, recording_method, time_in')
            .eq('student_id', id)
            .eq('subject_offering_id', resolvedOfferingId);
        if (_hasRealAttendanceRows(att as List)) {
          return const StudentDeletionEligibility(
            canDelete: false,
            isClassRemovalOnly: false,
            hasClassRecords: true,
            blockReason: 'This student cannot be deleted from this class because they have recorded attendance data in this subject.\n\nTo preserve historical academic records and maintain school compliance, this student must remain in the archives instead of being deleted.',
          );
        }

        // Term grades & Gradebook sheet check
        final gr = await _client
            .from('term_grades')
            .select('id, initial_grade, transmuted_grade, is_finalized')
            .eq('student_id', id)
            .eq('subject_offering_id', resolvedOfferingId);
        final sheets = await _client
            .from('gradebook_term_sheets')
            .select('scores_json')
            .eq('subject_offering_id', resolvedOfferingId);
        if (_hasRealTermGrades(gr as List) ||
            _hasPositiveSheetScores(sheets as List, id)) {
          return const StudentDeletionEligibility(
            canDelete: false,
            isClassRemovalOnly: false,
            hasClassRecords: true,
            blockReason: 'This student cannot be deleted from this class because they have recorded term grades in this subject.\n\nTo preserve historical academic records and maintain school compliance, this student must remain in the archives instead of being deleted.',
          );
        }

        // Classwork submissions check
        final cwItems = await _client
            .from('classwork_items')
            .select('id')
            .eq('subject_offering_id', resolvedOfferingId);
        final cwIds = (cwItems as List)
            .map((e) => e['id']?.toString())
            .whereType<String>()
            .toList();
        if (cwIds.isNotEmpty) {
          final cwSubs = await _client
              .from('student_classwork_submissions')
              .select('id, status, score')
              .eq('student_id', id)
              .inFilter('classwork_id', cwIds);
          if (_hasRealClassworkSubmissions(cwSubs as List)) {
            return const StudentDeletionEligibility(
              canDelete: false,
              isClassRemovalOnly: false,
              hasClassRecords: true,
              blockReason: 'This student cannot be deleted from this class because they have submitted classwork activities in this subject.\n\nTo preserve historical academic records and maintain school compliance, this student must remain in the archives instead of being deleted.',
            );
          }
        }

        // Digital assessments check
        final daItems = await _client
            .from('digital_assessments')
            .select('id')
            .eq('subject_offering_id', resolvedOfferingId);
        final daIds = (daItems as List)
            .map((e) => e['id']?.toString())
            .whereType<String>()
            .toList();
        if (daIds.isNotEmpty) {
          final daAttempts = await _client
              .from('assessment_attempts')
              .select('id, status, score_earned')
              .eq('student_id', id)
              .inFilter('assessment_id', daIds);
          if (_hasRealAssessmentAttempts(daAttempts as List)) {
            return const StudentDeletionEligibility(
              canDelete: false,
              isClassRemovalOnly: false,
              hasClassRecords: true,
              blockReason: 'This student cannot be deleted from this class because they have taken assessment quizzes or exams in this subject.\n\nTo preserve historical academic records and maintain school compliance, this student must remain in the archives instead of being deleted.',
            );
          }
        }
      }

      // 2. Check if student is enrolled in OTHER classes or has records elsewhere in the school
      var otherEnrollmentsQuery = _client
          .from('student_enrollments')
          .select('id, subject_offering_id')
          .eq('student_id', id);
      if (resolvedOfferingId != null && resolvedOfferingId.isNotEmpty) {
        otherEnrollmentsQuery = otherEnrollmentsQuery.neq(
          'subject_offering_id',
          resolvedOfferingId,
        );
      }
      final otherEnrollments = await otherEnrollmentsQuery;
      final hasOtherEnrollments = (otherEnrollments as List).isNotEmpty;

      // 3. Check for any real global records in other subjects across the school
      var globalAttendanceQuery = _client
          .from('attendance_records')
          .select('id, status, recording_method, time_in')
          .eq('student_id', id);
      if (resolvedOfferingId != null && resolvedOfferingId.isNotEmpty) {
        globalAttendanceQuery = globalAttendanceQuery.neq(
          'subject_offering_id',
          resolvedOfferingId,
        );
      }
      final globalAtt = await globalAttendanceQuery;

      var globalGradesQuery = _client
          .from('term_grades')
          .select('id, initial_grade, transmuted_grade, is_finalized')
          .eq('student_id', id);
      if (resolvedOfferingId != null && resolvedOfferingId.isNotEmpty) {
        globalGradesQuery = globalGradesQuery.neq(
          'subject_offering_id',
          resolvedOfferingId,
        );
      }
      final globalGr = await globalGradesQuery;

      final globalCw = await _client
          .from('student_classwork_submissions')
          .select('id, status, score')
          .eq('student_id', id);

      final globalAssess = await _client
          .from('assessment_attempts')
          .select('id, status, score_earned')
          .eq('student_id', id);

      final hasGlobalRecords =
          _hasRealAttendanceRows(globalAtt as List) ||
          _hasRealTermGrades(globalGr as List) ||
          _hasRealClassworkSubmissions(globalCw as List) ||
          _hasRealAssessmentAttempts(globalAssess as List);

      if (hasOtherEnrollments || hasGlobalRecords) {
        if (resolvedOfferingId != null && resolvedOfferingId.isNotEmpty) {
          return StudentDeletionEligibility(
            canDelete: true,
            isClassRemovalOnly: true,
            hasOtherEnrollments: hasOtherEnrollments,
            hasGlobalRecords: hasGlobalRecords,
          );
        } else {
          return StudentDeletionEligibility(
            canDelete: false,
            isClassRemovalOnly: false,
            hasOtherEnrollments: hasOtherEnrollments,
            hasGlobalRecords: hasGlobalRecords,
            blockReason: 'Cannot delete student because no specific class was identified and the student has existing enrollments or academic records.',
          );
        }
      }

      // 4. True isolated orphan student
      return const StudentDeletionEligibility(
        canDelete: true,
        isClassRemovalOnly: false,
        hasOtherEnrollments: false,
        hasGlobalRecords: false,
      );
    } catch (e) {
      debugPrint('Error checking student deletion eligibility: $e');
      return const StudentDeletionEligibility(
        canDelete: false,
        isClassRemovalOnly: false,
        blockReason: 'Unable to verify student academic records at this time. Please try again.',
      );
    }
  }

  @override
  Future<void> permanentlyDeleteStudent(String id, [String? subjectId]) async {
    try {
      final resolvedOfferingId = await _resolveSubjectOfferingId(subjectId);

      if (resolvedOfferingId != null && resolvedOfferingId.isNotEmpty) {
        await _cleanupOfferingPlaceholderRecords(id, resolvedOfferingId);

        await _client.from('student_enrollments').delete().match({
          'student_id': id,
          'subject_offering_id': resolvedOfferingId,
        });

        final remaining = await _client
            .from('student_enrollments')
            .select('id, status')
            .eq('student_id', id);

        if ((remaining as List).isNotEmpty) {
          final hasEnrolledElsewhere = remaining.any(
            (r) => r['status']?.toString().toLowerCase() == 'enrolled',
          );
          if (hasEnrolledElsewhere) {
            await _restoreGlobalStudentAccount(id);
          }
          _invalidateStudentRelatedCaches();
          return;
        }
      } else {
        try {
          await _client
              .from('attendance_records')
              .delete()
              .eq('student_id', id);
        } catch (_) {}
        await _client.from('student_enrollments').delete().eq('student_id', id);
      }

      // Check if student still has any enrollment in another class
      final remainingCheck = await _client
          .from('student_enrollments')
          .select('id, status')
          .eq('student_id', id);
      if ((remainingCheck as List).isNotEmpty) {
        final hasEnrolledElsewhere = remainingCheck.any(
          (r) => r['status']?.toString().toLowerCase() == 'enrolled',
        );
        if (hasEnrolledElsewhere) {
          await _restoreGlobalStudentAccount(id);
        }
        _invalidateStudentRelatedCaches();
        return;
      }

      // Guard: ensure no real academic records exist anywhere before full account purge
      final anyAtt = await _client
          .from('attendance_records')
          .select('id, status, recording_method, time_in')
          .eq('student_id', id);
      if (_hasRealAttendanceRows(anyAtt as List)) {
        _invalidateStudentRelatedCaches();
        return;
      }

      final anyGr = await _client
          .from('term_grades')
          .select('id, initial_grade, transmuted_grade, is_finalized')
          .eq('student_id', id);
      if (_hasRealTermGrades(anyGr as List)) {
        _invalidateStudentRelatedCaches();
        return;
      }

      final anyCw = await _client
          .from('student_classwork_submissions')
          .select('id, status, score')
          .eq('student_id', id);
      if (_hasRealClassworkSubmissions(anyCw as List)) {
        _invalidateStudentRelatedCaches();
        return;
      }

      final anyAssess = await _client
          .from('assessment_attempts')
          .select('id, status, score_earned')
          .eq('student_id', id);
      if (_hasRealAssessmentAttempts(anyAssess as List)) {
        _invalidateStudentRelatedCaches();
        return;
      }

      // Clean up remaining placeholder rows across all tables before account deletion
      try {
        await _client.from('attendance_records').delete().eq('student_id', id);
      } catch (_) {}
      try {
        await _client.from('term_grades').delete().eq('student_id', id);
      } catch (_) {}
      try {
        await _client
            .from('student_classwork_submissions')
            .delete()
            .eq('student_id', id);
      } catch (_) {}
      try {
        await _client.from('assessment_attempts').delete().eq('student_id', id);
      } catch (_) {}

      try {
        await _client
            .from('parent_student_links')
            .delete()
            .eq('student_id', id);
      } catch (_) {}

      try {
        await _client.from('student_settings').delete().eq('student_id', id);
      } catch (_) {}
      try {
        await _client.from('student_profiles').delete().eq('student_id', id);
      } catch (_) {}
      try {
        await _client.from('users').delete().eq('id', id);
      } catch (_) {}

      try {
        await FirebaseAuthAdminService.deleteUser(uid: id);
      } catch (fbErr) {
        debugPrint('Firebase Auth deletion notice for student $id: $fbErr');
      }
      _invalidateStudentRelatedCaches();
    } catch (e) {
      debugPrint('Error permanently deleting student $id: $e');
    }
  }
}
