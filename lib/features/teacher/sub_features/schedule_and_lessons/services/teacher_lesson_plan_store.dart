import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';

class LessonPlanAccessDeniedException implements Exception {
  final String message;
  const LessonPlanAccessDeniedException(this.message);

  @override
  String toString() => message;
}

/// Strictly isolated per-teacher storage for SHS iLAW Lesson Plans.
///
/// Guarantees:
/// 1. Zero mutations to Supabase SQL schema/tables.
/// 2. Only active authenticated users with `UserRole.teacher` can read, save,
///    or delete lesson plans (Students, Parents, and logged-out users are blocked).
/// 3. Each teacher's lesson plans live in a dedicated key partitioned by their
///    unique `teacherId`, and ownership (`plan.teacherId == activeTeacher.id`)
///    is verified on every operation so no teacher can ever view or modify
///    another teacher's plans.
class TeacherLessonPlanStore {
  static const String _storagePrefix = 'ilaw_teacher_lesson_plans_v1_';

  final UserModel? Function() _currentUserProvider;

  TeacherLessonPlanStore({UserModel? Function()? currentUserProvider})
    : _currentUserProvider =
          currentUserProvider ?? (() => AuthRepository.instance.currentUser);

  static final TeacherLessonPlanStore instance = TeacherLessonPlanStore();

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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKeyForTeacher(teacher.id));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final plans = decoded
          .whereType<Map>()
          .map((m) => IlawLessonPlan.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.teacherId == teacher.id)
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

    final existing = await loadPlansForCurrentTeacher();
    final ownedPlan = plan.copyWith(
      teacherId: teacher.id,
      teacherName: plan.teacherName.trim().isNotEmpty
          ? plan.teacherName.trim()
          : teacher.fullName,
      updatedAt: DateTime.now(),
    );

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
    final existing = await loadPlansForCurrentTeacher();
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
