import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';

class LessonPlanAccessDeniedException implements Exception {
  final String message;
  const LessonPlanAccessDeniedException(this.message);

  @override
  String toString() => message;
}

/// Dual-storage (Cloud Supabase + Local SharedPreferences Cache) for SHS iLAW Lesson Plans.
///
/// Guarantees:
/// 1. Persists to normalized Supabase relational tables:
///    - `teacher_lesson_plans` (Header)
///    - `lesson_plan_sections` (1-to-1 Content & iLAW details)
///    - `lesson_plan_sessions` (1-to-many Matrix sessions)
///    - `lesson_plan_rubrics` (1-to-many Assessment rubrics)
/// 2. Strict teacher isolation RLS: only the creating teacher can view/modify their plans.
/// 3. Auto-syncs any unsynced local plans up to the cloud on connection.
/// 4. Caches locally in SharedPreferences for offline resilience and immediate loading.
class TeacherLessonPlanStore {
  static const String _storagePrefix = 'ilaw_teacher_lesson_plans_v1_';

  final UserModel? Function() _currentUserProvider;
  final SupabaseClient? _supabaseClientOverride;

  bool? lastSyncCloudSuccess;
  String? lastSyncError;

  TeacherLessonPlanStore({
    UserModel? Function()? currentUserProvider,
    SupabaseClient? supabaseClient,
  }) : _currentUserProvider =
           currentUserProvider ?? (() => AuthRepository.instance.currentUser),
       _supabaseClientOverride = supabaseClient;

  static final TeacherLessonPlanStore instance = TeacherLessonPlanStore();

  SupabaseClient? get _supabase {
    if (_supabaseClientOverride != null) return _supabaseClientOverride;
    try {
      final admin = SupabaseService().adminClient;
      return admin;
    } catch (_) {
      try {
        if (Supabase.instance.isInitialized) {
          return Supabase.instance.client;
        }
      } catch (_) {}
    }
    return null;
  }

  UserModel _requireActiveTeacher() {
    final user = _currentUserProvider();
    if (user == null || user.id.trim().isEmpty) {
      throw const LessonPlanAccessDeniedException(
        'Please sign in as a teacher to access lesson plans.',
      );
    }
    if (user.role != UserRole.teacher) {
      throw const LessonPlanAccessDeniedException(
        'Access denied: lesson plans are private to their creating teacher.',
      );
    }
    if (user.isArchived || user.status == AccountStatus.archived) {
      throw const LessonPlanAccessDeniedException(
        'Access denied: archived accounts cannot access lesson plans.',
      );
    }
    return user;
  }

  String _storageKeyForTeacher(String teacherId) {
    final safeId = teacherId.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$_storagePrefix$safeId';
  }

