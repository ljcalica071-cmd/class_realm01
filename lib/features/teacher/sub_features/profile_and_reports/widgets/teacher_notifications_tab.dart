import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

/// Real-Time Paginated Teacher Notifications Tab
/// - Search bar & handled subjects dropdown filter
/// - Loads items with pagination & real-time Supabase push updates
/// - Soft-delete resilience & 2-line expandable notification cards
class TeacherNotificationsTab extends StatefulWidget {
  const TeacherNotificationsTab({super.key});

  @override
  State<TeacherNotificationsTab> createState() =>
      _TeacherNotificationsTabState();
}

class _TeacherNotificationsTabState extends State<TeacherNotificationsTab> {
  final List<AppNotificationModel> _notifications = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;

  // Handled subjects for teacher
  List<Map<String, dynamic>> _teacherSubjects = [];
  String? _selectedSubjectFilter; // null or 'ALL' or specific subject_name
  String _searchQuery = '';

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadTeacherSubjects();
    _loadNotifications(initial: true);
    _scrollController.addListener(_onScroll);
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _loadTeacherSubjects() async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) return;

    final cached = SubjectRepository.instance.getCachedTeacherSubjects(teacherId);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _teacherSubjects = cached;
      });
    }

    try {
      final fetched = await SubjectRepository.instance.getTeacherSubjects(teacherId);
      if (mounted) {
        setState(() {
          _teacherSubjects = fetched;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher subjects: $e');
    }
  }

  void _subscribeToRealtime() {
    _channel = Supabase.instance.client
        .channel('teacher_notifications_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            _loadNotifications(initial: true);
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
          .inFilter('target_audience', ['all', 'teachers'])
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final items = (res as List)
          .map((r) => AppNotificationModel.fromJson(r as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          if (initial) {
            _notifications.clear();
          }
          _notifications.addAll(items);
          _offset += items.length;
          _hasMore = items.length == _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Distinct list of subjects handled by this teacher
  List<String> get _distinctHandledSubjects {
    final set = <String>{};
    for (final s in _teacherSubjects) {
      final name = s['subject_name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        set.add(name);
      }
    }
    return set.toList()..sort();
  }

  /// Filter notifications:
  /// 1. Only show notifications relevant to handled subjects (or general all-audience broadcasts)
  /// 2. Apply search query
  /// 3. Apply subject filter dropdown
  List<AppNotificationModel> get _filteredNotifications {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null) {
      if (currentUser.isArchived ||
          currentUser.status == AccountStatus.archived ||
          currentUser.status == AccountStatus.deactivated) {
        return [];
      }
      final isEligible = currentUser.status == AccountStatus.active ||
          currentUser.status == AccountStatus.pendingFirstLogin;
      if (!isEligible) {
        return [];
      }
    }

    final handledSubjectNames = _distinctHandledSubjects.map((s) => s.toLowerCase()).toSet();

    return _notifications.where((n) {
      // Exclude announcements broadcasted before the teacher account existed
      if (currentUser?.createdAt != null && n.type.toLowerCase() == 'announcement') {
        if (n.timestamp.isBefore(currentUser!.createdAt!)) {
          return false;
        }
      }

      final title = n.title.toLowerCase();
      final body = n.message.toLowerCase();
      final fullText = '$title $body';

      // If notification has a specific subject mentioned in message/title, ensure it matches handled subjects
      // e.g. "Aguilar, Fiona has reached 3 recorded absences in Class (General)..."
      final regex = RegExp(r'in\s+([A-Za-z0-9\s/&_-]+?)\s*\(([^)]+)\)', caseSensitive: false);
      final match = regex.firstMatch('${n.title} ${n.message}');
      if (match != null) {
        final notifSubject = match.group(1)?.trim().toLowerCase() ?? '';
        // If teacher has handled subjects and this notification is about a subject they DON'T teach, hide it
        if (handledSubjectNames.isNotEmpty &&
            notifSubject.isNotEmpty &&
            !notifSubject.contains('general') &&
            !handledSubjectNames.any((h) => notifSubject.contains(h) || h.contains(notifSubject))) {
          return false;
        }
      }

      // Subject Filter Dropdown
      if (_selectedSubjectFilter != null && _selectedSubjectFilter != 'ALL') {
        final targetSubj = _selectedSubjectFilter!.toLowerCase();
        final matchesSubject = fullText.contains(targetSubj);
        if (!matchesSubject) return false;
      }

      // Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesQuery = title.contains(q) || body.contains(q);
        if (!matchesQuery) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayedNotifications = _filteredNotifications;

    return Column(
      children: [
        // Filter & Search Controls Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
              // Search Input
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search notifications...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 14),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surface.withValues(alpha: 0.8)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Subject Dropdown Filter
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                child: SizedBox(
                  height: 40,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubjectFilter ?? 'ALL',
                    icon: const Icon(LucideIcons.chevronDown, size: 16),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    dropdownColor: theme.colorScheme.surface,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surface.withValues(alpha: 0.8)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'ALL',
                        child: Text(
                          'All Handled Subjects',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ..._distinctHandledSubjects.map(
                        (sub) => DropdownMenuItem<String>(
                          value: sub,
                          child: Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSubjectFilter = val;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

        // List Area
        Expanded(
          child: _isLoading
              ? ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const ShimmerBroadcastItem(),
                )
              : displayedNotifications.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.bellOff,
                                size: 30,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _searchQuery.isNotEmpty || (_selectedSubjectFilter != null && _selectedSubjectFilter != 'ALL')
                                  ? 'No matching notifications'
                                  : 'You\'re all caught up!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty || (_selectedSubjectFilter != null && _selectedSubjectFilter != 'ALL')
                                  ? 'Try adjusting your search terms or subject filter.'
                                  : 'There are no new alerts or announcements at the moment.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadNotifications(initial: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        itemCount: displayedNotifications.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == displayedNotifications.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: ShimmerBroadcastItem(),
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
    );
  }
}
