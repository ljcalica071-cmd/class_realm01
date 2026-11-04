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

  /// Explicitly clears in-memory dashboard cache (called on user logout or session switch).
  void clearCache() {
    _cachedDashboard = null;
  }

  Future<StudentDashboardData> loadDashboard({
    bool forceRefresh = false,
  }) async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      _cachedDashboard = null;
      throw StateError(
        'A signed-in student session is required to load the dashboard.',
      );
    }

    final uid = authUser.uid;

    // Discard any in-memory cache that belongs to a different student account
    if (_cachedDashboard != null && _cachedDashboard!.student.id != uid) {
      _cachedDashboard = null;
    }

    if (forceRefresh) {
      _cachedDashboard = null;
      AppDataCache.instance.invalidate('student_dashboard_$uid');
    }

    if (!forceRefresh &&
        _cachedDashboard != null &&
        _cachedDashboard!.student.id == uid) {
      return _cachedDashboard!;
    }

    // 1. FAST LOCAL READ (0 milliseconds load, Web + Native parity)
    if (!forceRefresh) {
      final cachedWeb = AppDataCache.instance.getCached<StudentDashboardData>(
        'student_dashboard_$uid',
        (json) => StudentDashboardData.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      );
      if (cachedWeb != null && cachedWeb.student.id == uid) {
        _cachedDashboard = cachedWeb;
        if (!AppDataCache.instance.isFresh('student_dashboard_$uid')) {
          unawaited(_fetchFromCloud());
        }
        return cachedWeb;
      }

      // SQLite Native Fallback (Scoped strictly to this student's UID)
      try {
        final cachedJsonStr = await AppDatabase.instance.getSetting(
          'cached_student_dashboard_$uid',
        );
        if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
          final data = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
          final parsed = StudentDashboardData.fromJson(data);
          if (parsed.student.id == uid) {
            _cachedDashboard = parsed;
            // Trigger background cloud refresh silently
            unawaited(_fetchFromCloud());
            return _cachedDashboard!;
          }
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
    // Guard against preserving stale data from a prior logged-in student
    if (_cachedDashboard != null && _cachedDashboard!.student.id != uid) {
      _cachedDashboard = null;
    }

    final client = SupabaseService().client;

    try {
      // 1. Fetch student profile directly via Pure Dart
      Map<String, dynamic>? profileRes;
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
                  classwork_id,
                  status,
                  score,
                  feedback,
                  submitted_at,
                  submission_attachments (
                    id,
                    file_name,
                    storage_url,
                    mime_type,
                    file_size_bytes
                  )
                ''')
                .eq('student_id', uid);
            submissionRows = res as List? ?? [];
          } catch (_) {
            final res = await client
                .from('student_classwork_submissions')
                .select('classwork_id, status, score, feedback, submitted_at')
                .eq('student_id', uid);
            submissionRows = res as List? ?? [];
          }

          final submissionsByClassworkId = <String, Map<String, dynamic>>{};
          for (final row in submissionRows) {
            final submission = Map<String, dynamic>.from(row as Map);
            final classworkId = submission['classwork_id']?.toString();
            if (classworkId != null) {
              submissionsByClassworkId[classworkId] = submission;
            }
          }

          List<dynamic> items = [];
          try {
            final res = await client
                .from('classwork_items')
                .select('''
                  id,
                  subject_offering_id,
                  classwork_type,
                  grading_category,
                  completion_mode,
                  term_number,
                  gradebook_column_index,
                  title,
                  description,
                  instructions,
                  assigned_at,
                  deadline,
                  max_score,
                  storage_path,
                  file_name,
                  mime_type,
                  file_size_bytes,
                  subject_offerings (
                    subjects ( subject_name ),
                    sections ( section_name, grade_level )
                  )
                ''')
                .filter('subject_offering_id', 'in', offeringIds)
                .eq('is_published', true)
                .eq('is_archived', false)
                .order('deadline', ascending: true);
            items = res as List? ?? [];
          } catch (_) {
            final res = await client
                .from('classwork_items')
                .select('''
                  id,
                  subject_offering_id,
                  classwork_type,
                  title,
                  description,
                  instructions,
                  assigned_at,
                  deadline,
                  max_score,
                  subject_offerings (
                    subjects ( subject_name ),
                    sections ( section_name, grade_level )
                  )
                ''')
                .filter('subject_offering_id', 'in', offeringIds)
                .eq('is_published', true)
                .eq('is_archived', false)
                .order('deadline', ascending: true);
            items = res as List? ?? [];
          }

          classworkList = items.map<Map<String, dynamic>>((i) {
            final m = Map<String, dynamic>.from(i as Map);
            final off = m['subject_offerings'] as Map<String, dynamic>? ?? {};
            final s = off['subjects'] as Map<String, dynamic>? ?? {};
            final sec = off['sections'] as Map<String, dynamic>? ?? {};
            final submission = submissionsByClassworkId[m['id']?.toString()];

            Map<String, dynamic>? teacherAttachment;
            final storagePath = m['storage_path']?.toString() ?? '';
            final fileName = m['file_name']?.toString() ?? '';
            if (storagePath.isNotEmpty || fileName.isNotEmpty) {
              teacherAttachment = {
                'id': m['id']?.toString() ?? '',
                'file_name': fileName.isNotEmpty ? fileName : 'Reference Material',
                'storage_url': storagePath,
                'mime_type': m['mime_type']?.toString() ?? 'application/octet-stream',
                'file_size_bytes': (m['file_size_bytes'] as num?)?.toInt() ?? 0,
              };
            }

            Map<String, dynamic>? studentSubmissionMap;
            final subAttachments = submission?['submission_attachments'] as List? ?? [];
            if (subAttachments.isNotEmpty) {
              final att = Map<String, dynamic>.from(subAttachments.first as Map);
              studentSubmissionMap = {
                'id': att['id']?.toString() ?? '',
                'file_name': att['file_name']?.toString() ?? 'Submitted Work',
                'storage_url': att['storage_url']?.toString() ?? '',
                'mime_type': att['mime_type']?.toString() ?? 'application/octet-stream',
                'file_size_bytes': (att['file_size_bytes'] as num?)?.toInt() ?? 0,
              };
            }

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
              'term_number': (m['term_number'] as num?)?.toInt() ?? 1,
              'gradebook_column_index': (m['gradebook_column_index'] as num?)?.toInt(),
              'subject_name': s['subject_name']?.toString() ?? '',
              'section_name': sec['section_name']?.toString() ?? '',
              'grade_level': sec['grade_level']?.toString() ?? '',
              'status': submission?['status']?.toString() ?? 'pending',
              'score': submission?['score'],
              'feedback': submission?['feedback'],
              'submitted_at': submission?['submitted_at'],
              'attachment': teacherAttachment,
              'student_submission': studentSubmissionMap,
            };
          }).toList();

          // Also fetch published digital assessments (quizzes and periodical exams)
          try {
            final attemptRows = await client
                .from('assessment_attempts')
                .select('assessment_id, status, submitted_at')
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

              classworkList.add({
                'id': aId,
                'subject_offering_id':
                    m['subject_offering_id']?.toString() ?? '',
                'type': 'exam',
                'title': m['title']?.toString() ?? 'Periodical Examination',
                'description':
                    'Periodical Examination (${m['time_limit_minutes'] ?? 60} mins)',
                'instructions': m['instructions']?.toString() ?? '',
                'assigned_at': m['available_from']?.toString(),
                'deadline': m['deadline']?.toString(),
                'max_score': 100,
                'completion_mode': 'online',
                'subject_name': s['subject_name']?.toString() ?? '',
                'section_name': sec['section_name']?.toString() ?? '',
                'grade_level': sec['grade_level']?.toString() ?? '',
                'status': isSubmitted ? 'submitted' : 'pending',
                'score': null,
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
      // Guard against taking stale fallback fields from another user
      final safeUser =
          (currentUser != null && currentUser.id == uid) ? currentUser : null;
      final p = profileRes ?? <String, dynamic>{};
      final data = <String, dynamic>{
        'student': {
          'id': uid,
          'email': authUser.email ?? safeUser?.email ?? '',
          'lrn': p['lrn']?.toString() ?? safeUser?.lrn ?? '',
          'first_name':
              p['first_name']?.toString() ?? safeUser?.firstName ?? '',
          'middle_name':
              p['middle_name']?.toString() ?? safeUser?.middleName,
          'last_name':
              p['last_name']?.toString() ?? safeUser?.lastName ?? '',
          'gender': p['gender']?.toString() ?? safeUser?.gender,
          'birthday':
              p['birthday']?.toString() ??
              safeUser?.birthday?.toIso8601String(),
          'enrollments': enrollmentsList,
        },
        'classwork': classworkList,
      };

      try {
        await AppDatabase.instance.setSetting(
          'cached_student_dashboard_$uid',
          jsonEncode(data),
        );
      } catch (_) {}

      final freshDashboard = StudentDashboardData.fromJson(data);
      _cachedDashboard = freshDashboard;
      unawaited(
        AppDataCache.instance.setCache(
          'student_dashboard_$uid',
          data,
        ),
      );
      return freshDashboard;
    } catch (e) {
      debugPrint('Pure Dart student dashboard notice: $e');
      if (_cachedDashboard != null &&
          _cachedDashboard!.student.id == authUser.uid) {
        return _cachedDashboard!;
      }
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