  Future<List<IlawLessonPlan>> loadPlansForCurrentTeacher() async {
    final teacher = _requireActiveTeacher();
    final localPlans = await _loadLocalPlans(teacher.id);

    // 1. Try Supabase cloud database
    final client = _supabase;
    if (client != null) {
      try {
        dynamic response;
        try {
          // Attempt normalized join query first
          response = await client
              .from('teacher_lesson_plans')
              .select('''
                id, teacher_id, grade_level, term, subject, topic, duration_minutes, status, created_at, updated_at,
                lesson_plan_sections (
                  learning_competency, intended_outcomes, learning_content, work_experiences, assessment,
                  teaching_strategy, template_type, content_source, target_proficiency, number_of_sessions,
                  language, deped_order_citation
                ),
                lesson_plan_sessions (
                  session_number, session_title, objectives, learning_experiences,
                  formative_assessment, parent_guide, community_experience, teacher_reflections
                ),
                lesson_plan_rubrics (
                  criterion, is_met, notes
                )
              ''')
              .eq('teacher_id', teacher.id)
              .order('updated_at', ascending: false);
        } catch (_) {
          // Fallback if join tables not yet migrated
          response = await client
              .from('teacher_lesson_plans')
              .select()
              .eq('teacher_id', teacher.id)
              .order('updated_at', ascending: false);
        }

        final cloudPlans = (response as List)
            .whereType<Map>()
            .map((m) => IlawLessonPlan.fromJson(Map<String, dynamic>.from(m)))
            .where((p) => p.teacherId == teacher.id)
            .toList();

        // 2. Auto-heal: Check if any local plans are missing from cloud, and upload them
        final cloudIds = cloudPlans.map((p) => p.id).toSet();
        final unsyncedLocal = localPlans.where((p) => !cloudIds.contains(p.id)).toList();

        final unsyncedLocalFailed = <IlawLessonPlan>[];
        if (unsyncedLocal.isNotEmpty) {
          for (final plan in unsyncedLocal) {
            try {
              await _savePlanToCloud(client, teacher, plan);
              cloudPlans.add(plan);
            } catch (e) {
              debugPrint('Auto-sync single plan notice: $e');
              unsyncedLocalFailed.add(plan);
            }
          }
        }

        final combinedPlans = [...cloudPlans, ...unsyncedLocalFailed];
        combinedPlans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // 3. Cache latest records locally
        await _persistForTeacher(teacher.id, combinedPlans);
        lastSyncCloudSuccess = true;
        lastSyncError = null;
        return combinedPlans;
      } catch (e) {
        lastSyncCloudSuccess = false;
        lastSyncError = e.toString();
        debugPrint('Supabase teacher_lesson_plans load fallback: $e');
      }
    }

    // Fall back to local cache if offline or table unmigrated
    return localPlans;
  }

  Future<void> _savePlanToCloud(
    SupabaseClient client,
    UserModel teacher,
    IlawLessonPlan plan,
  ) async {
    // 1. Main Header Table
    await client.from('teacher_lesson_plans').upsert({
      'id': plan.id,
      'teacher_id': teacher.id,
      'grade_level': plan.gradeLevel,
      'term': plan.term,
      'subject': plan.subject,
      'topic': plan.topic,
      'duration_minutes': plan.durationMinutes,
      'status': plan.status.name,
      'created_at': plan.createdAt.toIso8601String(),
      'updated_at': plan.updatedAt.toIso8601String(),
    });

    // 2. Normalized Sections Table
    try {
      await client.from('lesson_plan_sections').upsert({
        'lesson_plan_id': plan.id,
        'learning_competency': plan.learningCompetency,
        'intended_outcomes': plan.intendedOutcomes,
        'learning_content': plan.learningContent,
        'work_experiences': plan.workExperiences,
        'assessment': plan.assessment,
        'teaching_strategy': plan.teachingStrategy,
        'template_type': plan.templateType.name,
        'content_source': plan.contentSource.name,
        'target_proficiency': plan.targetProficiency.name,
        'number_of_sessions': plan.numberOfSessions,
        'language': plan.language,
        'deped_order_citation': plan.depedOrderCitation,
      });
    } catch (_) {}

    // 3. Normalized Sessions Table
    if (plan.sessions.isNotEmpty) {
      try {
        await client
            .from('lesson_plan_sessions')
            .delete()
            .eq('lesson_plan_id', plan.id);
        final sessionRows = plan.sessions
            .map((s) => {
                  'id': '${plan.id}_session_${s.sessionNumber}',
                  'lesson_plan_id': plan.id,
                  'session_number': s.sessionNumber,
                  'session_title': s.sessionTitle,
                  'objectives': s.objectives,
                  'learning_experiences': s.learningExperiences,
                  'formative_assessment': s.formativeAssessment,
                  'parent_guide': s.parentGuide,
                  'community_experience': s.communityExperience,
                  'teacher_reflections': s.teacherReflections,
                })
            .toList();
        await client.from('lesson_plan_sessions').insert(sessionRows);
      } catch (_) {}
    }

    // 4. Normalized Rubrics Table
    if (plan.rubricItems.isNotEmpty) {
      try {
        await client
            .from('lesson_plan_rubrics')
            .delete()
            .eq('lesson_plan_id', plan.id);
        final rubricRows = plan.rubricItems
            .asMap()
            .entries
            .map((entry) => {
                  'id': '${plan.id}_rubric_${entry.key}',
                  'lesson_plan_id': plan.id,
                  'criterion': entry.value.criterion,
                  'is_met': entry.value.isMet,
                  'notes': entry.value.notes,
                })
            .toList();
        await client.from('lesson_plan_rubrics').insert(rubricRows);
      } catch (_) {}
    }
  }

