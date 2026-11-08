import 'package:class_realm/core/services/app_data_cache.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/models/user_model.dart';

class StudentDashboardRepository {
  StudentDashboardRepository._();

  static final StudentDashboardRepository instance =
      StudentDashboardRepository._();

  StudentDashboardData? _cachedDashboard;
  StudentDashboardData? get currentDashboard => _cachedDashboard;

  Future<StudentDashboardData> loadDashboard({
    bool forceRefresh = false,
  }) async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (forceRefresh) {
      _cachedDashboard = null;
      if (authUser != null) {
        AppDataCache.instance.invalidate('student_dashboard_${authUser.uid}');
      }
    }

    if (!forceRefresh && _cachedDashboard != null) {
      return _cachedDashboard!;
    }

    // 1. FAST LOCAL READ (0 milliseconds load, Web + Native parity)
    if (!forceRefresh && authUser != null) {
      final cachedWeb = AppDataCache.instance.getCached<StudentDashboardData>(
        'student_dashboard_${authUser.uid}',
        (json) => StudentDashboardData.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      );
      if (cachedWeb != null) {
        _cachedDashboard = cachedWeb;
        if (!AppDataCache.instance.isFresh(
          'student_dashboard_${authUser.uid}',
        )) {
          unawaited(_fetchFromCloud());
        }
        return cachedWeb;
      }

      // SQLite Native Fallback
      try {
        final cachedJsonStr = await AppDatabase.instance.getSetting(
          'cached_student_dashboard',
        );
        if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
          final data = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
          _cachedDashboard = StudentDashboardData.fromJson(data);

          // Trigger background cloud refresh silently
          unawaited(_fetchFromCloud());
          return _cachedDashboard!;
        }
      } catch (_) {}
    }

    return _fetchFromCloud();
  }

  Future<StudentDashboardData> _fetchFromCloud() async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (_cachedDashboard != null) return _cachedDashboard!;
      throw StateError(
        'A signed-in student session is required to load the dashboard.',
      );
    }

    final uid = authUser.uid;
    final client = SupabaseService().client;

    try {
      // 1. Fetch student profile and settings directly via Pure Dart
      Map<String, dynamic>? profileRes;
      Map<String, dynamic>? settingsRes;
      try {
        profileRes = await client
            .from('student_profiles')
            .select(
              'student_id, lrn, first_name, middle_name, last_name, birthday, gender',
            )
            .eq('student_id', uid)
            .maybeSingle();
      } catch (e) {
        debugPrint('Student profile fetch notice: $e');
      }
      try {
        settingsRes = await client
            .from('student_settings')
            .select('*')
            .eq('student_id', uid)
            .maybeSingle();
      } catch (e) {
        debugPrint('Student settings fetch notice: $e');
      }

      // 2. Fetch student enrollments directly via Pure Dart
      List<dynamic> enrollmentRows = [];
      try {
        final res = await client
            .from('student_enrollments')
            .select('''
              subject_offering_id,
              subject_offerings (
                id,
                subjects ( id, subject_name, subject_code, grade_level ),
                sections ( id, section_name, grade_level ),
                teacher_profiles ( teacher_id, first_name, last_name, gender )
              )
            ''')
            .eq('student_id', uid)
            .ilike('status', 'enrolled');
        enrollmentRows = res as List? ?? [];
      } catch (e) {
        debugPrint(
          'Enrollments full query notice: $e. Retrying without teacher_profiles join...',
        );
        try {
          final res = await client
              .from('student_enrollments')
              .select('''
                subject_offering_id,
                subject_offerings (
                  id,
                  subjects ( id, subject_name, subject_code, grade_level ),
                  sections ( id, section_name, grade_level )
                )
              ''')
              .eq('student_id', uid)
              .ilike('status', 'enrolled');
          enrollmentRows = res as List? ?? [];
        } catch (e2) {
          debugPrint('Enrollments fallback query notice: $e2');
        }
      }

      final enrollmentsList = enrollmentRows.map((row) {
        final offering =
            row['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
        final sec = offering['sections'] as Map<String, dynamic>? ?? {};
        final teacher =
            offering['teacher_profiles'] as Map<String, dynamic>? ?? {};
        final rawTeacherName = [
          teacher['first_name'],
          teacher['last_name'],
        ].where((n) => n != null && n.toString().trim().isNotEmpty).join(' ');
        final g = teacher['gender']?.toString().trim().toLowerCase();
        final prefix = (g == 'female' || g == 'f')
            ? "Ma'am "
            : (g == 'male' || g == 'm')
            ? "Sir "
            : "";
        final teacherName = rawTeacherName.isNotEmpty
            ? '$prefix$rawTeacherName'
            : '';
        return {
          'subject_id': row['subject_offering_id']?.toString() ?? '',
          'subject_name': sub['subject_name']?.toString() ?? '',
          'subject_code': sub['subject_code']?.toString() ?? '',
          'section_name': sec['section_name']?.toString() ?? '',
          'grade_level':
              (sec['grade_level'] ?? sub['grade_level'])?.toString() ?? '',
          'teacher_name': teacherName,
        };
      }).toList();

      final offeringIds = enrollmentsList
          .map((e) => e['subject_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // 3. Fetch classwork items and the current student's submissions gracefully.
      List<Map<String, dynamic>> classworkList = [];
      if (offeringIds.isNotEmpty) {
        try {
          List<dynamic> submissionRows = [];
          try {
            final res = await client
                .from('student_classwork_submissions')
                .select('''
                  id,
                  classwork_id,
                  status,
                  score,
                  feedback,
                  submitted_at,
                  submission_attachments (
                    id,
                    file_name,
                    storage_url,
                    file_size_bytes,
                    mime_type
                  )
                ''')
                .eq('student_id', uid);
            submissionRows = res as List? ?? [];
          } catch (subErr) {
            debugPrint(
              'Notice fetching student submissions with attachments: $subErr. Retrying without attachments...',
            );
            try {
              final res = await client
                  .from('student_classwork_submissions')
                  .select('id, classwork_id, status, score, feedback, submitted_at')
                  .eq('student_id', uid);
              submissionRows = res as List? ?? [];
            } catch (fallbackErr) {
              debugPrint('Notice on fallback submissions fetch: $fallbackErr');
            }
          }

          final submissionsByClassworkId = <String, Map<String, dynamic>>{};
          for (final row in submissionRows) {
            final submission = Map<String, dynamic>.from(row as Map);
            final classworkId = submission['classwork_id']?.toString();
            if (classworkId != null) {
              submissionsByClassworkId[classworkId] = submission;
            }
          }

          final items = await client
              .from('classwork_items')
              .select('''
                id,
                subject_offering_id,
                classwork_type,
                grading_category,
                title,
                description,
                instructions,
                assigned_at,
                deadline,
                max_score,
                completion_mode,
                storage_path,
                file_name,
                file_size_bytes,
                mime_type,
                term_number,
                gradebook_column_index,
                allow_late_submission,
                subject_offerings (
                  subjects ( subject_name ),
                  sections ( section_name, grade_level )
                )
              ''')
              .filter('subject_offering_id', 'in', offeringIds)
              .eq('is_published', true)
              .eq('is_archived', false)
              .order('deadline', ascending: true);

          classworkList = (items as List? ?? []).map<Map<String, dynamic>>((i) {
            final m = Map<String, dynamic>.from(i as Map);
            final off = m['subject_offerings'] as Map<String, dynamic>? ?? {};
            final s = off['subjects'] as Map<String, dynamic>? ?? {};
            final sec = off['sections'] as Map<String, dynamic>? ?? {};
            final submission = submissionsByClassworkId[m['id']?.toString()];

            Map<String, dynamic>? studentSubMap;
            if (submission != null) {
              final attList =
                  submission['submission_attachments'] as List? ?? [];
              final firstAtt = attList.isNotEmpty && attList.first is Map
                  ? Map<String, dynamic>.from(attList.first as Map)
                  : null;
              studentSubMap = {
                'id': submission['id']?.toString() ?? '',
                'score': submission['score'],
                'feedback': submission['feedback'],
                'submitted_at': submission['submitted_at'],
                'status': submission['status'],
                if (firstAtt != null) ...{
                  'file_name': firstAtt['file_name'],
                  'storage_path': firstAtt['storage_url'],
                  'signed_url': firstAtt['storage_url'],
                  'file_size_bytes': firstAtt['file_size_bytes'],
                  'mime_type': firstAtt['mime_type'],
                },
              };
            }

            final hasAttachment = m['storage_path'] != null &&
                m['storage_path'].toString().trim().isNotEmpty;
            final attachmentMap = hasAttachment
                ? <String, dynamic>{
                    'id': m['id']?.toString() ?? '',
                    'file_name':
                        m['file_name']?.toString() ?? 'Teacher Attached File',
                    'mime_type': m['mime_type']?.toString(),
                    'file_size_bytes': (m['file_size_bytes'] as num?)?.toInt(),
                    'signed_url': m['storage_path']?.toString(),
                  }
                : null;

            return {
              'id': m['id']?.toString() ?? '',
              'subject_offering_id': m['subject_offering_id']?.toString() ?? '',
              'type':
                  m['classwork_type']?.toString() ??
                  (m['grading_category'] == 'ex' ? 'exam' : 'activity'),
              'title': m['title']?.toString() ?? '',
              'description': m['description']?.toString(),
              'instructions': m['instructions']?.toString(),
              'assigned_at': m['assigned_at']?.toString(),
              'deadline': m['deadline']?.toString(),
              'max_score': m['max_score'] is num ? m['max_score'] : 100,
              'completion_mode': m['completion_mode']?.toString() ?? 'online',
              'storage_path': m['storage_path']?.toString(),
              'file_name': m['file_name']?.toString(),
              'file_size_bytes': (m['file_size_bytes'] as num?)?.toInt(),
              'mime_type': m['mime_type']?.toString(),
              'term_number': (m['term_number'] as num?)?.toInt() ?? 1,
              'gradebook_column_index':
                  (m['gradebook_column_index'] as num?)?.toInt(),
              'subject_name': s['subject_name']?.toString() ?? '',
              'section_name': sec['section_name']?.toString() ?? '',
              'grade_level': sec['grade_level']?.toString() ?? '',
              'status': submission?['score'] != null
                  ? 'graded'
                  : (submission?['status']?.toString() ?? 'pending'),
              'score': submission?['score'],
              'feedback': submission?['feedback'],
              'submitted_at': submission?['submitted_at'],
              if (attachmentMap != null) ...{'attachment': attachmentMap},
              if (studentSubMap != null) ...{'submission': studentSubMap},
            };
          }).toList();

          // Also fetch published digital assessments (quizzes and periodical exams)
          try {
            final attemptRows = await client
                .from('assessment_attempts')
                .select('assessment_id, status, score_earned, submitted_at')
                .eq('student_id', uid);
            final attemptsByAssessmentId = <String, Map<String, dynamic>>{};
            for (final a in (attemptRows as List? ?? [])) {
              final row = Map<String, dynamic>.from(a as Map);
              final aId = row['assessment_id']?.toString();
              if (aId != null) {
                attemptsByAssessmentId[aId] = row;
              }
            }

            final assessments = await client
                .from('digital_assessments')
                .select("""
                  id,
                  subject_offering_id,
                  assessment_type,
                  grading_category,
                  title,
                  instructions,
                  time_limit_minutes,
                  available_from,
                  deadline,
                  assessment_questions ( points ),
                  subject_offerings (
                    subjects ( subject_name ),
                    sections ( section_name, grade_level )
                  )
                """)
                .filter('subject_offering_id', 'in', offeringIds)
                .eq('is_published', true)
                .eq('is_archived', false)
                .order('deadline', ascending: true);

            for (final item in (assessments as List? ?? [])) {
              final m = Map<String, dynamic>.from(item as Map);
              final off = m['subject_offerings'] as Map<String, dynamic>? ?? {};
              final s = off['subjects'] as Map<String, dynamic>? ?? {};
              final sec = off['sections'] as Map<String, dynamic>? ?? {};
              final aId = m['id']?.toString() ?? '';
              final attempt = attemptsByAssessmentId[aId];
              final isSubmitted =
                  attempt != null &&
                  (attempt['status'] == 'submitted' ||
                      attempt['status'] == 'auto_submitted');
              final isQuiz =
                  m['assessment_type']?.toString().toLowerCase() == 'quiz';
              final qList = m['assessment_questions'] as List? ?? const [];
              double computedMax = 0;
              for (final q in qList) {
                if (q is Map && q['points'] != null) {
                  computedMax += (q['points'] as num).toDouble();
                }
              }
              if (computedMax <= 0) computedMax = 100;

              // Deduplicate if already loaded via classwork_items
              final existingIndex = classworkList.indexWhere(
                (cw) => cw['id'] == aId,
              );
              if (existingIndex != -1) {
                if (isSubmitted) {
                  classworkList[existingIndex]['status'] = 'submitted';
                  if (attempt['score_earned'] != null) {
                    classworkList[existingIndex]['score'] =
                        attempt['score_earned'];
                  }
                }
                classworkList[existingIndex]['type'] = isQuiz ? 'quiz' : 'exam';
                if (m['available_from'] != null) {
                  classworkList[existingIndex]['assigned_at'] =
                      m['available_from']?.toString();
                }
                if (m['deadline'] != null) {
                  classworkList[existingIndex]['deadline'] = m['deadline']
                      ?.toString();
                }
                continue;
              }

              classworkList.add({
                'id': aId,
                'subject_offering_id':
                    m['subject_offering_id']?.toString() ?? '',
                'type': isQuiz ? 'quiz' : 'exam',
                'title':
                    m['title']?.toString() ??
                    (isQuiz ? 'Unit Quiz' : 'Periodical Examination'),
                'description':
                    '${isQuiz ? 'Unit Quiz' : 'Periodical Examination'} (${m['time_limit_minutes'] ?? 60} mins)',
                'instructions': m['instructions']?.toString() ?? '',
                'assigned_at': m['available_from']?.toString(),
                'deadline': m['deadline']?.toString(),
                'max_score': computedMax,
                'completion_mode': 'online',
                'subject_name': s['subject_name']?.toString() ?? '',
                'section_name': sec['section_name']?.toString() ?? '',
                'grade_level': sec['grade_level']?.toString() ?? '',
                'status': isSubmitted ? 'submitted' : 'pending',
                'score': attempt?['score_earned'],
                'submitted_at': attempt?['submitted_at'],
              });
            }
          } catch (assessErr) {
            debugPrint('Digital assessments load notice: $assessErr');
          }
        } catch (cwError) {
          debugPrint('Classwork items load notice: $cwError');
        }
      }

      final currentUser = AuthRepository.instance.currentUser;
      final p = profileRes ?? <String, dynamic>{};
      final data = <String, dynamic>{
        'student': {
          'id': uid,
          'email': authUser.email ?? currentUser?.email ?? '',
          'lrn': p['lrn']?.toString() ?? currentUser?.lrn ?? '',
          'first_name':
              p['first_name']?.toString() ?? currentUser?.firstName ?? '',
          'middle_name':
              p['middle_name']?.toString() ?? currentUser?.middleName,
          'last_name':
              p['last_name']?.toString() ?? currentUser?.lastName ?? '',
          'gender': p['gender']?.toString() ?? currentUser?.gender,
          'birthday':
              p['birthday']?.toString() ??
              currentUser?.birthday?.toIso8601String(),
          'hide_term_grades_from_parent':
              settingsRes?['hide_term_grades_from_parent'] ??
              currentUser?.hideTermGradesFromParent ??
              false,
          'hide_final_grades_from_parent':
              settingsRes?['hide_final_grades_from_parent'] ??
              currentUser?.hideFinalGradesFromParent ??
              false,
          'enrollments': enrollmentsList,
        },
        'classwork': classworkList,
      };

      try {
        await AppDatabase.instance.setSetting(
          'cached_student_dashboard',
          jsonEncode(data),
        );
      } catch (_) {}

      _cachedDashboard = StudentDashboardData.fromJson(data);
      unawaited(
        AppDataCache.instance.setCache(
          'student_dashboard_${authUser.uid}',
          data,
        ),
      );
      return _cachedDashboard!;
    } catch (e) {
      debugPrint('Pure Dart student dashboard notice: $e');
      if (_cachedDashboard != null) return _cachedDashboard!;
      return _fallbackForAuthenticatedUser(authUser);
    }
  }

  StudentDashboardData _fallbackForAuthenticatedUser(
    firebase_auth.User authUser,
  ) {
    final currentUser = AuthRepository.instance.currentUser;
    final student =
        currentUser != null &&
            currentUser.id == authUser.uid &&
            currentUser.role == UserRole.student
        ? currentUser
        : UserModel(
            id: authUser.uid,
            username: authUser.email ?? '',
            fullName: authUser.displayName ?? '',
            email: authUser.email ?? '',
            role: UserRole.student,
            studentId: authUser.uid,
          );
    final dashboard = StudentDashboardData(
      student: student,
      classwork: const [],
      enrollments: const [],
    );
    _cachedDashboard = dashboard;
    return dashboard;
  }
}
