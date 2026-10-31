import 'dart:async';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';

/// Real-Time Paginated Student Notifications Tab (Edge Cases #8, #9, #10)
class StudentNotificationsTab extends StatefulWidget {
  const StudentNotificationsTab({super.key});

  @override
  State<StudentNotificationsTab> createState() =>
      _StudentNotificationsTabState();
}

class _StudentNotificationsTabState extends State<StudentNotificationsTab> {
  final List<AppNotificationModel> _notifications = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadNotifications(initial: true);
    _scrollController.addListener(_onScroll);
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribeToRealtime() {
    _channel = Supabase.instance.client
        .channel('student_notifications_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _loadNotifications(initial: true, silent: true),
        )
        .subscribe();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications({
    bool initial = false,
    bool silent = false,
  }) async {
    final targetOffset = initial ? 0 : _offset;
    if (initial) {
      if (!silent) {
        setState(() {
          _isLoading = true;
          _offset = 0;
          _hasMore = true;
        });
      }
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('is_archived', false)
          .inFilter('target_audience', ['all', 'students', 'students_parents'])
          .order('created_at', ascending: false)
          .range(targetOffset, targetOffset + _pageSize - 1);

      final items = (res as List)
          .map((r) => AppNotificationModel.fromJson(r as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          if (initial) {
            _notifications
              ..clear()
              ..addAll(items);
            _offset = items.length;
          } else {
            _notifications.addAll(items);
            _offset += items.length;
          }
          _hasMore = items.length == _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading student notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading && _notifications.isEmpty) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: theme.colorScheme.primary,
          size: 40,
        ),
      );
    }

    return AppPullToRefresh(
      onRefresh: () => _loadNotifications(initial: true, silent: true),
      child: _notifications.isEmpty
          ? AppPullToRefresh.scrollableState(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isDark ? 0.14 : 0.09,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You are all caught up',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There are no announcements or alerts for you right now.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _notifications.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _notifications.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: LoadingAnimationWidget.staggeredDotsWave(
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                    ),
                  );
                }
                final notification = _notifications[index];
                return ExpandableNotificationCard(notification: notification);
              },
            ),
    );
  }
}
