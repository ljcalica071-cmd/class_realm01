import 'package:class_realm/core/utils/search_utils.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
import 'package:class_realm/shared/widgets/app_top_toast.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

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
  int _currentPage = 1;
  static const int _pageSize = 10;
  static const int _fetchLimit = 200;

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

    final cached = SubjectRepository.instance.getCachedTeacherSubjects(
      teacherId,
    );
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _teacherSubjects = cached;
      });
    }

    try {
      final fetched = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_recipients',
          callback: (payload) {
            if (mounted) setState(() {});
          },
        )
        .subscribe();
  }

  Future<void> _loadNotifications({bool initial = false}) async {
    if (initial && _notifications.isEmpty) {
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

      if (mounted) {
        setState(() {
          _notifications
            ..clear()
            ..addAll(items);
          _isLoading = false;
        });

        SupabaseNotificationRepository.instance.calculateUnreadCount(user);
      }
    } catch (e) {
      debugPrint('Error loading teacher notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    if (currentUser == null) return [];

    return _notifications.where((n) {
      if (!SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
        n,
        currentUser,
        handledOrEnrolledSubjects: _distinctHandledSubjects,
      )) {
        return false;
      }

      // Subject Filter Dropdown
      if (_selectedSubjectFilter != null && _selectedSubjectFilter != 'ALL') {
        final targetSubj = _selectedSubjectFilter!.toLowerCase();
        final matchesSubject = '${n.title} ${n.message}'.toLowerCase().contains(
          targetSubj,
        );
        if (!matchesSubject) return false;
      }

      // Search Query
      if (!SearchUtils.isEmpty(_searchQuery)) {
        final matchesQuery = SearchUtils.matches(
          _searchQuery,
          names: [n.title],
          loose: [n.message],
        );
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
                  constraints: const BoxConstraints(
                    minWidth: 240,
                    maxWidth: 360,
                  ),
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 1;
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search notifications...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 14),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _currentPage = 1;
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
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
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 280,
                  ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
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
                          _currentPage = 1;
                        });
                      },
                    ),
                  ),
                ),
                // Mark All As Read Button
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

                    return OutlinedButton.icon(
                      icon: const Icon(LucideIcons.checkCheck, size: 15),
                      label: Text(
                        'Mark all as read (${unreadInList.length})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                    );
                  },
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 48,
                      horizontal: 32,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
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
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
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
                          _searchQuery.isNotEmpty ||
                                  (_selectedSubjectFilter != null &&
                                      _selectedSubjectFilter != 'ALL')
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
                          _searchQuery.isNotEmpty ||
                                  (_selectedSubjectFilter != null &&
                                      _selectedSubjectFilter != 'ALL')
                              ? 'Try adjusting your search terms or subject filter.'
                              : 'There are no new alerts or announcements at the moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final totalPages =
                        (displayedNotifications.length / _pageSize).ceil();
                    final safePage = _currentPage.clamp(
                      1,
                      totalPages > 0 ? totalPages : 1,
                    );
                    final startIndex = (safePage - 1) * _pageSize;
                    final endIndex =
                        (startIndex + _pageSize > displayedNotifications.length)
                        ? displayedNotifications.length
                        : startIndex + _pageSize;
                    final pagedItems = displayedNotifications.sublist(
                      startIndex,
                      endIndex,
                    );

                    return RefreshIndicator(
                      onRefresh: () => _loadNotifications(initial: true),
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
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
                            totalCount: displayedNotifications.length,
                            startIndex: startIndex,
                            endIndex: endIndex,
                            safePage: safePage,
                            totalPages: totalPages,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
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
            'Showing ${totalCount == 0 ? 0 : startIndex + 1} to $endIndex of $totalCount entries',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          if (totalPages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPageButton(
                  'First',
                  () => setState(() => _currentPage = 1),
                  safePage > 1,
                ),
                _buildPageButton(
                  '<',
                  () => setState(() => _currentPage = safePage - 1),
                  safePage > 1,
                ),
                for (int p = 1; p <= totalPages; p++)
                  if (p >= safePage - 2 && p <= safePage + 2)
                    _buildPageButton(
                      p.toString(),
                      () => setState(() => _currentPage = p),
                      true,
                      isActive: p == safePage,
                    ),
                _buildPageButton(
                  '>',
                  () => setState(() => _currentPage = safePage + 1),
                  safePage < totalPages,
                ),
                _buildPageButton(
                  'Last',
                  () => setState(() => _currentPage = totalPages),
                  safePage < totalPages,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPageButton(
    String label,
    VoidCallback onTap,
    bool enabled, {
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled && !isActive ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? theme.colorScheme.onPrimary
                : enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
