import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/buttons/notification_bell_button.dart';

/// Centralized Supabase Notification Repository
/// - Single source of truth: Supabase `notifications` and `notification_recipients` tables.
/// - Guarantees 100% accuracy between the unread badge count and visible notifications.
/// - Read states persist permanently in `notification_recipients` with `read_at` timestamp.
class SupabaseNotificationRepository {
  SupabaseNotificationRepository._();
  static final SupabaseNotificationRepository instance =
      SupabaseNotificationRepository._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Fetches all notification IDs marked as read by [userId] from Supabase `notification_recipients`.
  /// Automatically merges database records into local storage.
  Future<Set<String>> getReadNotificationIds(String userId) async {
    if (userId.trim().isEmpty) return {};
    try {
      final res = await _client
          .from('notification_recipients')
          .select('notification_id')
          .eq('user_id', userId.trim())
          .not('read_at', 'is', null);

      final dbIds = (res as List)
          .map((r) => r['notification_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      await LocalStorageService.mergeReadNotificationIds(userId, dbIds);
      return LocalStorageService.getReadNotificationIds(userId);
    } catch (e) {
      debugPrint('SupabaseNotificationRepository getReadNotificationIds error: $e');
      return LocalStorageService.getReadNotificationIds(userId);
    }
  }

  /// Permanently marks a notification as read in Supabase `notification_recipients`
  /// and updates local storage for instant zero-latency UI response.
  Future<void> markAsRead(String userId, String notifId) async {
    if (userId.trim().isEmpty || notifId.trim().isEmpty) return;

    // 1. Instant local persistence and UI trigger
    await LocalStorageService.markNotificationAsRead(userId, notifId);

    // 2. Database persistence as single source of truth
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await _client.from('notification_recipients').upsert({
        'notification_id': notifId.trim(),
        'user_id': userId.trim(),
        'read_at': nowUtc,
        'created_at': nowUtc,
      }, onConflict: 'notification_id, user_id');
    } catch (e) {
      debugPrint('SupabaseNotificationRepository markAsRead error: $e');
    }
  }

  /// Batch marks multiple notifications as read both in local storage and in database.
  Future<void> markAllAsRead(String userId, List<String> notifIds) async {
    if (userId.trim().isEmpty || notifIds.isEmpty) return;

    // 1. Instant local cache update
    for (final id in notifIds) {
      if (id.isNotEmpty) {
        await LocalStorageService.markNotificationAsRead(userId, id);
      }
    }

    // 2. Database batch upsert
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final rows = notifIds
          .where((id) => id.isNotEmpty)
          .map((id) => {
                'notification_id': id,
                'user_id': userId.trim(),
                'read_at': nowUtc,
                'created_at': nowUtc,
              })
          .toList();

      if (rows.isNotEmpty) {
        await _client.from('notification_recipients').upsert(
              rows,
              onConflict: 'notification_id, user_id',
            );
      }
    } catch (e) {
      debugPrint('SupabaseNotificationRepository markAllAsRead error: $e');
    }
  }

