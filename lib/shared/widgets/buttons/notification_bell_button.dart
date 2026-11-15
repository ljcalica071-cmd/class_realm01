import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';

/// Reusable Manager to sync unread notification badge counts across Header Bell & Sidebars
class NotificationBadgeManager {
  static final ValueNotifier<int> teacherUnreadNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> studentUnreadNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> parentUnreadNotifier = ValueNotifier<int>(0);

  static ValueNotifier<int> getNotifierForRole(String role) {
    switch (role.toLowerCase().trim()) {
      case 'teacher':
        return teacherUnreadNotifier;
      case 'student':
        return studentUnreadNotifier;
      case 'parent':
        return parentUnreadNotifier;
      default:
        return teacherUnreadNotifier;
    }
  }

  static void updateCount(String role, int count) {
    getNotifierForRole(role).value = count;
  }
}

/// Reusable Notification Bell Icon with Unread Badge Indicator (1, 2, 3...)
/// - Consistent LucideIcons.bell across Teacher, Student, and Parent portals.
/// - Listens to local read state epoch and Supabase realtime announcements to update badge.
class NotificationBellButton extends StatefulWidget {
  final VoidCallback onTap;
  final String role; // 'teacher', 'student', 'parent'
  final Color? iconColor;
  final String tooltip;

  const NotificationBellButton({
    super.key,
    required this.onTap,
    required this.role,
    this.iconColor,
    this.tooltip = 'Notifications',
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _unreadCount = 0;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _calculateUnreadCount();
    LocalStorageService.notificationReadStateEpoch.addListener(
      _onReadStateChanged,
    );
    _subscribeToNotifs();
  }

  @override
  void dispose() {
    LocalStorageService.notificationReadStateEpoch.removeListener(
      _onReadStateChanged,
    );
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _onReadStateChanged() {
    if (mounted) {
      _calculateUnreadCount();
    }
  }

  void _subscribeToNotifs() {
    _realtimeChannel = Supabase.instance.client
        .channel(
          'bell_badge_${widget.role}_${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _calculateUnreadCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_recipients',
          callback: (_) => _calculateUnreadCount(),
        )
        .subscribe();
  }

  Future<void> _calculateUnreadCount() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _unreadCount = 0);
      NotificationBadgeManager.updateCount(widget.role, 0);
      return;
    }

    try {
      final unread = await SupabaseNotificationRepository.instance
          .calculateUnreadCount(user);

      if (mounted) {
        setState(() => _unreadCount = unread);
      }
    } catch (_) {
      // Fallback silently if offline
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.iconColor ?? theme.colorScheme.onSurface;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: widget.tooltip,
          icon: Icon(LucideIcons.bell, color: color, size: 24),
          onPressed: widget.onTap,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 3,
            top: 3,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFDC2626,
                  ), // High-visibility notification badge red
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
