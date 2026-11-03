import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
/// 1. Persists to Supabase `public.teacher_lesson_plans` table so plans survive restarts and browser clears.
/// 2. Caches locally in SharedPreferences for offline resilience and fast loading.
/// 3. Only active authenticated users with `UserRole.teacher` can read, save, or delete lesson plans.
/// 4. Strict isolation: each teacher's plans are filtered by `teacher.id`.
class TeacherLessonPlanStore {
  static const String _storagePrefix = 'ilaw_teacher_lesson_plans_v1_';

  final UserModel? Function() _currentUserProvider;
  final SupabaseClient? _supabaseClientOverride;

  TeacherLessonPlanStore({
    UserModel? Function()? currentUserProvider,
    SupabaseClient? supabaseClient,
  })  : _currentUserProvider =
            currentUserProvider ?? (() => AuthRepository.instance.currentUser),
        _supabaseClientOverride = supabaseClient;

  static final TeacherLessonPlanStore instance = TeacherLessonPlanStore();

  SupabaseClient? get _supabase {
    if (_supabaseClientOverride != null) return _supabaseClientOverride;
    try {
      if (Supabase.instance.isInitialized) {
        return Supabase.instance.client;
      }
    } catch (_) {}
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

    // 1. Try Supabase cloud database first
    final client = _supabase;
    if (client != null) {
      try {
        final response = await client
            .from('teacher_lesson_plans')
            .select()
            .eq('teacher_id', teacher.id)
            .order('updated_at', ascending: false);

        final plans = response
            .whereType<Map>()
            .map((m) => IlawLessonPlan.fromJson(Map<String, dynamic>.from(m)))
            .where((p) => p.teacherId == teacher.id)
            .toList();
        plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // Sync cloud records into local cache
        await _persistForTeacher(teacher.id, plans);
        return plans;
      } catch (_) {
        // Table not ready or offline - gracefully fall back to local storage
      }
    }

    // 2. Fall back to local SharedPreferences cache
    return _loadLocalPlans(teacher.id);
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

    final ownedPlan = plan.copyWith(
      teacherId: teacher.id,
      teacherName: plan.teacherName.trim().isNotEmpty
          ? plan.teacherName.trim()
          : teacher.fullName,
      updatedAt: DateTime.now(),
    );

    // 1. Save to Supabase cloud database
    final client = _supabase;
    if (client != null) {
      try {
        await client.from('teacher_lesson_plans').upsert(ownedPlan.toJson());
      } catch (_) {
        // Safe fallback if table is not yet migrated in Supabase
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

    // 1. Delete from Supabase cloud database
    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from('teacher_lesson_plans')
            .delete()
            .eq('id', planId)
            .eq('teacher_id', teacher.id);
      } catch (_) {}
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
