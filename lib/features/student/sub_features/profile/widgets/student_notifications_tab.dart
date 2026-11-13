import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
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
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 15;

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
    _loadNotifications(initial: true);
    _scrollController.addListener(_onScroll);
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
          .select('subject_offerings (subject_name, section_name)')
          .eq('student_id', studentId)
          .eq('status', 'enrolled');

      final subjects = <String>[];
      for (final row in (res as List)) {
        final rawOffering = row['subject_offerings'];
        final Map? offering = rawOffering is Map
            ? rawOffering
            : (rawOffering is List && rawOffering.isNotEmpty
                  ? rawOffering.first as Map?
                  : null);
        final sName = offering?['subject_name'];
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
          .order('created_at', ascending: !_newestFirst)
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

  /// Filter notifications: only show notifications for enrolled subjects + general broadcasts
  List<AppNotificationModel> get _filteredNotifications {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null) {
      if (currentUser.isArchived ||
          currentUser.status == AccountStatus.archived ||
          currentUser.status == AccountStatus.deactivated) {
        return [];
      }
      final isEligible =
          currentUser.status == AccountStatus.active ||
          currentUser.status == AccountStatus.pendingFirstLogin;
      if (!isEligible) {
        return [];
      }
    }

    final currentStudentName = currentUser?.fullName.toLowerCase() ?? '';

    return _notifications
        .where((n) {
          // Exclude announcements broadcasted before the student account existed
          if (currentUser?.createdAt != null &&
              n.type.toLowerCase() == 'announcement') {
            if (n.timestamp.isBefore(currentUser!.createdAt!)) {
              return false;
            }
          }

          final title = n.title.toLowerCase();
          final body = n.message.toLowerCase();

          // Extract subject and section if present
          final regex = RegExp(
            r'in\s+([A-Za-z0-9\s/&_-]+?)\s*\(([^)]+)\)',
            caseSensitive: false,
          );
          final match = regex.firstMatch('${n.title} ${n.message}');

          if (match != null) {
            final notifSubject = match.group(1)?.trim().toLowerCase() ?? '';
            // If it's a personalized absence warning for another student, hide it
            if (body.contains('recorded absences') ||
                body.contains('attendance check-in')) {
              if (currentStudentName.isNotEmpty &&
                  !body.contains(currentStudentName) &&
                  !title.contains(currentStudentName)) {
                return false;
              }
            }

            // If enrolled subjects are known and this notification references a non-general subject the student isn't in
            if (_enrolledSubjectNames.isNotEmpty &&
                notifSubject.isNotEmpty &&
                !notifSubject.contains('general') &&
                !_enrolledSubjectNames.any(
                  (enrolled) =>
                      notifSubject.contains(enrolled) ||
                      enrolled.contains(notifSubject),
                )) {
              return false;
            }
          }

          return true;
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
    setState(() => _newestFirst = !_newestFirst);
    _loadNotifications(initial: true);
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
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
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  key: const Key('student_notif_subject_dropdown'),
                  value: _selectedSubject,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
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
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'All Subjects',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._subjectOptions.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedSubject = val),
                ),
              ),
            ),
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
            _buildFilterBar(theme, isDark),
            Expanded(
              child: AppPullToRefresh(
                onRefresh: () =>
                    _loadNotifications(initial: true, silent: true),
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
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        itemCount:
                            displayedNotifications.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == displayedNotifications.length) {
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
                          final notification = displayedNotifications[index];
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
