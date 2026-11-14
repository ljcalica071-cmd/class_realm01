import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

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
    LocalStorageService.notificationReadStateEpoch.addListener(_onReadStateChanged);
    _subscribeToNotifs();
  }

  @override
  void dispose() {
    LocalStorageService.notificationReadStateEpoch.removeListener(_onReadStateChanged);
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
        .channel('bell_badge_${widget.role}_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _calculateUnreadCount(),
        )
        .subscribe();
  }

  Future<void> _calculateUnreadCount() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _unreadCount = 0);
      return;
    }

    try {
      final role = widget.role.toLowerCase().trim();
      List<String> targetAudiences = ['all'];
      if (role == 'teacher') {
        targetAudiences.add('teachers');
      } else if (role == 'student') {
        targetAudiences.addAll(['students', 'students_parents']);
      } else if (role == 'parent') {
        targetAudiences.addAll(['parents', 'students_parents']);
      }

      final res = await Supabase.instance.client
          .from('notifications')
          .select('id, created_at, is_archived, target_audience')
          .eq('is_archived', false)
          .inFilter('target_audience', targetAudiences)
          .order('created_at', ascending: false)
          .limit(50);

      final readIds = LocalStorageService.getReadNotificationIds(user.id);
      int unread = 0;

      for (final row in (res as List)) {
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        // Skip announcements created before user account was registered
        if (user.createdAt != null && row['created_at'] != null) {
          final dt = DateTime.tryParse(row['created_at'].toString());
          if (dt != null && dt.isBefore(user.createdAt!)) {
            continue;
          }
        }

        if (!readIds.contains(id)) {
          unread++;
        }
      }

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
          icon: Icon(
            LucideIcons.bell,
            color: color,
            size: 20,
          ),
          onPressed: widget.onTap,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626), // High-visibility notification badge red
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
