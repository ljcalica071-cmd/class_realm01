import 'dart:async';
import 'package:flutter/material.dart';
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
}

