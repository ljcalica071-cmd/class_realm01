import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

enum InAppNotificationSeverity {
  info,
  warningLevel1, // 3 Absences - Amber
  warningLevel2, // 6 Absences - Orange
  warningCritical, // 10 Absences - Red
}

class InAppPushBannerData {
  final String id;
  final String title;
  final String message;
  final String? subtitle;
  final InAppNotificationSeverity severity;
  final VoidCallback? onTap;
  final DateTime timestamp;

  InAppPushBannerData({
    required this.id,
    required this.title,
    required this.message,
    this.subtitle,
    this.severity = InAppNotificationSeverity.info,
    this.onTap,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class InAppNotificationService {
  static final ValueNotifier<InAppPushBannerData?> currentBannerNotifier =
      ValueNotifier<InAppPushBannerData?>(null);

  static Timer? _autoDismissTimer;
  static RealtimeChannel? _announcementsChannel;

  /// Shows an in-app push notification banner at the top of the viewport.
  /// If notifications are disabled in local storage/settings, this call is safely ignored.
  static void showBanner({
    required String title,
    required String message,
    String? subtitle,
    InAppNotificationSeverity severity = InAppNotificationSeverity.info,
    VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 4500),
  }) {
    if (!LocalStorageService.arePushNotificationsEnabled()) {
      return;
    }

    _autoDismissTimer?.cancel();

    final banner = InAppPushBannerData(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      subtitle: subtitle,
      severity: severity,
      onTap: onTap,
    );

    currentBannerNotifier.value = banner;

    _autoDismissTimer = Timer(duration, () {
      if (currentBannerNotifier.value?.id == banner.id) {
        dismiss();
      }
    });
  }

  /// Manually dismiss the active banner
  static void dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    currentBannerNotifier.value = null;
  }

  /// Subscribes to institutional broadcast announcements via Supabase Realtime.
  /// When a new broadcast announcement is inserted that matches the user's role:
  /// - Automatically verifies [LocalStorageService.arePushNotificationsEnabled()]
  /// - If enabled, displays the in-app push banner at the top of the viewport
  static void subscribeToAnnouncements({required String role}) {
    if (_announcementsChannel != null) {
      Supabase.instance.client.removeChannel(_announcementsChannel!);
      _announcementsChannel = null;
    }

    final normalizedRole = role.toLowerCase().trim();
    // Admin only sends broadcasts and is strictly excluded from receiving student/teacher/parent notifications
    if (normalizedRole == 'admin') {
      return;
    }

    _announcementsChannel = Supabase.instance.client
        .channel('global_announcements_channel_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            try {
              if (normalizedRole == 'admin') return;
              final newRecord = payload.newRecord;
              if (newRecord.isEmpty) return;

              final isArchived = newRecord['is_archived'] as bool? ?? false;
              if (isArchived) return;

              final targetAudience = (newRecord['target_audience'] as String? ?? 'all').toLowerCase();
              final title = newRecord['title'] as String? ?? 'School Announcement';
              final message = newRecord['message'] as String? ?? '';

              bool audienceMatches = false;
              if (targetAudience == 'all' && normalizedRole != 'admin') {
                audienceMatches = true;
              } else if (normalizedRole == 'teacher' && targetAudience == 'teachers') {
                audienceMatches = true;
              } else if (normalizedRole == 'student' &&
                  (targetAudience == 'students' || targetAudience == 'students_parents')) {
                audienceMatches = true;
              } else if (normalizedRole == 'parent' &&
                  (targetAudience == 'parents' || targetAudience == 'students_parents')) {
                audienceMatches = true;
              }

              if (audienceMatches) {
                // Detect attendance warning levels & set severity appropriately
                InAppNotificationSeverity severity = InAppNotificationSeverity.info;
                String subtitle = 'School Announcement';

                final combined = '$title $message'.toLowerCase();
                final notificationType = (newRecord['notification_type'] as String? ?? '').toLowerCase();
                final isAttendance = notificationType == 'attendance' ||
                    combined.contains('absence') ||
                    combined.contains('attendance');

                if (isAttendance) {
                  if (combined.contains('10 absence') ||
                      combined.contains('critical') ||
                      combined.contains('final warning') ||
                      combined.contains('sardo')) {
                    severity = InAppNotificationSeverity.warningCritical;
                    subtitle = 'Critical Attendance Notice';
                  } else if (combined.contains('6 absence') ||
                      combined.contains('2nd warning')) {
                    severity = InAppNotificationSeverity.warningLevel2;
                    subtitle = 'Attendance Warning';
                  } else if (combined.contains('3 absence') ||
                      combined.contains('1st warning')) {
                    severity = InAppNotificationSeverity.warningLevel1;
                    subtitle = 'Attendance Notice';
                  } else {
                    subtitle = 'Attendance Notice';
                  }
                }

                showBanner(
                  title: title,
                  message: message,
                  subtitle: subtitle,
                  severity: severity,
                  duration: const Duration(seconds: 6),
                );
              }
            } catch (e) {
              debugPrint('Error handling realtime broadcast announcement: $e');
            }
          },
        )
        .subscribe();
  }

  /// Unsubscribes from realtime announcements
  static void unsubscribeFromAnnouncements() {
    if (_announcementsChannel != null) {
      Supabase.instance.client.removeChannel(_announcementsChannel!);
      _announcementsChannel = null;
    }
  }
}