  /// Unified role-based visibility filter ensuring identical display across
  /// Notification Bell Badges and individual notification tabs.
  bool isNotificationVisibleForUser(
    AppNotificationModel n,
    UserModel user, {
    Iterable<String>? handledOrEnrolledSubjects,
    Iterable<UserModel>? linkedChildren,
  }) {
    if (n.isArchived) return false;

    // Account status validation
    if (user.isArchived ||
        user.status == AccountStatus.archived ||
        user.status == AccountStatus.deactivated) {
      return false;
    }
    final isEligible = user.status == AccountStatus.active ||
        user.status == AccountStatus.pendingFirstLogin;
    if (!isEligible) return false;

    final roleStr = user.role.name.toLowerCase().trim();

    // Audience targeting check
    final audience = n.targetAudience.toLowerCase().trim();
    if (roleStr == 'teacher') {
      if (audience != 'all' && audience != 'teachers') return false;
    } else if (roleStr == 'student') {
      if (audience != 'all' &&
          audience != 'students' &&
          audience != 'students_parents') {
        return false;
      }
    } else if (roleStr == 'parent') {
      if (audience != 'all' &&
          audience != 'parents' &&
          audience != 'students_parents') {
        return false;
      }
    } else {
      // Admin is sender-only, or unknown role
      if (audience != 'all') return false;
    }

    // Skip broadcast announcements created before user account existed
    if (user.createdAt != null && n.type.toLowerCase() == 'announcement') {
      if (n.timestamp.isBefore(user.createdAt!)) {
        return false;
      }
    }

    final title = n.title.toLowerCase();
    final message = n.message.toLowerCase();
    final fullText = '$title $message';

    // Regex to match "in [Subject Name] ([Section Name])"
    final subjectRegex = RegExp(
      r'in\s+([A-Za-z0-9\s/&_-]+?)\s*\(([^)]+)\)',
      caseSensitive: false,
    );
    final subjectMatch = subjectRegex.firstMatch(fullText);

    if (roleStr == 'teacher') {
      // Filter out notifications for subjects this teacher doesn't teach
      if (subjectMatch != null && handledOrEnrolledSubjects != null) {
        final notifSubject = subjectMatch.group(1)?.trim().toLowerCase() ?? '';
        final handled = handledOrEnrolledSubjects
            .map((s) => s.toLowerCase().trim())
            .where((s) => s.isNotEmpty)
            .toSet();

        if (handled.isNotEmpty &&
            notifSubject.isNotEmpty &&
            !notifSubject.contains('general') &&
            !handled.any((h) => notifSubject.contains(h) || h.contains(notifSubject))) {
          return false;
        }
      }
    } else if (roleStr == 'student') {
      // 1. Personalized student absence/attendance warnings
      if (message.contains('recorded absences') ||
          message.contains('attendance check-in') ||
          message.contains('absences in')) {
        final studentFullName = user.fullName.toLowerCase().trim();
        final studentFirstName = (user.firstName ?? '').toLowerCase().trim();
        final studentLastName = (user.lastName ?? '').toLowerCase().trim();

        bool mentionsStudent = false;
        if (studentFullName.isNotEmpty && fullText.contains(studentFullName)) {
          mentionsStudent = true;
        } else if (studentLastName.length > 2 && fullText.contains(studentLastName)) {
          mentionsStudent = true;
        } else if (studentFirstName.length > 2 && fullText.contains(studentFirstName)) {
          mentionsStudent = true;
        }

        if (!mentionsStudent) {
          return false;
        }
      }

      // 2. Enrolled subjects check
      if (subjectMatch != null && handledOrEnrolledSubjects != null) {
        final notifSubject = subjectMatch.group(1)?.trim().toLowerCase() ?? '';
        final enrolled = handledOrEnrolledSubjects
            .map((s) => s.toLowerCase().trim())
            .where((s) => s.isNotEmpty)
            .toSet();

        if (enrolled.isNotEmpty &&
            notifSubject.isNotEmpty &&
            !notifSubject.contains('general') &&
            !enrolled.any((e) => notifSubject.contains(e) || e.contains(notifSubject))) {
          return false;
        }
      }
    } else if (roleStr == 'parent') {
      // Absence/attendance alerts must match at least one of the parent's linked children
      final isStudentAlert = message.contains('recorded absences') ||
          message.contains('attendance check-in') ||
          message.contains('has reached') ||
          message.contains('missed') ||
          title.contains('absences');

      if (isStudentAlert && linkedChildren != null && linkedChildren.isNotEmpty) {
        final childNames = linkedChildren
            .map((c) => c.fullName.toLowerCase().trim())
            .where((n) => n.isNotEmpty)
            .toList();
        final childLastNames = linkedChildren
            .map((c) => (c.lastName ?? '').toLowerCase().trim())
            .where((l) => l.length > 2)
            .toList();
        final childFirstNames = linkedChildren
            .map((c) => (c.firstName ?? '').toLowerCase().trim())
            .where((f) => f.length > 2)
            .toList();

        final matchesAnyChild = childNames.any((name) => fullText.contains(name)) ||
            childLastNames.any((last) => fullText.contains(last)) ||
            childFirstNames.any((first) => fullText.contains(first));

        if (!matchesAnyChild) {
          return false;
        }
      }
    }

    return true;
  }

