import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/models/admin_portal_models.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminActivityAnalyticsTab extends StatefulWidget {
  const AdminActivityAnalyticsTab({super.key});

  @override
  State<AdminActivityAnalyticsTab> createState() =>
      _AdminActivityAnalyticsTabState();
}

class _AdminActivityAnalyticsTabState extends State<AdminActivityAnalyticsTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  bool _hasInitialLoaded = false;
  bool _isSwitchingFilter = false;
  String _activeFilter = 'today'; // 'today', 'week', 'custom', 'all'
  DateTime? _selectedCustomDate;
  int _currentHistoryPage = 1;
  static const int _historyItemsPerPage = 10;

  List<UserSessionLog> _sessionLogs = [];
  List<TeacherWorkloadSummary> _workloadSummaries = [];

  // Local memory cache per filter to avoid re-fetching and eliminate loading flicker
  final Map<String, List<UserSessionLog>> _sessionLogsCache = {};
  final Map<String, List<TeacherWorkloadSummary>> _workloadCache = {};

  // 1-second ticker using ValueNotifier to isolate real-time duration updates without full-tree rebuilds
  late final ValueNotifier<DateTime> _tickerNotifier;
  Timer? _oneSecondTimer;

  // Realtime debounce buffer (5-second throttle for heavy teacher concurrency)
  RealtimeChannel? _realtimeChannel;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tickerNotifier = ValueNotifier<DateTime>(DateTime.now());
    _startTicker();
    _restoreCachedData(_getCacheKey());
    _loadData();
    _subscribeToSessionRealtime();
  }

  @override
  void dispose() {
    _oneSecondTimer?.cancel();
    _debounceTimer?.cancel();
    _tickerNotifier.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _startTicker() {
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickerNotifier.value = DateTime.now();
    });
  }

  void _subscribeToSessionRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin_activity_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_session_logs',
          callback: (_) {
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(seconds: 5), () {
              _loadData(isSilent: true);
            });
          },
        )
        .subscribe();
  }

  String _getCacheKey() {
    if (_activeFilter == 'custom' && _selectedCustomDate != null) {
      final d = _selectedCustomDate!;
      return 'custom_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    return _activeFilter;
  }

  String _persistentCacheKey(String filterKey) {
    final adminId = AuthRepository.instance.currentUser?.id ?? 'unknown';
    return 'admin_activity_${adminId}_$filterKey';
  }

  bool _restoreCachedData(String filterKey) {
    try {
      final cached = AppDataCache.instance.getCached<Map<String, dynamic>>(
        _persistentCacheKey(filterKey),
        (json) => Map<String, dynamic>.from(json as Map),
      );
      if (cached == null) return false;

      final logs = (cached['logs'] as List)
          .map(
            (entry) => UserSessionLog.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
      final workloads = (cached['workloads'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .map(
            (entry) => TeacherWorkloadSummary(
              teacherId: entry['teacher_id']?.toString() ?? '',
              teacherName: entry['teacher_name']?.toString() ?? 'Teacher',
              totalSubjectsCount:
                  (entry['total_subjects_count'] as num?)?.toInt() ?? 0,
              totalSectionsCount:
                  (entry['total_sections_count'] as num?)?.toInt() ?? 0,
              isActiveNow: entry['is_active_now'] == true,
              todayDurationSeconds:
                  (entry['today_duration_seconds'] as num?)?.toInt() ?? 0,
              weekDurationSeconds:
                  (entry['week_duration_seconds'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();

      _sessionLogsCache[filterKey] = logs;
      _workloadCache[filterKey] = workloads;
      _sessionLogs = logs;
      _workloadSummaries = workloads;
      _hasInitialLoaded = true;
      return true;
    } catch (error) {
      debugPrint('Admin activity cache read notice: $error');
      return false;
    }
  }

  Future<void> _loadData({
    bool isSilent = false,
    bool isFilterSwitch = false,
  }) async {
    final cacheKey = _getCacheKey();

    if (isFilterSwitch && !_sessionLogsCache.containsKey(cacheKey)) {
      _restoreCachedData(cacheKey);
    }

    // If cached and switching filters, immediately display cached data with zero latency
    if (isFilterSwitch && _sessionLogsCache.containsKey(cacheKey)) {
      setState(() {
        _currentHistoryPage = 1;
        _sessionLogs = _sessionLogsCache[cacheKey]!;
        if (_workloadCache.containsKey(cacheKey)) {
          _workloadSummaries = _workloadCache[cacheKey]!;
        }
        _isSwitchingFilter = false;
      });
      // Fetch in background silently to verify sync
      isSilent = true;
    } else if (isFilterSwitch) {
      setState(() {
        _currentHistoryPage = 1;
        _isSwitchingFilter = true;
      });
    }

    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    if (_activeFilter == 'today') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day);
    } else if (_activeFilter == 'week') {
      // Monday of current week
      startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      endDate = DateTime(now.year, now.month, now.day);
    } else if (_activeFilter == 'custom' && _selectedCustomDate != null) {
      final d = _selectedCustomDate!;
      startDate = DateTime(d.year, d.month, d.day);
      endDate = DateTime(d.year, d.month, d.day);
    }

    try {
      final activeSy = await AdminRepository.instance.getActiveSchoolYear();
      final syId = activeSy?.id ?? '';

      final logs = await AdminRepository.instance.getTeacherSessionLogs(
        startDate: startDate,
        endDate: endDate,
      );
      final workloads = await AdminRepository.instance
          .getTeacherWorkloadSummaries(syId);

      _sessionLogsCache[cacheKey] = logs;
      _workloadCache[cacheKey] = workloads;
      unawaited(
        AppDataCache.instance.setCache(_persistentCacheKey(cacheKey), {
          'logs': logs.map((log) {
            return {...log.toJson(), 'teacher_name': log.teacherName};
          }).toList(),
          'workloads': workloads.map((summary) {
            return {
              'teacher_id': summary.teacherId,
              'teacher_name': summary.teacherName,
              'total_subjects_count': summary.totalSubjectsCount,
              'total_sections_count': summary.totalSectionsCount,
              'is_active_now': summary.isActiveNow,
              'today_duration_seconds': summary.todayDurationSeconds,
              'week_duration_seconds': summary.weekDurationSeconds,
            };
          }).toList(),
        }),
      );

      if (mounted) {
        setState(() {
          _sessionLogs = logs;
          _workloadSummaries = workloads;
          _hasInitialLoaded = true;
          _isSwitchingFilter = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasInitialLoaded = true;
          _isSwitchingFilter = false;
        });
      }
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = DateTime(2026, 1, 1);

    // Front-end constraint: Future dates are strictly disabled by lastDate: today
    final picked = await showAppDatePickerDialog(
      context,
      initialDate: _selectedCustomDate ?? today,
      firstDate: minDate,
      lastDate: today,
      title: 'Select Activity Date',
      icon: LucideIcons.calendar,
      showAge: false,
    );

    if (picked == null) return;

    // Strict validation: No future dates allowed
    if (picked.isAfter(today)) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Invalid Date',
          message: 'Future dates cannot be selected for activity analytics.',
        );
      }
      return;
    }

    // Strict validation: Year 2025 and below are blocked
    if (picked.year < 2026) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Invalid Date',
          message: 'Teacher activity records start from the year 2026.',
        );
      }
      return;
    }

    setState(() {
      _activeFilter = 'custom';
      _selectedCustomDate = picked;
    });

    _loadData(isFilterSwitch: true);
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second $ampm';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatHumanReadableTotal(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Initial load: show high-polish shimmer skeleton only on very first boot
    if (!_hasInitialLoaded &&
        _sessionLogs.isEmpty &&
        _workloadSummaries.isEmpty) {
      return _buildSkeletonLoading(context, isDark);
    }

    final activeNowCount = _sessionLogs
        .where((s) => s.isActive)
        .map((s) => s.userId)
        .toSet()
        .length;
    final totalTrackedTeachers = _workloadSummaries.length;
    final totalDurationSeconds = _sessionLogs.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Filter Bar
              _buildHeaderAndFilters(context, isDark),
              const SizedBox(height: 22),

              // KPI Metric Cards
              _buildMetricCardsRow(
                context,
                isDark,
                activeNowCount,
                totalTrackedTeachers,
                totalDurationSeconds,
              ),
              const SizedBox(height: 24),

              // Visual Analytics Charts Row (Curve Chart & Donut Chart - inspired by Pic 4)
              _buildAnalyticsChartsRow(
                context,
                isDark,
                activeNowCount,
                totalTrackedTeachers,
              ),
              const SizedBox(height: 28),

              // Teacher Workload & Total Usage Summary Cards
              _buildTeacherWorkloadSection(context, isDark),
              const SizedBox(height: 28),

              // Live Teacher Session Logs Table
              _buildSessionLogsSection(context, isDark),
            ],
          ),
        ),

        // Subtle top progress bar when switching filters (No screen flash / destruction)
        if (_isSwitchingFilter)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================================
  // Header and Filter Controls
  // =========================================================================
  Widget _buildHeaderAndFilters(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    String customDateLabel = 'Select Date';
    if (_selectedCustomDate != null) {
      final d = _selectedCustomDate!;
      customDateLabel =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.chartColumn,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Teacher Activity & Analytics Hub',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Track how long teachers use the system and view their class workloads.',
              style: TextStyle(
                fontSize: 13.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        );

        final filterBar = Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildFilterButton('Today', 'today'),
              _buildFilterButton('This Week', 'week'),
              _buildDateFilterButton(customDateLabel, 'custom'),
              _buildFilterButton('All Records', 'all'),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [headerText, const SizedBox(height: 16), filterBar],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: headerText),
            const SizedBox(width: 16),
            filterBar,
          ],
        );
      },
    );
  }

  Widget _buildFilterButton(String label, String key) {
    final isSelected = _activeFilter == key;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        if (_activeFilter == key) return;
        setState(() => _activeFilter = key);
        _loadData(isFilterSwitch: true);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterButton(String label, String key) {
    final isSelected = _activeFilter == key;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: _pickCustomDate,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Overview KPI Metric Cards
  // =========================================================================
  Widget _buildMetricCardsRow(
    BuildContext context,
    bool isDark,
    int activeNowCount,
    int totalTrackedTeachers,
    int totalDurationSeconds,
  ) {
    final theme = Theme.of(context);

    String filterSubtitle;
    if (_activeFilter == 'today') {
      filterSubtitle = 'Recorded today';
    } else if (_activeFilter == 'week') {
      filterSubtitle = 'This week (Mon - Sun)';
    } else if (_activeFilter == 'custom' && _selectedCustomDate != null) {
      filterSubtitle = 'Date: ${_formatDate(_selectedCustomDate!)}';
    } else {
      filterSubtitle = 'All recorded sessions';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Active Teachers Now',
                value: '$activeNowCount Online',
                icon: LucideIcons.radio,
                color: AppTheme.catGreen,
                subtitle: 'Currently logged in',
                isLivePulse: activeNowCount > 0,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Total Teachers Monitored',
                value: '$totalTrackedTeachers Faculty',
                icon: LucideIcons.users,
                color: theme.colorScheme.primary,
                subtitle: 'Assigned teachers',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Total Usage Duration',
                value: _formatHumanReadableTotal(totalDurationSeconds),
                icon: LucideIcons.clock,
                color: const Color(0xFF0284C7),
                subtitle: filterSubtitle,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool isLivePulse = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (isLivePulse)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.catGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Visual Analytics Charts Row (Curve Chart & Donut Chart - inspired by Pic 4)
  // =========================================================================
  Widget _buildAnalyticsChartsRow(
    BuildContext context,
    bool isDark,
    int activeNowCount,
    int totalTrackedTeachers,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStack = constraints.maxWidth < 950;

        if (isStack) {
          return Column(
            children: [
              _buildUsageCurveChartCard(context, isDark),
              const SizedBox(height: 16),
              _buildActivityDonutChartCard(
                context,
                isDark,
                activeNowCount,
                totalTrackedTeachers,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _buildUsageCurveChartCard(context, isDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: _buildActivityDonutChartCard(
                context,
                isDark,
                activeNowCount,
                totalTrackedTeachers,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsageCurveChartCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    // Prepare chart data points based on filter
    final points = _generateChartData();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher System Usage Over Time',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _activeFilter == 'week'
                        ? 'Daily hours spent by teachers using the system this week'
                        : (_activeFilter == 'custom' &&
                                  _selectedCustomDate != null
                              ? 'Hourly hours spent by teachers on ${_formatDate(_selectedCustomDate!)}'
                              : 'Hourly hours spent by teachers using the system today'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.catGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.catGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Real-time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.catGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Curve Chart Painter
          SizedBox(
            height: 190,
            child: _TeacherActivityCurveChart(
              points: points,
              isDark: isDark,
              lineColor: AppTheme.catGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDonutChartCard(
    BuildContext context,
    bool isDark,
    int activeNowCount,
    int totalTrackedTeachers,
  ) {
    final theme = Theme.of(context);

    // Calculate distribution
    final completedSessionsCount = _sessionLogs
        .where((s) => !s.isActive)
        .map((s) => s.userId)
        .toSet()
        .length;
    final totalActiveToday = activeNowCount + completedSessionsCount;
    final idleCount = math.max(0, totalTrackedTeachers - totalActiveToday);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teacher Online Status',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Current teacher login status and system usage',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),

          // Donut Chart + Center Counter
          SizedBox(
            height: 190,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: _TeacherActivityDonutPainter(
                          activeNowCount: activeNowCount,
                          idleCount: idleCount,
                          total: math.max(1, totalTrackedTeachers),
                          isDark: isDark,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalTrackedTeachers',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Teachers',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Donut Legend
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDonutLegendItem(
                        label: 'Online Now',
                        count: activeNowCount,
                        color: AppTheme.catGreen,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildDonutLegendItem(
                        label: 'Offline',
                        count: idleCount,
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFCBD5E1),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendItem({
    required String label,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // Chart Data Generation
  // =========================================================================
  List<_ChartPoint> _generateChartData() {
    if (_activeFilter == 'week') {
      // Monday through Sunday
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final values = List.filled(7, 0.0);

      for (final log in _sessionLogs) {
        final weekdayIdx = log.sessionDate.weekday - 1;
        if (weekdayIdx >= 0 && weekdayIdx < 7) {
          values[weekdayIdx] += (log.durationSeconds / 3600.0);
        }
      }

      return List.generate(7, (i) => _ChartPoint(days[i], values[i]));
    }

    // Default to Hourly buckets (8 AM to 6 PM)
    final hours = ['8 AM', '10 AM', '12 PM', '2 PM', '4 PM', '6 PM'];
    final hourBuckets = [8, 10, 12, 14, 16, 18];
    final values = List.filled(6, 0.0);

    for (final log in _sessionLogs) {
      final h = log.loginAt.hour;
      for (int i = 0; i < hourBuckets.length; i++) {
        if (h >= hourBuckets[i] &&
            (i == hourBuckets.length - 1 || h < hourBuckets[i + 1])) {
          values[i] += (log.durationSeconds / 3600.0);
          break;
        }
      }
    }

    return List.generate(6, (i) => _ChartPoint(hours[i], values[i]));
  }

  // =========================================================================
  // Teacher Workload & Telemetry Summary Cards
  // =========================================================================
  Widget _buildTeacherWorkloadSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Teacher Workload & System Usage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${_workloadSummaries.length} Teachers Assigned',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          child: _workloadSummaries.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    'No teacher records found for this active school year.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _workloadSummaries.map((w) {
                    final teacherSessions = _sessionLogs
                        .where((s) => s.userId == w.teacherId)
                        .toList();

                    return Container(
                      width: 280,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: w.isActiveNow
                              ? AppTheme.catGreen.withValues(alpha: 0.6)
                              : (isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0)),
                          width: w.isActiveNow ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (w.isActiveNow)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.catGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  w.teacherName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subjects Handled:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              Text(
                                '${w.totalSubjectsCount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sections Handled:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              Text(
                                '${w.totalSectionsCount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          ValueListenableBuilder<DateTime>(
                            valueListenable: _tickerNotifier,
                            builder: (context, currentNow, _) {
                              int totalSecs = 0;
                              for (final s in teacherSessions) {
                                if (s.isActive) {
                                  final elapsed = currentNow
                                      .difference(s.loginAt)
                                      .inSeconds;
                                  totalSecs += (elapsed > 0
                                      ? elapsed
                                      : s.durationSeconds);
                                } else {
                                  totalSecs += s.durationSeconds;
                                }
                              }

                              String periodLabel;
                              if (_activeFilter == 'today') {
                                periodLabel = 'Today Usage:';
                              } else if (_activeFilter == 'week') {
                                periodLabel = 'This Week Usage:';
                              } else if (_activeFilter == 'custom' &&
                                  _selectedCustomDate != null) {
                                periodLabel = 'Date Usage:';
                              } else {
                                periodLabel = 'Total Usage:';
                              }

                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    periodLabel,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    AdminRepository.formatHumanReadableDuration(
                                      totalSecs,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: totalSecs > 0
                                          ? AppTheme.catGreen
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // Live Teacher Session Logs Table
  // =========================================================================
  Widget _buildSessionLogsSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Teacher Login & Usage History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${_sessionLogs.length} Records Found',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_sessionLogs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.history,
                  size: 44,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                const SizedBox(height: 14),
                Text(
                  'No Login Records Found',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'There are no recorded teacher sessions for the selected period.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          () {
            final totalLogs = _sessionLogs.length;
            final totalPages = (totalLogs / _historyItemsPerPage).ceil();
            int safePage = _currentHistoryPage;
            if (safePage > totalPages && totalPages > 0) {
              safePage = totalPages;
            }
            if (safePage < 1) {
              safePage = 1;
            }

            final startIndex = (safePage - 1) * _historyItemsPerPage;
            final endIndex = math.min(
              startIndex + _historyItemsPerPage,
              totalLogs,
            );
            final pageLogs = totalLogs > 0
                ? _sessionLogs.sublist(startIndex, endIndex)
                : <UserSessionLog>[];

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<DateTime>(
                      valueListenable: _tickerNotifier,
                      builder: (context, currentNow, _) {
                        return Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.2),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(1.5),
                            4: FlexColumnWidth(2.0),
                          },
                          children: [
                            // Header Row
                            TableRow(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                              ),
                              children: const [
                                _TableHeaderCell('Teacher Name'),
                                _TableHeaderCell('Date'),
                                _TableHeaderCell('Time In'),
                                _TableHeaderCell('Time Out'),
                                _TableHeaderCell('Time Spent in System'),
                              ],
                            ),
                            // Data Rows for Current Page
                            ...pageLogs.map((log) {
                              final isLive = log.isActive;
                              int elapsedSeconds = log.durationSeconds;
                              if (isLive) {
                                elapsedSeconds = currentNow
                                    .difference(log.loginAt)
                                    .inSeconds;
                                if (elapsedSeconds < 0) elapsedSeconds = 0;
                              }

                              return TableRow(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                                children: [
                                  // Teacher Name
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        if (isLive)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.catGreen,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            log.teacherName ??
                                                'Teacher (${log.userId})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Date
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      _formatDate(log.sessionDate),
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  // Login Time
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      _formatTimestamp(log.loginAt),
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  // Logout Time
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: isLive
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.catGreen
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Online Now',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.catGreen,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            log.logoutAt != null
                                                ? _formatTimestamp(
                                                    log.logoutAt!,
                                                  )
                                                : 'Ended',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                            ),
                                          ),
                                  ),
                                  // Duration Ticker
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      AdminRepository.formatHumanReadableDuration(
                                        elapsedSeconds,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        color: isLive
                                            ? AppTheme.catGreen
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                    ),

                    // Bottom Container: Entry count and pagination (Styled like Teacher Management)
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${totalLogs == 0 ? 0 : startIndex + 1} to $endIndex of $totalLogs entries',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (totalPages > 1)
                            Row(
                              children: [
                                _buildPageButton(
                                  'First',
                                  () => setState(() => _currentHistoryPage = 1),
                                  safePage > 1,
                                ),
                                _buildPageButton(
                                  '<',
                                  () => setState(
                                    () => _currentHistoryPage = safePage - 1,
                                  ),
                                  safePage > 1,
                                ),
                                for (int p = 1; p <= totalPages; p++)
                                  if (p >= safePage - 2 && p <= safePage + 2)
                                    _buildPageButton(
                                      p.toString(),
                                      () => setState(
                                        () => _currentHistoryPage = p,
                                      ),
                                      true,
                                      isActive: p == safePage,
                                    ),
                                _buildPageButton(
                                  '>',
                                  () => setState(
                                    () => _currentHistoryPage = safePage + 1,
                                  ),
                                  safePage < totalPages,
                                ),
                                _buildPageButton(
                                  'Last',
                                  () => setState(
                                    () => _currentHistoryPage = totalPages,
                                  ),
                                  safePage < totalPages,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
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

  // =========================================================================
  // Theme-Aware Skeleton Shimmer Loading (Both Light and Dark Mode)
  // =========================================================================
  Widget _buildSkeletonLoading(BuildContext context, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return _SkeletonShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBar(width: 300, height: 24, borderRadius: 8),
                    const SizedBox(height: 8),
                    _skeletonBar(width: 400, height: 14, borderRadius: 6),
                  ],
                ),
                _skeletonBar(width: 280, height: 38, borderRadius: 10),
              ],
            ),
            const SizedBox(height: 24),

            // Overview KPI Cards Skeleton
            Row(
              children: [
                Expanded(child: _buildMetricCardSkeleton(cardBg, borderColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCardSkeleton(cardBg, borderColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCardSkeleton(cardBg, borderColor)),
              ],
            ),
            const SizedBox(height: 24),

            // Charts Skeleton Row
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    height: 240,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBar(width: 220, height: 16),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _skeletonBar(
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 240,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(child: _skeletonCircle(size: 130)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Workload Telemetry Cards Skeleton
            _skeletonBar(width: 280, height: 18, borderRadius: 6),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  3,
                  (_) => _buildWorkloadCardSkeleton(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _skeletonBar({
    double? width,
    required double height,
    double borderRadius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static Widget _skeletonCircle({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  static Widget _buildMetricCardSkeleton(Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _skeletonCircle(size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBar(width: 90, height: 12),
                const SizedBox(height: 6),
                _skeletonBar(width: 120, height: 16),
                const SizedBox(height: 4),
                _skeletonBar(width: 70, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildWorkloadCardSkeleton(bool isDark) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBar(width: 140, height: 14),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _skeletonBar(width: 100, height: 12),
              _skeletonBar(width: 24, height: 12),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _skeletonBar(width: 100, height: 12),
              _skeletonBar(width: 24, height: 12),
            ],
          ),
          const SizedBox(height: 12),
          _skeletonBar(width: double.infinity, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _skeletonBar(width: 90, height: 11),
              _skeletonBar(width: 50, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Custom Painter: Activity Curve Chart (Inspired by Pic 4)
// =========================================================================
class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint(this.label, this.value);
}

class _TeacherActivityCurveChart extends StatelessWidget {
  final List<_ChartPoint> points;
  final bool isDark;
  final Color lineColor;

  const _TeacherActivityCurveChart({
    required this.points,
    required this.isDark,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _CurveChartPainter(
        points: points,
        isDark: isDark,
        lineColor: lineColor,
      ),
    );
  }
}

class _CurveChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final bool isDark;
  final Color lineColor;

  _CurveChartPainter({
    required this.points,
    required this.isDark,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const bottomPadding = 24.0;
    const topPadding = 20.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final chartWidth = size.width;

    double maxVal = 0.0;
    for (final p in points) {
      if (p.value > maxVal) maxVal = p.value;
    }
    if (maxVal <= 0.0) maxVal = 4.0; // Default scale ceiling
    maxVal = maxVal * 1.25; // Top breathing room

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    final n = points.length;
    final dx = n > 1 ? chartWidth / (n - 1) : chartWidth;

    final path = Path();
    final fillPath = Path();

    final pointCoords = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = dx * i;
      final normalizedY = points[i].value / maxVal;
      final y = topPadding + chartHeight * (1.0 - normalizedY);
      pointCoords.add(Offset(x, y));
    }

    if (pointCoords.isNotEmpty) {
      path.moveTo(pointCoords[0].dx, pointCoords[0].dy);
      fillPath.moveTo(pointCoords[0].dx, pointCoords[0].dy);

      for (int i = 0; i < pointCoords.length - 1; i++) {
        final p0 = pointCoords[i];
        final p1 = pointCoords[i + 1];
        final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlX2 = controlX1;
        path.cubicTo(controlX1, p0.dy, controlX2, p1.dy, p1.dx, p1.dy);
        fillPath.cubicTo(controlX1, p0.dy, controlX2, p1.dy, p1.dx, p1.dy);
      }

      fillPath.lineTo(pointCoords.last.dx, size.height - bottomPadding);
      fillPath.lineTo(pointCoords.first.dx, size.height - bottomPadding);
      fillPath.close();

      // Draw Gradient Area Fill under the curve
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: isDark ? 0.35 : 0.22),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, gradientPaint);

      // Draw Curve Stroke
      final strokePaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);

      // Draw Points & Highlight Pill on Peak
      int peakIdx = 0;
      double peakVal = -1;
      for (int i = 0; i < points.length; i++) {
        if (points[i].value > peakVal) {
          peakVal = points[i].value;
          peakIdx = i;
        }
      }

      for (int i = 0; i < pointCoords.length; i++) {
        final pt = pointCoords[i];

        // Outer glow
        canvas.drawCircle(
          pt,
          5.0,
          Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white,
        );
        // Inner point
        canvas.drawCircle(pt, 3.5, Paint()..color = lineColor);

        // Draw Peak Highlight Badge if active
        if (i == peakIdx && peakVal > 0) {
          final badgeRect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(pt.dx, pt.dy - 18),
              width: 56,
              height: 20,
            ),
            const Radius.circular(6),
          );
          canvas.drawRRect(
            badgeRect,
            Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white,
          );
          canvas.drawRRect(
            badgeRect,
            Paint()
              ..color = lineColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );

          final tpVal = TextPainter(
            text: TextSpan(
              text: '${peakVal.toStringAsFixed(1)}h',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tpVal.paint(canvas, Offset(pt.dx - (tpVal.width / 2), pt.dy - 24));
        }
      }
    }

    // X-Axis Text Labels
    final textStyle = TextStyle(
      fontSize: 11,
      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < points.length; i++) {
      final x = dx * i;
      final tp = TextPainter(
        text: TextSpan(text: points[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      double drawX = x - (tp.width / 2);
      if (i == 0) drawX = 0;
      if (i == points.length - 1) drawX = chartWidth - tp.width;

      tp.paint(canvas, Offset(drawX, size.height - bottomPadding + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _CurveChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDark != isDark;
  }
}

// =========================================================================
// Custom Painter: Activity Donut Chart (Inspired by Pic 4)
// =========================================================================
class _TeacherActivityDonutPainter extends CustomPainter {
  final int activeNowCount;
  final int idleCount;
  final int total;
  final bool isDark;

  _TeacherActivityDonutPainter({
    required this.activeNowCount,
    required this.idleCount,
    required this.total,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 16.0;

    final backgroundPaint = Paint()
      ..color = isDark ? Colors.white10 : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    final activePct = activeNowCount / total;
    final idlePct = idleCount / total;

    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final sweepAngle =
          (pct * 2 * math.pi) - 0.08; // Small gap between segments
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (sweepAngle > 0) {
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      }
      startAngle += pct * 2 * math.pi;
    }

    drawSegment(activePct, AppTheme.catGreen);
    drawSegment(idlePct, isDark ? Colors.white24 : const Color(0xFFCBD5E1));
  }

  @override
  bool shouldRepaint(covariant _TeacherActivityDonutPainter oldDelegate) {
    return oldDelegate.activeNowCount != activeNowCount ||
        oldDelegate.idleCount != idleCount ||
        oldDelegate.total != total ||
        oldDelegate.isDark != isDark;
  }
}

// =========================================================================
// Shimmer Animation Wrapper
// =========================================================================
class _SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const _SkeletonShimmer({required this.child});

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade300;
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.5, -0.3),
              end: const Alignment(1.5, 0.3),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(
                slidePercent: _shimmerController.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.5 - 1.25),
      0.0,
      0.0,
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
      ),
    );
  }
}
