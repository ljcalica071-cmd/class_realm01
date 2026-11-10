import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/models/academic_models.dart';
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

  @override
  void initState() {
    super.initState();
    _loadEnrolledSubjects();
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

  Future<void> _loadEnrolledSubjects() async {
    try {
      final dashboard = StudentDashboardRepository.instance.currentDashboard;
      if (dashboard != null && dashboard.enrollments.isNotEmpty) {
        if (mounted) {
          setState(() {
            _enrolledSubjectNames = dashboard.enrollments
                .map((e) => e.subjectName.trim().toLowerCase())
                .where((name) => name.isNotEmpty)
                .toSet();
          });
        }
        return;
      }

      final studentId = AuthRepository.instance.currentUser?.id;
      if (studentId == null) return;

      final res = await Supabase.instance.client
          .from('student_enrollments')
          .select('subject_offerings (subject_name, section_name)')
          .eq('student_id', studentId)
          .eq('status', 'enrolled');

      final subjects = <String>{};
      for (final row in (res as List)) {
        final offering = row['subject_offerings'] as Map<String, dynamic>?;
        if (offering != null) {
          final sName = offering['subject_name']?.toString().trim().toLowerCase();
          if (sName != null && sName.isNotEmpty) {
            subjects.add(sName);
          }
        }
      }

      if (mounted) {
        setState(() {
          _enrolledSubjectNames = subjects;
        });
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

  /// Filter notifications: only show notifications for enrolled subjects + general broadcasts
  List<AppNotificationModel> get _filteredNotifications {
    final currentStudentName = AuthRepository.instance.currentUser?.fullName.toLowerCase() ?? '';

    return _notifications.where((n) {
      final title = n.title.toLowerCase();
      final body = n.message.toLowerCase();

      // Extract subject and section if present
      final regex = RegExp(r'in\s+([A-Za-z0-9\s/&_-]+?)\s*\(([^)]+)\)', caseSensitive: false);
      final match = regex.firstMatch('${n.title} ${n.message}');

      if (match != null) {
        final notifSubject = match.group(1)?.trim().toLowerCase() ?? '';
        // If it's a personalized absence warning for another student, hide it
        if (body.contains('recorded absences') || body.contains('attendance check-in')) {
          if (currentStudentName.isNotEmpty && !body.contains(currentStudentName) && !title.contains(currentStudentName)) {
            return false;
          }
        }

        // If enrolled subjects are known and this notification references a non-general subject the student isn't in
        if (_enrolledSubjectNames.isNotEmpty &&
            notifSubject.isNotEmpty &&
            !notifSubject.contains('general') &&
            !_enrolledSubjectNames.any((enrolled) => notifSubject.contains(enrolled) || enrolled.contains(notifSubject))) {
          return false;
        }
      }

      return true;
    }).toList();
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
        child: AppPullToRefresh(
          onRefresh: () => _loadNotifications(initial: true, silent: true),
          child: displayedNotifications.isEmpty
              ? AppPullToRefresh.scrollableState(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF263040) : Colors.white,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: displayedNotifications.length + (_hasMore ? 1 : 0),
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
    );
  }
}
