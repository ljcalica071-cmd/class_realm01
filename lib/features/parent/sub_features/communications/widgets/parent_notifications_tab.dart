import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';
import 'package:class_realm/shared/widgets/app_top_toast.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';

/// Real-Time Paginated Parent Notifications Tab
/// - Filters notifications so parents only see notifications for their linked children and their children's enrolled subjects (+ general announcements)
/// - Child selector dropdown when parent has multiple linked children
/// - Enforces 2-line expandable notification cards with subject/section badges
/// - Adheres strictly to student-parent-ui-ux.md (maxWidth: 540, 60-30-10 palette, LucideIcons)
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
  static const int _pageSize = 15;

  List<UserModel> _linkedChildren = [];
  String? _selectedChildId; // null or child student_id
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadLinkedChildren();
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

  Future<void> _loadLinkedChildren() async {
    final parentId = AuthRepository.instance.currentUser?.id;
    if (parentId == null) return;

    try {
      final children = await SupabaseParentRepository()
          .getLinkedStudentsForParent(parentId);
      if (mounted) {
        setState(() {
          _linkedChildren = children;
        });
      }
    } catch (e) {
      debugPrint('Error loading linked children for parent notifications: $e');
    }
  }

  void _subscribeToRealtime() {
    _channel = Supabase.instance.client
        .channel('parent_notifications_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _loadNotifications(initial: true, silent: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_recipients',
          callback: (_) {
            if (mounted) setState(() {});
          },
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
      final user = AuthRepository.instance.currentUser;
      if (user != null) {
        await SupabaseNotificationRepository.instance.getReadNotificationIds(
          user.id,
        );
      }

      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('is_archived', false)
          .inFilter('target_audience', ['all', 'parents', 'students_parents'])
          .order('created_at', ascending: false)
          .range(targetOffset, targetOffset + _pageSize - 1);

      final fetched = (res as List)
          .map((r) => AppNotificationModel.fromJson(r as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          if (initial) {
            _items
              ..clear()
              ..addAll(fetched);
            _offset = fetched.length;
          } else {
            _items.addAll(fetched);
            _offset += fetched.length;
          }
          _hasMore = fetched.length == _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });

        if (user != null) {
          SupabaseNotificationRepository.instance.calculateUnreadCount(user);
        }
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

  /// Filter notifications: only show notifications relevant to linked children (+ general announcements)
  List<AppNotificationModel> get _filteredNotifications {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return [];

    UserModel? specificChild;
    if (_selectedChildId != null && _selectedChildId != 'ALL') {
      specificChild = _linkedChildren.firstWhere(
        (c) => c.id == _selectedChildId,
        orElse: () => _linkedChildren.first,
      );
    }

    return _items.where((n) {
      final childrenToCheck = specificChild != null
          ? [specificChild]
          : _linkedChildren;
      return SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(
            n,
            currentUser,
            linkedChildren: childrenToCheck,
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayedItems = _filteredNotifications;

    if (_isLoading && _items.isEmpty) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: theme.colorScheme.primary,
          size: 40,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          children: [
            // Child switcher if multiple children exist
            if (_linkedChildren.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.users,
                      size: 15,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedChildId ?? 'ALL',
                        icon: const Icon(LucideIcons.chevronDown, size: 16),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        dropdownColor: isDark
                            ? const Color(0xFF263040)
                            : Colors.white,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'ALL',
                            child: Text('All Children'),
                          ),
                          ..._linkedChildren.map(
                            (c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(
                                c.fullName.isNotEmpty ? c.fullName : 'Learner',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedChildId = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Mark All As Read Button
            Builder(
              builder: (btnCtx) {
                final currentUserId =
                    AuthRepository.instance.currentUser?.id ?? '';
                final unreadInList = displayedItems
                    .where(
                      (n) => !LocalStorageService.isNotificationRead(
                        currentUserId,
                        n.id,
                      ),
                    )
                    .map((n) => n.id)
                    .toList();
                if (unreadInList.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.checkCheck, size: 14),
                      label: Text(
                        'Mark all as read (${unreadInList.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final user = AuthRepository.instance.currentUser;
                        if (user != null) {
                          await SupabaseNotificationRepository.instance
                              .markAllAsRead(user.id, unreadInList);
                          await SupabaseNotificationRepository.instance
                              .calculateUnreadCount(user);
                          if (btnCtx.mounted) {
                            AppTopToast.success(
                              btnCtx,
                              'All notifications marked as read.',
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),

            // Notification List
            Expanded(
              child: AppPullToRefresh(
                onRefresh: () =>
                    _loadNotifications(initial: true, silent: true),
                child: displayedItems.isEmpty
                    ? AppPullToRefresh.scrollableState(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF263040)
                                : Colors.white,
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
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: isDark ? 0.18 : 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.bellOff,
                                  size: 26,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Announcements Yet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No notifications for your linked learners at this time.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: displayedItems.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == displayedItems.length) {
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
                          final notification = displayedItems[index];
                          return ExpandableNotificationCard(
                            notification: notification,
                            maxCollapsedLines: 2,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
