import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';

/// Real-Time Paginated Parent Notifications Tab (Edge Cases #8, #9, #10)
class ParentNotificationsTab extends StatefulWidget {
  final List<AppNotificationModel>? notifications;

  const ParentNotificationsTab({super.key, this.notifications});

  @override
  State<ParentNotificationsTab> createState() => _ParentNotificationsTabState();
}

class _ParentNotificationsTabState extends State<ParentNotificationsTab> {
  final List<AppNotificationModel> _items = [];
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
    if (widget.notifications != null && widget.notifications!.isNotEmpty) {
      _items.addAll(widget.notifications!);
      _isLoading = false;
    } else {
      _loadNotifications(initial: true);
      _subscribeToRealtime();
    }
    _scrollController.addListener(_onScroll);
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
        .channel('parent_notifications_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _loadNotifications(initial: true),
        )
        .subscribe();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('is_archived', false)
          .inFilter('target_audience', ['all', 'students_parents'])
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final fetched = (res as List)
          .map((r) => AppNotificationModel.fromJson(r as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          if (initial) _items.clear();
          _items.addAll(fetched);
          _offset += fetched.length;
          _hasMore = fetched.length == _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading parent notifications: $e');
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No notifications at this time.',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(initial: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final notification = _items[index];
          return ExpandableNotificationCard(
            notification: notification,
          );
        },
      ),
    );
  }
}
