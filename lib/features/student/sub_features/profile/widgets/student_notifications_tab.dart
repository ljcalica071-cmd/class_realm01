import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';

/// Real-Time Paginated Student Notifications Tab
/// - Only displays notifications for subjects the student is enrolled in + general broadcasts
/// - Enforces 2-line expandable notification cards with subject/section badges
/// - Adheres strictly to student-parent-ui-ux.md (maxWidth: 540, 60-30-10 palette, LucideIcons)
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
  int _currentPage = 1;
  static const int _pageSize = 10;
  static const int _fetchLimit = 200;

  Set<String> _enrolledSubjectNames = {};
  RealtimeChannel? _channel;
  RealtimeChannel? _enrollmentChannel;

  /// Sorting: true = Newest to Oldest (default), false = Oldest to Newest.
  bool _newestFirst = true;

  /// Display names of the student's enrolled subjects (for the filter dropdown).
  List<String> _subjectOptions = [];

  /// Currently selected subject filter. `null` means "All Subjects".
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadEnrolledSubjects();
    final studentId = AuthRepository.instance.currentUser?.id;
    if (studentId != null && studentId.isNotEmpty) {
      final cached =
          AppDataCache.instance.getCached<List<AppNotificationModel>>(
        'student_notifications_$studentId',
        (jsonList) => (jsonList as List)
            .map((j) => AppNotificationModel.fromJson(
                Map<String, dynamic>.from(j as Map)))
            .toList(),
      );
      if (cached != null && cached.isNotEmpty) {
        _notifications
          ..clear()
          ..addAll(cached);
        _isLoading = false;
      }
    }
    _loadNotifications(
      initial: _notifications.isEmpty,
      silent: _notifications.isNotEmpty,
    );
    _subscribeToRealtime();
    _subscribeToEnrollmentChanges();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    if (_enrollmentChannel != null) {
      Supabase.instance.client.removeChannel(_enrollmentChannel!);
    }
    super.dispose();
  }

  void _applySubjects(Iterable<String> displayNames) {
    final byKey = <String, String>{};
    for (final raw in displayNames) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      byKey.putIfAbsent(name.toLowerCase(), () => name);
    }
    final options = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _enrolledSubjectNames = byKey.keys.toSet();
      _subjectOptions = options;
      // Reset the filter if the selected subject is no longer enrolled.
      if (_selectedSubject != null &&
          !byKey.containsKey(_selectedSubject!.toLowerCase())) {
        _selectedSubject = null;
      }
    });
  }

  Future<void> _loadEnrolledSubjects() async {
    try {
      // Show cached subjects instantly, then refresh from the server so the
      // list stays in sync with any changes made by the teacher.
      final dashboard = StudentDashboardRepository.instance.currentDashboard;
      if (dashboard != null && dashboard.enrollments.isNotEmpty) {
        _applySubjects(dashboard.enrollments.map((e) => e.subjectName));
      }

      final studentId = AuthRepository.instance.currentUser?.id;
      if (studentId == null) return;

      final res = await Supabase.instance.client
          .from('student_enrollments')
          .select(
            'subject_offerings (subjects (subject_name), sections (section_name))',
          )
          .eq('student_id', studentId)
          .ilike('status', 'enrolled');

      final subjects = <String>[];
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
          subjects.add('$sName'.trim());
        }
      }

      if (subjects.isNotEmpty || _subjectOptions.isEmpty) {
        _applySubjects(subjects);
      }
    } catch (e) {
      debugPrint('Error loading enrolled subjects for student: $e');
    }
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

  /// Keeps the subject dropdown updated when the teacher enrolls/unenrolls
  /// the student or updates their subjects.
  void _subscribeToEnrollmentChanges() {
    final studentId = AuthRepository.instance.currentUser?.id;
    if (studentId == null) return;
    try {
      _enrollmentChannel = Supabase.instance.client
          .channel('student_notif_enrollments_$studentId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'student_enrollments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'student_id',
              value: studentId,
            ),
            callback: (_) => _loadEnrolledSubjects(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to enrollment changes: $e');
    }
  }

  Future<void> _loadNotifications({
    bool initial = false,
    bool silent = false,
  }) async {
    if (initial && !silent && _notifications.isEmpty) {
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

      final items = await SupabaseNotificationRepository.instance
          .getUserNotifications(user, limit: _fetchLimit);

      if (!_newestFirst) {
        items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      if (mounted) {
        setState(() {
          _notifications
            ..clear()
            ..addAll(items);
          _isLoading = false;
        });

        if (user.id.isNotEmpty) {
          AppDataCache.instance.setCache(
            'student_notifications_${user.id}',
            items.map((n) => n.toJson()).toList(),
          );
        }

        SupabaseNotificationRepository.instance.calculateUnreadCount(user);
      }
    } catch (e) {
      debugPrint('Error loading student notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Filter notifications: only show notifications for enrolled subjects + general broadcasts
  List<AppNotificationModel> get _filteredNotifications {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return [];

    return _notifications
        .where((n) {
          return SupabaseNotificationRepository.instance
              .isNotificationVisibleForUser(
                n,
                currentUser,
                handledOrEnrolledSubjects: _enrolledSubjectNames,
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

  void _toggleSort() {
    setState(() {
      _newestFirst = !_newestFirst;
      _currentPage = 1;
    });
    _loadNotifications(initial: true);
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // Sort button: Newest -> Oldest / Oldest -> Newest
          Material(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('student_notif_sort_button'),
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
          const SizedBox(width: 10),
          // Subject dropdown
          Expanded(
            child: AppFixedDropdown<String?>(
              key: const Key('student_notif_subject_dropdown'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayedNotifications = _filteredNotifications;

    if (_isLoading && _notifications.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: const ShimmerStudentNotificationsSkeleton(),
        ),
      );
    }

    final totalCount = displayedNotifications.length;
    final totalPages = max(1, (totalCount / _pageSize).ceil());
    final safePage = _currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > totalCount)
        ? totalCount
        : startIndex + _pageSize;
    final pagedItems = totalCount == 0
        ? const <AppNotificationModel>[]
        : displayedNotifications.sublist(startIndex, endIndex);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AppPullToRefresh(
          onRefresh: () => _loadNotifications(initial: true, silent: true),
          child: Column(
            children: [
              _buildFilterBar(theme, isDark, displayedNotifications),
              Expanded(
                child: displayedNotifications.isEmpty
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
                                'You are all caught up',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'There are no announcements or alerts for your enrolled subjects right now.',
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
                    : ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        children: pagedItems
                            .map(
                              (notification) => ExpandableNotificationCard(
                                notification: notification,
                                maxCollapsedLines: 2,
                              ),
                            )
                            .toList(),
                      ),
              ),
              _buildPaginationBar(
                theme: theme,
                isDark: isDark,
                totalCount: totalCount,
                startIndex: startIndex,
                endIndex: endIndex,
                safePage: safePage,
                totalPages: totalPages,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
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
    final startDisplay = totalCount == 0 ? 0 : startIndex + 1;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;

            final controls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Previous button
                InkWell(
                  onTap: safePage > 1 ? () => _goToPage(safePage - 1) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 7 : 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: safePage > 1
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                        ),
                        if (!isNarrow) ...[
                          const SizedBox(width: 3),
                          Text(
                            'Prev',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: safePage > 1
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Page indicator pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.4 : 0.25,
                      ),
                    ),
                  ),
                  child: Text(
                    '$safePage / ${max(1, totalPages)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Next button
                InkWell(
                  onTap: safePage < totalPages
                      ? () => _goToPage(safePage + 1)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 7 : 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isNarrow) ...[
                          Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: safePage < totalPages
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(width: 3),
                        ],
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: safePage < totalPages
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            final showingText = Text(
              totalCount == 0
                  ? (isNarrow ? '0 of 0' : 'Showing 0 of 0 notifications')
                  : (isNarrow
                      ? '$startDisplay–$endIndex of $totalCount'
                      : 'Showing $startDisplay–$endIndex of $totalCount notifications'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );

            if (constraints.maxWidth < 280) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  showingText,
                  const SizedBox(height: 8),
                  controls,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: showingText),
                const SizedBox(width: 8),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}