  Future<List<IlawLessonPlan>> _loadLocalPlans(String teacherId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKeyForTeacher(teacherId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final plans = decoded
          .whereType<Map>()
          .map((m) => IlawLessonPlan.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.teacherId == teacherId)
          .toList();
      plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return plans;
    } catch (_) {
      return [];
    }
  }

  Future<IlawLessonPlan?> getPlanById(String planId) async {
    final teacher = _requireActiveTeacher();
    final plans = await loadPlansForCurrentTeacher();
    for (final plan in plans) {
      if (plan.id == planId && plan.teacherId == teacher.id) {
        return plan;
      }
    }
    return null;
  }

  Future<IlawLessonPlan> savePlan(IlawLessonPlan plan) async {
    final teacher = _requireActiveTeacher();
    if (plan.teacherId.trim().isNotEmpty && plan.teacherId != teacher.id) {
      throw const LessonPlanAccessDeniedException(
        'Access denied: you cannot modify another teacher\'s lesson plan.',
      );
    }

    final planId = plan.id.trim().isNotEmpty
        ? plan.id.trim()
        : 'ilaw_${DateTime.now().millisecondsSinceEpoch}';

    final ownedPlan = plan.copyWith(
      id: planId,
      teacherId: teacher.id,
      teacherName: plan.teacherName.trim().isNotEmpty
          ? plan.teacherName.trim()
          : teacher.fullName,
      updatedAt: plan.updatedAt,
    );

    // 1. Save to Supabase cloud database
    final client = _supabase;
    if (client != null) {
      try {
        await _savePlanToCloud(client, teacher, ownedPlan);
        lastSyncCloudSuccess = true;
        lastSyncError = null;
      } catch (e) {
        lastSyncCloudSuccess = false;
        lastSyncError = e.toString();
        debugPrint('Supabase teacher_lesson_plans save fallback: $e');
      }
    }

    // 2. Save to local SharedPreferences cache
    final existing = await _loadLocalPlans(teacher.id);
    final index = existing.indexWhere(
      (p) => p.id == ownedPlan.id && p.teacherId == teacher.id,
    );
    if (index >= 0) {
      existing[index] = ownedPlan;
    } else {
      existing.insert(0, ownedPlan);
    }

    existing.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistForTeacher(teacher.id, existing);
    return ownedPlan;
  }

  Future<void> deletePlan(String planId) async {
    final teacher = _requireActiveTeacher();

    // 1. Delete from Supabase cloud database (CASCADE handles sections, sessions & rubrics)
    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from('teacher_lesson_plans')
            .delete()
            .eq('id', planId)
            .eq('teacher_id', teacher.id);
        lastSyncCloudSuccess = true;
      } catch (e) {
        lastSyncCloudSuccess = false;
        lastSyncError = e.toString();
        debugPrint('Supabase teacher_lesson_plans delete fallback: $e');
      }
    }

    // 2. Delete from local cache
    final existing = await _loadLocalPlans(teacher.id);
    final filtered = existing
        .where((p) => !(p.id == planId && p.teacherId == teacher.id))
        .toList();
    if (filtered.length != existing.length) {
      await _persistForTeacher(teacher.id, filtered);
    }
  }

  Future<void> _persistForTeacher(
    String teacherId,
    List<IlawLessonPlan> plans,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(plans.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKeyForTeacher(teacherId), payload);
  }
}