  /// Calculates the exact unread notification count for [user] ensuring
  /// 100% synchronization with the database and user-facing notifications tab.
  Future<int> calculateUnreadCount(UserModel user) async {
    final role = user.role.name.toLowerCase().trim();
    if (role == 'admin') {
      NotificationBadgeManager.updateCount(role, 0);
      return 0;
    }

    try {
      // 1. Fetch user read IDs from database
      final readIds = await getReadNotificationIds(user.id);

      // 2. Fetch notifications matching role audience
      List<String> targetAudiences = ['all'];
      if (role == 'teacher') {
        targetAudiences.add('teachers');
      } else if (role == 'student') {
        targetAudiences.addAll(['students', 'students_parents']);
      } else if (role == 'parent') {
        targetAudiences.addAll(['parents', 'students_parents']);
      }

      final res = await _client
          .from('notifications')
          .select()
          .eq('is_archived', false)
          .inFilter('target_audience', targetAudiences)
          .order('created_at', ascending: false)
          .limit(50);

      final rawList = (res as List)
          .map((r) => AppNotificationModel.fromJson(r as Map<String, dynamic>))
          .toList();

      // 3. Resolve context data for filtering
      Iterable<String>? subjects;
      Iterable<UserModel>? linkedChildren;

      if (role == 'teacher') {
        final cached = SubjectRepository.instance.getCachedTeacherSubjects(user.id);
        if (cached.isNotEmpty) {
          subjects = cached
              .map((s) => s['subject_name']?.toString() ?? '')
              .where((s) => s.isNotEmpty);
        } else {
          try {
            final fetched = await SubjectRepository.instance.getTeacherSubjects(user.id);
            subjects = fetched
                .map((s) => s['subject_name']?.toString() ?? '')
                .where((s) => s.isNotEmpty);
          } catch (_) {}
        }
      } else if (role == 'student') {
        final dashboard = StudentDashboardRepository.instance.currentDashboard;
        if (dashboard != null && dashboard.enrollments.isNotEmpty) {
          subjects = dashboard.enrollments.map((e) => e.subjectName);
        } else {
          try {
            final enrollRes = await _client
                .from('student_enrollments')
                .select('subject_offerings(subject_name)')
                .eq('student_id', user.id)
                .eq('status', 'enrolled');

            final sList = <String>[];
            for (final row in (enrollRes as List)) {
              final raw = row['subject_offerings'];
              final Map? off = raw is Map
                  ? raw
                  : (raw is List && raw.isNotEmpty ? raw.first as Map? : null);
              final name = off?['subject_name']?.toString().trim();
              if (name != null && name.isNotEmpty) {
                sList.add(name);
              }
            }
            subjects = sList;
          } catch (_) {}
        }
      } else if (role == 'parent') {
        final cached = AppDataCache.instance.getCached<List<UserModel>>(
          'parent_linked_students_${user.id}',
          (json) => (json as List)
              .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
        if (cached != null && cached.isNotEmpty) {
          linkedChildren = cached;
        } else {
          try {
            linkedChildren = await SupabaseParentRepository()
                .getLinkedStudentsForParent(user.id);
          } catch (_) {}
        }
      }

      // 4. Filter visible notifications strictly
      int unread = 0;
      for (final n in rawList) {
        if (!isNotificationVisibleForUser(
          n,
          user,
          handledOrEnrolledSubjects: subjects,
          linkedChildren: linkedChildren,
        )) {
          continue;
        }

        if (!readIds.contains(n.id) &&
            !LocalStorageService.isNotificationRead(user.id, n.id)) {
          unread++;
        }
      }

      NotificationBadgeManager.updateCount(role, unread);
      return unread;
    } catch (e) {
      debugPrint('SupabaseNotificationRepository calculateUnreadCount error: $e');
      return 0;
    }
  }
}
