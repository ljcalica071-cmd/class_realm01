import 'dart:async';

import 'package:flutter/material.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';

/// Real-Time Paginated Parent Notifications Tab
/// - Filter & Sorting support: Newest to Oldest / Oldest to Newest
/// - Filter by Subject dropdown (enrolled subjects of linked learners)
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
  int _currentPage = 1;
  static const int _pageSize = 10;
  static const int _fetchLimit = 200;

  List<UserModel> _linkedChildren = [];
  String? _selectedChildId; // null or child student_id
  RealtimeChannel? _channel;

  /// Sorting: true = Newest to Oldest (default), false = Oldest to Newest.
  bool _newestFirst = true;

  /// Display names of the children's enrolled subjects (for filter dropdown).
  List<String> _subjectOptions = [];

  /// Currently selected subject filter. `null` means "All Subjects".
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadLinkedChildren();
    if (widget.notifications != null && widget.notifications!.isNotEmpty) {
      _items.addAll(widget.notifications!);
      _isLoading = false;
    } else {
      final parentId = AuthRepository.instance.currentUser?.id;
      if (parentId != null && parentId.isNotEmpty) {
        final cached =
            AppDataCache.instance.getCached<List<AppNotificationModel>>(
          'parent_notifications_$parentId',
          (jsonList) => (jsonList as List)
              .map((j) => AppNotificationModel.fromJson(
                  Map<String, dynamic>.from(j as Map)))
              .toList(),
        );
        if (cached != null && cached.isNotEmpty) {
          _items
            ..clear()
            ..addAll(cached);
          _isLoading = false;
        }
      }
      _loadNotifications(initial: _items.isEmpty, silent: _items.isNotEmpty);
      _subscribeToRealtime();
    }
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
        await _loadEnrolledSubjectsForChildren(children);
      }
    } catch (e) {
      debugPrint('Error loading linked children for parent notifications: $e');
    }
  }

  Future<void> _loadEnrolledSubjectsForChildren(List<UserModel> children) async {
    if (children.isEmpty) return;
    try {
      final childIds = children.map((c) => c.id).where((id) => id.isNotEmpty).toList();
      if (childIds.isEmpty) return;

      final res = await Supabase.instance.client
          .from('student_enrollments')
          .select(
            'subject_offerings (subjects (subject_name), sections (section_name))',
          )
          .inFilter('student_id', childIds)
          .ilike('status', 'enrolled');

      final byKey = <String, String>{};
      for (final row in (res as List)) {
        final rawOffering = row['subject_offerings'];
        final Map? offering = rawOffering is Map
            ? rawOffering
            : (rawOffering is List && rawOffering.isNotEmpty
                  ? rawOffering.first as Map?
                  : null);
        final rawSub = offering?['subjects'];
        final Map? subMap = rawSub is Map
            ? rawSub
            : (rawSub is List && rawSub.isNotEmpty
                  ? rawSub.first as Map?
                  : null);
        final sName = subMap?['subject_name'] ?? offering?['subject_name'];
        if (sName != null && '$sName'.trim().isNotEmpty) {
          final trimmed = '$sName'.trim();
          byKey.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
        }
      }

      final options = byKey.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _subjectOptions = options;
          if (_selectedSubject != null &&
              !byKey.containsKey(_selectedSubject!.toLowerCase())) {
            _selectedSubject = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading subjects for parent notifications: $e');
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

  Future<void> _loadNotifications({
    bool initial = false,
    bool silent = false,
  }) async {
    if (initial && !silent && _items.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final user = AuthRepository.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final fetched = await SupabaseNotificationRepository.instance
          .getUserNotifications(user, limit: _fetchLimit);

      if (!_newestFirst) {
        fetched.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(fetched);
          _isLoading = false;
        });

        if (user.id.isNotEmpty) {
          unawaited(
            AppDataCache.instance.setCache(
              'parent_notifications_${user.id}',
              fetched.map((n) => n.toJson()).toList(),
            ),
          );
        }

        SupabaseNotificationRepository.instance.calculateUnreadCount(user);
      }
    } catch (e) {
      debugPrint('Error loading parent notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSort() {
    setState(() {
      _newestFirst = !_newestFirst;
      _currentPage = 1;
    });
    _loadNotifications(initial: true);
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

    return _items
        .where((n) {
          final childrenToCheck = specificChild != null
              ? [specificChild]
              : _linkedChildren;
          return SupabaseNotificationRepository.instance
              .isNotificationVisibleForUser(
                n,
                currentUser,
                handledOrEnrolledSubjects: _subjectOptions,
                linkedChildren: childrenToCheck,
              );
        })
        .where((n) {
          // Subject dropdown filter
          final selected = _selectedSubject?.trim().toLowerCase();
          if (selected == null || selected.isEmpty) return true;
          final haystack = '${n.title} ${n.message}'.toLowerCase();
          return haystack.contains(selected);
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayedItems = _filteredNotifications;

    if (_isLoading && _items.isEmpty) {
      return const ShimmerStudentNotificationsSkeleton();
    }

    return AppPullToRefresh(
      onRefresh: () => _loadNotifications(initial: true, silent: true),
      child: Center(
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
                        child: AppFixedDropdown<String>(
                          value: _selectedChildId ?? 'ALL',
                          isExpanded: true,
                          icon: const Icon(LucideIcons.chevronDown, size: 16),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          items: [
                            const AppDropdownItem<String>(
                              value: 'ALL',
                              label: 'All Children',
                            ),
                            ..._linkedChildren.map(
                              (c) => AppDropdownItem<String>(
                                value: c.id,
                                label: c.fullName.isNotEmpty
                                    ? c.fullName
                                    : 'Learner',
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedChildId = val;
                              _currentPage = 1;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // Filter & Sorting Bar: Sort Old/New Toggle + Subject Dropdown + Mark All Read
              _buildFilterBar(theme, isDark, displayedItems),

              // Notification List
              Expanded(
                child: displayedItems.isEmpty
                    ? AppPullToRefresh.scrollableState(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
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
                                _selectedSubject != null
                                    ? 'No Announcements for $_selectedSubject'
                                    : 'No Announcements Yet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedSubject != null
                                    ? 'No notifications matching "$_selectedSubject" for your linked learners.'
                                    : 'No notifications for your linked learners at this time.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              if (_selectedSubject != null) ...[
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedSubject = null;
                                      _currentPage = 1;
                                    });
                                  },
                                  child: const Text('Clear Filter'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final totalPages = (displayedItems.length / _pageSize)
                              .ceil();
                          final safePage = _currentPage.clamp(
                            1,
                            totalPages > 0 ? totalPages : 1,
                          );
                          final startIndex = (safePage - 1) * _pageSize;
                          final endIndex =
                              (startIndex + _pageSize > displayedItems.length)
                              ? displayedItems.length
                              : startIndex + _pageSize;
                          final pagedItems = displayedItems.sublist(
                            startIndex,
                            endIndex,
                          );

                          return ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            children: [
                              ...pagedItems.map(
                                (notification) => ExpandableNotificationCard(
                                  notification: notification,
                                  maxCollapsedLines: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildPaginationBar(
                                theme: theme,
                                isDark: isDark,
                                totalCount: displayedItems.length,
                                startIndex: startIndex,
                                endIndex: endIndex,
                                safePage: safePage,
                                totalPages: totalPages,
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    ThemeData theme,
    bool isDark,
    List<AppNotificationModel> displayedNotifications,
  ) {
    final borderColor = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.14 : 0.09,
    );
    final surface = isDark ? const Color(0xFF263040) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          // Sort button: Newest -> Oldest / Oldest -> Newest
          Material(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('parent_notif_sort_button'),
              borderRadius: BorderRadius.circular(12),
              onTap: _toggleSort,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _newestFirst
                          ? LucideIcons.arrowDownWideNarrow
                          : LucideIcons.arrowUpNarrowWide,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _newestFirst ? 'Newest' : 'Oldest',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Subject dropdown filter
          Expanded(
            child: AppFixedDropdown<String?>(
              key: const Key('parent_notif_subject_dropdown'),
              value: _selectedSubject,
              isExpanded: true,
              icon: Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              items: [
                const AppDropdownItem<String?>(
                  value: null,
                  label: 'All Subjects',
                ),
                ..._subjectOptions.map(
                  (s) => AppDropdownItem<String?>(
                    value: s,
                    label: s,
                  ),
                ),
              ],
              onChanged: (val) => setState(() {
                _selectedSubject = val;
                _currentPage = 1;
              }),
            ),
          ),

          // Mark All Read Button
          Builder(
            builder: (btnCtx) {
              final currentUserId =
                  AuthRepository.instance.currentUser?.id ?? '';
              final unreadInList = displayedNotifications
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
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: 'Mark all as read',
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.checkCheck, size: 14),
                    label: Text(
                      '${unreadInList.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  Widget _buildPaginationBar({
    required ThemeData theme,
    required bool isDark,
    required int totalCount,
    required int startIndex,
    required int endIndex,
    required int safePage,
    required int totalPages,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            totalCount == 0
                ? 'Showing 0 of 0 notifications'
                : 'Showing ${startIndex + 1}–$endIndex of $totalCount notifications',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: safePage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Previous', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.2 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.4 : 0.2,
                    ),
                  ),
                ),
                child: Text(
                  '$safePage of ${totalPages > 0 ? totalPages : 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: safePage < totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Next', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
