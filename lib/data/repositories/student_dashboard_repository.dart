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
    if (!forceRefresh && _cachedDashboard != null) {
      return _cachedDashboard!;
    }

    // 1. FAST LOCAL READ (0 milliseconds load, Web + Native parity)
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (!forceRefresh && authUser != null) {
      final cachedWeb = AppDataCache.instance.getCached<StudentDashboardData>(
        'student_dashboard_${authUser.uid}',
        (json) => StudentDashboardData.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      if (cachedWeb != null) {
        _cachedDashboard = cachedWeb;
        if (!AppDataCache.instance.isFresh('student_dashboard_${authUser.uid}')) {
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
      // 1. Fetch student profile directly via Pure Dart
      final profileRes = await client
          .from('student_profiles')
          .select(
            'student_id, lrn, first_name, middle_name, last_name, birthday, gender',
          )
          .eq('student_id', uid)
          .maybeSingle();

      // 2. Fetch student enrollments directly via Pure Dart
      final enrollmentRows = await client
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

      final enrollmentsList = (enrollmentRows as List? ?? []).map((row) {
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

      // 3. Fetch classwork items and the current student's submissions.
      List<Map<String, dynamic>> classworkList = [];
      if (offeringIds.isNotEmpty) {
        final submissionRows = await client
            .from('student_classwork_submissions')
            .select('classwork_id, status, score, feedback')
            .eq('student_id', uid);
        final submissionsByClassworkId = <String, Map<String, dynamic>>{};
        for (final row in submissionRows as List) {
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

        classworkList = (items as List? ?? []).map<Map<String, dynamic>>((i) {
          final m = Map<String, dynamic>.from(i as Map);
          final off = m['subject_offerings'] as Map<String, dynamic>? ?? {};
          final s = off['subjects'] as Map<String, dynamic>? ?? {};
          final sec = off['sections'] as Map<String, dynamic>? ?? {};
          final submission = submissionsByClassworkId[m['id']?.toString()];
          return {
            'id': m['id']?.toString() ?? '',
            'subject_offering_id': m['subject_offering_id']?.toString() ?? '',
            'type': m['classwork_type']?.toString() ?? 'activity',
            'title': m['title']?.toString() ?? '',
            'description': m['description']?.toString(),
            'instructions': m['instructions']?.toString(),
            'assigned_at': m['assigned_at']?.toString(),
            'deadline': m['deadline']?.toString(),
            'max_score': m['max_score'] is num ? m['max_score'] : 100,
            'subject_name': s['subject_name']?.toString() ?? '',
            'section_name': sec['section_name']?.toString() ?? '',
            'grade_level': sec['grade_level']?.toString() ?? '',
            'status': submission?['status']?.toString() ?? 'pending',
            'score': submission?['score'],
            'feedback': submission?['feedback'],
          };
        }).toList();
      }

      final p = profileRes ?? <String, dynamic>{};
      final data = <String, dynamic>{
        'student': {
          'id': uid,
          'email': authUser.email ?? '',
          'lrn': p['lrn']?.toString() ?? '',
          'first_name': p['first_name']?.toString() ?? '',
          'middle_name': p['middle_name']?.toString(),
          'last_name': p['last_name']?.toString() ?? '',
          'gender': p['gender']?.toString(),
          'birthday': p['birthday']?.toString(),
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
      unawaited(AppDataCache.instance.setCache(
        'student_dashboard_${authUser.uid}',
        data,
      ));
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
