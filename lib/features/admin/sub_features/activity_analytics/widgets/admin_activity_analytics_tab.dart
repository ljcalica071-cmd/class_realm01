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
  String? _selectedTeacherId; // null = all teachers

  static const List<Color> _teacherColorPalette = [
    AppTheme.catGreen, // Emerald
    Color(0xFF6366F1), // Indigo
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF43F5E), // Coral / Rose
    Color(0xFF3B82F6), // Blue
  ];

  List<UserSessionLog> _sessionLogs = [];
  List<TeacherWorkloadSummary> _workloadSummaries = [];

  // Local memory cache per filter to avoid re-fetching and eliminate loading flicker
  final Map<String, List<UserSessionLog>> _sessionLogsCache = {};
  final Map<String, List<TeacherWorkloadSummary>> _workloadCache = {};

  // 1-second ticker using ValueNotifier to isolate real-time duration updates without full-tree rebuilds
  late final ValueNotifier<DateTime> _tickerNotifier;
  Timer? _oneSecondTimer;

  // Realtime debounce buffer
  RealtimeChannel? _realtimeChannel;
  Timer? _debounceTimer;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tickerNotifier = ValueNotifier<DateTime>(DateTime.now());
    _startTicker();
    _restoreCachedData(_getCacheKey());
    _loadData();
    _subscribeToSessionRealtime();

    // Resilient 15-second background auto-refresh in case of dropped WebSockets
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadData(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _oneSecondTimer?.cancel();
    _debounceTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _tickerNotifier.dispose();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  void _startTicker() {
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickerNotifier.value = DateTime.now();
    });
  }

  void _subscribeToSessionRealtime() {
    final client = Supabase.instance.client;
    if (_realtimeChannel != null) {
      try {
        client.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }

    _realtimeChannel = client
        .channel('admin_activity_realtime_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_session_logs',
          callback: (payload) {
            final newData = payload.newRecord;
            if (newData.isNotEmpty && newData['role'] == 'teacher') {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _loadData(isSilent: true);
                  }
                });
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[ActivityAnalytics] Realtime status: $status');
          if (error != null) {
            debugPrint('[ActivityAnalytics] Realtime error: $error');
          }
        });
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
    final localDt = dt.toLocal();
    final hour = localDt.hour % 12 == 0 ? 12 : localDt.hour % 12;
    final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
    final minute = localDt.minute.toString().padLeft(2, '0');
    final second = localDt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second $ampm';
  }

  String _formatDate(DateTime dt) {
    final localDt = dt.toLocal();
    return '${localDt.year}-${localDt.month.toString().padLeft(2, '0')}-${localDt.day.toString().padLeft(2, '0')}';
  }

  String _formatHumanReadableTotal(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  static String _shortMonth(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }

  static String _formatTooltipDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00h 00m';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h == 0 && m == 0) {
      return '${s.toString().padLeft(2, '0')}s';
    }
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
  }

  List<_TeacherInfo> _getTeacherInfoList() {
    if (_workloadSummaries.isNotEmpty) {
      return List.generate(_workloadSummaries.length, (i) {
        final w = _workloadSummaries[i];
        return _TeacherInfo(
          id: w.teacherId,
          name: w.teacherName,
          color: _teacherColorPalette[i % _teacherColorPalette.length],
        );
      });
    }

    final uniqueTeacherIds = <String>{};
    final teachers = <_TeacherInfo>[];
    int colorIdx = 0;
    for (final log in _sessionLogs) {
      if (!uniqueTeacherIds.contains(log.userId)) {
        uniqueTeacherIds.add(log.userId);
        teachers.add(
          _TeacherInfo(
            id: log.userId,
            name: log.teacherName ?? 'Teacher',
            color: _teacherColorPalette[colorIdx % _teacherColorPalette.length],
          ),
        );
        colorIdx++;
      }
    }

    if (teachers.isEmpty) {
      return const [
        _TeacherInfo(
          id: 'faculty',
          name: 'Faculty',
          color: AppTheme.catGreen,
        ),
      ];
    }
    return teachers;
  }

  String _getChartSubtitle() {
    if (_selectedTeacherId != null) {
      final teachers = _getTeacherInfoList();
      final match = teachers.where((t) => t.id == _selectedTeacherId);
      final teacherName = match.isNotEmpty ? match.first.name : 'Selected Faculty';
      return 'Session telemetry & usage timeline for $teacherName';
    }

    if (_activeFilter == 'all') {
      return 'Historical timeline across all recorded session dates';
    } else if (_activeFilter == 'week') {
      return 'Daily faculty usage breakdown this week (Monday – Sunday)';
    } else if (_activeFilter == 'custom' && _selectedCustomDate != null) {
      return 'Hourly faculty usage on ${_formatDate(_selectedCustomDate!)}';
    }
    return 'Real-time hourly faculty activity and usage today';
  }

  Widget _buildTeacherFilterMenu(BuildContext context, bool isDark) {
    final teachers = _getTeacherInfoList();
    if (teachers.isEmpty) return const SizedBox.shrink();

    final selectedTeacher = _selectedTeacherId != null
        ? teachers.firstWhere(
            (t) => t.id == _selectedTeacherId,
            orElse: () => teachers.first,
          )
        : null;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
        ),
      ),
      child: PopupMenuButton<String?>(
        tooltip: 'Filter by Teacher',
        offset: const Offset(0, 36),
        onSelected: (String? teacherId) {
          setState(() => _selectedTeacherId = teacherId);
        },
        itemBuilder: (context) => [
          PopupMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                Icon(
                  LucideIcons.users,
                  size: 15,
                  color: _selectedTeacherId == null
                      ? AppTheme.catGreen
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(width: 8),
                Text(
                  'All Faculty',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _selectedTeacherId == null
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: _selectedTeacherId == null
                        ? AppTheme.catGreen
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                ),
                const Spacer(),
                if (_selectedTeacherId == null)
                  const Icon(Icons.check, size: 16, color: AppTheme.catGreen),
              ],
            ),
          ),
          const PopupMenuDivider(),
          ...teachers.map((t) {
            final isCurrent = _selectedTeacherId == t.id;
            return PopupMenuItem<String?>(
              value: t.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: t.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent
                            ? t.color
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent)
                    Icon(Icons.check, size: 16, color: t.color),
                ],
              ),
            );
          }),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedTeacher != null
                  ? selectedTeacher.color.withValues(alpha: 0.5)
                  : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedTeacher != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: selectedTeacher.color,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    LucideIcons.users,
                    size: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              Text(
                selectedTeacher != null ? selectedTeacher.name : 'All Faculty',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use skeleton loading if still fetching AND cache is empty
    if (!_hasInitialLoaded || _isSwitchingFilter) {
      return _buildSkeletonLoading(context, isDark);
    }

    final currentNow = DateTime.now();
    final activeNowCount = _sessionLogs
        .where((s) => s.isActive)
        .map((s) => s.userId)
        .toSet()
        .length;
    final totalTrackedTeachers = _workloadSummaries.isNotEmpty
        ? _workloadSummaries.length
        : math.max(activeNowCount, 1);
    final totalDurationSeconds = _sessionLogs.fold<int>(
      0,
      (sum, s) {
        if (s.isActive) {
          final liveSec = currentNow.difference(s.loginAt).inSeconds;
          return sum + (liveSec > s.durationSeconds ? liveSec : s.durationSeconds);
        }
        return sum + s.durationSeconds;
      },
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

    // Prepare chart series data based on active filter and teacher selection
    final seriesList = _generateChartData();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faculty Engagement & System Usage',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _getChartSubtitle(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTeacherFilterMenu(context, isDark),
                  const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 20),

          // Custom Curve Chart Painter with smooth hover and multi-series support
          SizedBox(
            height: seriesList.length > 1 ? 220 : 190,
            child: _TeacherActivityCurveChart(
              seriesList: seriesList,
              isDark: isDark,
              activeFilter: _activeFilter,
              onTeacherSelected: (teacherId) {
                setState(() => _selectedTeacherId = teacherId);
              },
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

    final idleCount = math.max(0, totalTrackedTeachers - activeNowCount);

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
  // Chart Data Generation (Multi-Teacher & All-Records Aware)
  // =========================================================================
  List<_TeacherSeries> _generateChartData() {
    final currentNow = DateTime.now();
    final allTeachers = _getTeacherInfoList();

    // Determine target teachers to plot
    final List<_TeacherInfo> targetTeachers;
    if (_selectedTeacherId != null) {
      final matched = allTeachers.where((t) => t.id == _selectedTeacherId).toList();
      targetTeachers = matched.isNotEmpty ? matched : allTeachers;
    } else {
      targetTeachers = allTeachers;
    }

    // Filter session logs for target teachers if single teacher selected
    final List<UserSessionLog> relevantLogs;
    if (_selectedTeacherId != null) {
      relevantLogs = _sessionLogs.where((s) => s.userId == _selectedTeacherId).toList();
    } else {
      relevantLogs = _sessionLogs;
    }

    if (_activeFilter == 'all') {
      // Collect sorted unique dates across relevant logs
      final allDatesSet = <DateTime>{};
      for (final log in relevantLogs) {
        allDatesSet.add(DateTime(log.sessionDate.year, log.sessionDate.month, log.sessionDate.day));
      }
      final sortedDates = allDatesSet.toList()..sort((a, b) => a.compareTo(b));

      List<DateTime> displayDates;
      if (sortedDates.isEmpty) {
        displayDates = List.generate(
          5,
          (i) => DateTime(currentNow.year, currentNow.month, currentNow.day)
              .subtract(Duration(days: 4 - i)),
        );
      } else if (sortedDates.length == 1) {
        final singleDate = sortedDates.first;
        displayDates = List.generate(
          5,
          (i) => singleDate.subtract(Duration(days: 4 - i)),
        );
      } else if (sortedDates.length > 7) {
        displayDates = sortedDates.sublist(sortedDates.length - 7);
      } else {
        displayDates = sortedDates;
      }

      return targetTeachers.map((teacher) {
        final teacherLogs = relevantLogs.where((s) => s.userId == teacher.id).toList();
        final points = displayDates.map((date) {
          int sec = 0;
          for (final log in teacherLogs) {
            if (log.sessionDate.year == date.year &&
                log.sessionDate.month == date.month &&
                log.sessionDate.day == date.day) {
              int sessionSec = log.durationSeconds;
              if (log.isActive) {
                final activeSec = currentNow.difference(log.loginAt).inSeconds;
                if (activeSec > sessionSec) sessionSec = activeSec;
              }
              sec += sessionSec;
            }
          }
          final hoursVal = sec / 3600.0;
          final dateLabel = '${_shortMonth(date.month)} ${date.day}';
          return _ChartPoint(
            label: dateLabel,
            value: hoursVal,
            totalSeconds: sec,
            teacherId: teacher.id,
            teacherName: teacher.name,
            date: date,
          );
        }).toList();

        return _TeacherSeries(
          teacherId: teacher.id,
          teacherName: teacher.name,
          color: teacher.color,
          points: points,
        );
      }).toList();
    }

    if (_activeFilter == 'week') {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return targetTeachers.map((teacher) {
        final teacherLogs = relevantLogs.where((s) => s.userId == teacher.id).toList();
        final points = List.generate(7, (weekdayIdx) {
          int sec = 0;
          for (final log in teacherLogs) {
            if (log.sessionDate.weekday - 1 == weekdayIdx) {
              int sessionSec = log.durationSeconds;
              if (log.isActive) {
                final activeSec = currentNow.difference(log.loginAt).inSeconds;
                if (activeSec > sessionSec) sessionSec = activeSec;
              }
              sec += sessionSec;
            }
          }
          final hoursVal = sec / 3600.0;
          return _ChartPoint(
            label: days[weekdayIdx],
            value: hoursVal,
            totalSeconds: sec,
            teacherId: teacher.id,
            teacherName: teacher.name,
          );
        });

        return _TeacherSeries(
          teacherId: teacher.id,
          teacherName: teacher.name,
          color: teacher.color,
          points: points,
        );
      }).toList();
    }

    // Default to Hourly buckets (8 AM to 6 PM) for 'today' and 'custom'
    final hours = ['8 AM', '10 AM', '12 PM', '2 PM', '4 PM', '6 PM'];
    final hourBuckets = [8, 10, 12, 14, 16, 18];

    return targetTeachers.map((teacher) {
      final teacherLogs = relevantLogs.where((s) => s.userId == teacher.id).toList();
      final points = List.generate(6, (i) {
        int sec = 0;
        final bucketHour = hourBuckets[i];
        final nextBucketHour = i < hourBuckets.length - 1 ? hourBuckets[i + 1] : 24;

        for (final log in teacherLogs) {
          final h = log.loginAt.hour;
          bool inBucket = false;
          if (i == 0 && h < hourBuckets[0]) {
            inBucket = true;
          } else if (i == hourBuckets.length - 1 && h >= hourBuckets.last) {
            inBucket = true;
          } else if (h >= bucketHour && h < nextBucketHour) {
            inBucket = true;
          }

          if (inBucket) {
            int sessionSec = log.durationSeconds;
            if (log.isActive) {
              final activeSec = currentNow.difference(log.loginAt).inSeconds;
              if (activeSec > sessionSec) sessionSec = activeSec;
            }
            sec += sessionSec;
          }
        }

        final hoursVal = sec / 3600.0;
        return _ChartPoint(
          label: hours[i],
          value: hoursVal,
          totalSeconds: sec,
          teacherId: teacher.id,
          teacherName: teacher.name,
        );
      });

      return _TeacherSeries(
        teacherId: teacher.id,
        teacherName: teacher.name,
        color: teacher.color,
        points: points,
      );
    }).toList();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          _SkeletonShimmer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBar(width: 300, height: 24, borderRadius: 8, isDark: isDark),
                    const SizedBox(height: 8),
                    _skeletonBar(width: 400, height: 14, borderRadius: 6, isDark: isDark),
                  ],
                ),
                _skeletonBar(width: 280, height: 38, borderRadius: 10, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Overview KPI Cards Skeleton
          Row(
            children: [
              Expanded(child: _buildMetricCardSkeleton(cardBg, borderColor, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCardSkeleton(cardBg, borderColor, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCardSkeleton(cardBg, borderColor, isDark)),
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
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: _SkeletonShimmer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBar(width: 220, height: 16, isDark: isDark),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _skeletonBar(
                            width: double.infinity,
                            height: double.infinity,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
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
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _SkeletonShimmer(
                      child: _skeletonCircle(size: 130, isDark: isDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Workload Telemetry Cards Skeleton
          _SkeletonShimmer(
            child: _skeletonBar(width: 280, height: 18, borderRadius: 6, isDark: isDark),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
    );
  }

  static Widget _skeletonBar({
    double? width,
    required double height,
    double borderRadius = 6,
    bool isDark = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static Widget _skeletonCircle({
    required double size,
    bool isDark = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
    );
  }

  static Widget _buildMetricCardSkeleton(
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: _SkeletonShimmer(
        child: Row(
          children: [
            _skeletonCircle(size: 46, isDark: isDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBar(width: 90, height: 12, isDark: isDark),
                  const SizedBox(height: 6),
                  _skeletonBar(width: 120, height: 16, isDark: isDark),
                  const SizedBox(height: 4),
                  _skeletonBar(width: 70, height: 10, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildWorkloadCardSkeleton(bool isDark) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: _SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeletonBar(width: 140, height: 14, isDark: isDark),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _skeletonBar(width: 100, height: 12, isDark: isDark),
                _skeletonBar(width: 24, height: 12, isDark: isDark),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _skeletonBar(width: 100, height: 12, isDark: isDark),
                _skeletonBar(width: 24, height: 12, isDark: isDark),
              ],
            ),
            const SizedBox(height: 12),
            _skeletonBar(width: double.infinity, height: 1, isDark: isDark),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _skeletonBar(width: 90, height: 11, isDark: isDark),
                _skeletonBar(width: 50, height: 11, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Custom Painter: Activity Curve Chart (Inspired by Pic 4)
// =========================================================================
class _TeacherInfo {
  final String id;
  final String name;
  final Color color;
  const _TeacherInfo({
    required this.id,
    required this.name,
    required this.color,
  });
}

class _ChartPoint {
  final String label;
  final double value;
  final int totalSeconds;
  final String? teacherId;
  final String? teacherName;
  final DateTime? date;

  const _ChartPoint({
    required this.label,
    required this.value,
    this.totalSeconds = 0,
    this.teacherId,
    this.teacherName,
    this.date,
  });
}

class _TeacherSeries {
  final String teacherId;
  final String teacherName;
  final Color color;
  final List<_ChartPoint> points;

  const _TeacherSeries({
    required this.teacherId,
    required this.teacherName,
    required this.color,
    required this.points,
  });
}

class _TeacherActivityCurveChart extends StatefulWidget {
  final List<_ChartPoint> points;
  final bool isDark;
  final Color lineColor;
  final List<_TeacherSeries> seriesList;
  final String activeFilter;
  final ValueChanged<String?>? onTeacherSelected;

  const _TeacherActivityCurveChart({
    required this.isDark,
    this.seriesList = const [],
    this.activeFilter = 'today',
    this.onTeacherSelected,
  }) : points = const [], lineColor = AppTheme.catGreen;

  @override
  State<_TeacherActivityCurveChart> createState() =>
      _TeacherActivityCurveChartState();
}

class _TeacherActivityCurveChartState extends State<_TeacherActivityCurveChart>
    with SingleTickerProviderStateMixin {
  int? _hoveredPointIndex;
  int? _hoveredSeriesIndex;
  late final AnimationController _hoverAnimController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _hoverAnimController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _hoverAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSeries = widget.seriesList.isNotEmpty
        ? widget.seriesList
        : (widget.points.isNotEmpty
            ? [
                _TeacherSeries(
                  teacherId: 'default',
                  teacherName: 'Faculty',
                  color: widget.lineColor,
                  points: widget.points,
                ),
              ]
            : <_TeacherSeries>[]);

    if (effectiveSeries.isEmpty || effectiveSeries.first.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final pointsCount = effectiveSeries.first.points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                onHover: (event) {
                  final x = event.localPosition.dx;
                  final width = constraints.maxWidth;
                  final dxPerPoint =
                      pointsCount > 1 ? width / (pointsCount - 1) : width;

                  final nearestPointIndex =
                      (x / dxPerPoint).round().clamp(0, pointsCount - 1);

                  // If multiple series, determine which series line is closest in Y
                  int nearestSeriesIndex = 0;
                  if (effectiveSeries.length > 1) {
                    double minDiff = double.infinity;
                    final chartHeight = constraints.maxHeight - 44.0;
                    double maxVal = 0.0;
                    for (final s in effectiveSeries) {
                      for (final p in s.points) {
                        if (p.value > maxVal) maxVal = p.value;
                      }
                    }
                    if (maxVal <= 0.0) maxVal = 4.0;
                    maxVal = maxVal * 1.25;

                    for (int sIdx = 0; sIdx < effectiveSeries.length; sIdx++) {
                      final p = effectiveSeries[sIdx].points[nearestPointIndex];
                      final normalizedY = p.value / maxVal;
                      final ptY = 20.0 + chartHeight * (1.0 - normalizedY);
                      final diff = (event.localPosition.dy - ptY).abs();
                      if (diff < minDiff) {
                        minDiff = diff;
                        nearestSeriesIndex = sIdx;
                      }
                    }
                  }

                  if (_hoveredPointIndex != nearestPointIndex ||
                      _hoveredSeriesIndex != nearestSeriesIndex) {
                    setState(() {
                      _hoveredPointIndex = nearestPointIndex;
                      _hoveredSeriesIndex = nearestSeriesIndex;
                    });
                    _hoverAnimController.forward(from: 0.0);
                  }
                },
                onExit: (_) {
                  setState(() {
                    _hoveredPointIndex = null;
                    _hoveredSeriesIndex = null;
                  });
                  _hoverAnimController.reverse();
                },
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _CurveChartPainter(
                        seriesList: effectiveSeries,
                        isDark: widget.isDark,
                        lineColor: widget.lineColor,
                        activeFilter: widget.activeFilter,
                        hoveredPointIndex: _hoveredPointIndex,
                        hoveredSeriesIndex: _hoveredSeriesIndex,
                        hoverAnimValue: _scaleAnimation.value,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        // If there are 2 or more series, render interactive legend pills below
        if (effectiveSeries.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: effectiveSeries.map((series) {
                return InkWell(
                  onTap: () => widget.onTeacherSelected?.call(series.teacherId),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: series.color
                          .withValues(alpha: widget.isDark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: series.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: series.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          series.teacherName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: series.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _CurveChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final bool isDark;
  final Color lineColor;
  final int? hoveredIndex;
  final List<_TeacherSeries> seriesList;
  final String activeFilter;
  final int? hoveredPointIndex;
  final int? hoveredSeriesIndex;
  final double hoverAnimValue;

  _CurveChartPainter({
    required this.isDark,
    this.lineColor = AppTheme.catGreen,
    this.seriesList = const [],
    this.activeFilter = 'today',
    this.hoveredIndex,
    this.hoveredPointIndex,
    this.hoveredSeriesIndex,
    this.hoverAnimValue = 0.0,
  }) : points = const [];

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveSeries = seriesList.isNotEmpty
        ? seriesList
        : (points.isNotEmpty
            ? [
                _TeacherSeries(
                  teacherId: 'default',
                  teacherName: 'Faculty',
                  color: lineColor,
                  points: points,
                ),
              ]
            : <_TeacherSeries>[]);

    if (effectiveSeries.isEmpty || effectiveSeries.first.points.isEmpty) return;

    const bottomPadding = 24.0;
    const topPadding = 20.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final chartWidth = size.width;

    double maxVal = 0.0;
    for (final s in effectiveSeries) {
      for (final p in s.points) {
        if (p.value > maxVal) maxVal = p.value;
      }
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

    final pointsCount = effectiveSeries.first.points.length;
    final dx = pointsCount > 1 ? chartWidth / (pointsCount - 1) : chartWidth;

    // Collect coordinates for every series
    final allSeriesCoords = <List<Offset>>[];

    for (int sIdx = 0; sIdx < effectiveSeries.length; sIdx++) {
      final series = effectiveSeries[sIdx];
      final pointCoords = <Offset>[];

      for (int i = 0; i < pointsCount; i++) {
        final x = dx * i;
        final normalizedY = (series.points[i].value / maxVal).clamp(0.0, 1.0);
        final y = topPadding + chartHeight * (1.0 - normalizedY);
        pointCoords.add(Offset(x, y));
      }
      allSeriesCoords.add(pointCoords);

      if (pointCoords.isNotEmpty) {
        final path = Path();
        final fillPath = Path();

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

        // If single series, draw gradient fill under curve
        if (effectiveSeries.length == 1) {
          final gradientPaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                series.color.withValues(alpha: isDark ? 0.32 : 0.20),
                series.color.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
          canvas.drawPath(fillPath, gradientPaint);
        }

        // Draw curve stroke
        final strokePaint = Paint()
          ..color = series.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveSeries.length == 1 ? 3.0 : 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, strokePaint);
      }
    }

    // Determine which point and series tooltip to target
    int? targetPointIdx = hoveredPointIndex;
    int targetSeriesIdx = hoveredSeriesIndex ?? 0;

    // If not hovering, find peak point from series
    if (targetPointIdx == null) {
      double peakVal = -1;
      int peakPt = 0;
      int peakS = 0;
      for (int s = 0; s < effectiveSeries.length; s++) {
        for (int p = 0; p < effectiveSeries[s].points.length; p++) {
          if (effectiveSeries[s].points[p].value > peakVal) {
            peakVal = effectiveSeries[s].points[p].value;
            peakPt = p;
            peakS = s;
          }
        }
      }
      if (peakVal > 0) {
        targetPointIdx = peakPt;
        targetSeriesIdx = peakS;
      }
    }

    // Draw Points on each curve
    for (int sIdx = 0; sIdx < effectiveSeries.length; sIdx++) {
      final series = effectiveSeries[sIdx];
      final coords = allSeriesCoords[sIdx];

      for (int i = 0; i < coords.length; i++) {
        final pt = coords[i];
        final isThisTarget = (targetPointIdx == i) && (targetSeriesIdx == sIdx);
        final isHovered = (hoveredPointIndex == i) && (hoveredSeriesIndex == sIdx);

        if (isHovered && hoverAnimValue > 0) {
          // Animated glowing ring on hover
          final outerGlowRadius = 5.0 + (3.5 * hoverAnimValue);
          canvas.drawCircle(
            pt,
            outerGlowRadius,
            Paint()
              ..color = series.color.withValues(alpha: 0.25 * hoverAnimValue),
          );

          // Center white/dark circle ring
          canvas.drawCircle(
            pt,
            6.5,
            Paint()
              ..color = isDark ? const Color(0xFF1E293B) : Colors.white,
          );
          // Inner dot
          canvas.drawCircle(
            pt,
            4.5,
            Paint()..color = series.color,
          );
        } else {
          // Normal point
          canvas.drawCircle(
            pt,
            isThisTarget ? 6.0 : 4.5,
            Paint()
              ..color = isDark ? const Color(0xFF1E293B) : Colors.white,
          );
          canvas.drawCircle(
            pt,
            isThisTarget ? 4.0 : 3.0,
            Paint()..color = series.color,
          );
        }
      }
    }

    // Draw Highlight Badge Tooltip for targeted point
    if (targetPointIdx != null &&
        targetSeriesIdx < effectiveSeries.length &&
        targetPointIdx < effectiveSeries[targetSeriesIdx].points.length) {
      final targetSeries = effectiveSeries[targetSeriesIdx];
      final targetPoint = targetSeries.points[targetPointIdx];
      final pt = allSeriesCoords[targetSeriesIdx][targetPointIdx];

      // Format duration strictly as 00h 00m (or 00s if < 1m)
      final durationStr = _AdminActivityAnalyticsTabState._formatTooltipDuration(
        targetPoint.totalSeconds,
      );

      final teacherName = targetPoint.teacherName ?? targetSeries.teacherName;

      // Text Painters
      final nameSpan = TextSpan(
        text: teacherName,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      );
      final tpName = TextPainter(
        text: nameSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final timeSpan = TextSpan(
        text: durationStr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: targetSeries.color,
        ),
      );
      final tpTime = TextPainter(
        text: timeSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // If activeFilter is 'all', show the date label in subtle text
      TextPainter? tpDate;
      if (activeFilter == 'all') {
        tpDate = TextPainter(
          text: TextSpan(
            text: targetPoint.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      }

      double maxContentWidth = math.max(tpName.width, tpTime.width);
      if (tpDate != null && tpDate.width > maxContentWidth) {
        maxContentWidth = tpDate.width;
      }

      final badgeWidth = maxContentWidth + 20;
      final badgeHeight = tpName.height +
          tpTime.height +
          (tpDate != null ? tpDate.height + 4 : 0) +
          14;

      // Check whether tooltip fits comfortably above the point
      final fitsAbove = (pt.dy - badgeHeight - 16) >= 0;
      final badgeCenterY = fitsAbove
          ? pt.dy - (badgeHeight / 2) - 12
          : pt.dy + (badgeHeight / 2) + 12;

      final badgeCenterX =
          pt.dx.clamp(badgeWidth / 2 + 6, chartWidth - badgeWidth / 2 - 6);

      canvas.save();
      canvas.translate(badgeCenterX, badgeCenterY);

      // Smooth scale spring animation on hover
      final scale = hoveredPointIndex != null
          ? (0.85 + (0.15 * hoverAnimValue.clamp(0.0, 1.0)))
          : 1.0;
      canvas.scale(scale, scale);

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: badgeWidth,
          height: badgeHeight,
        ),
        const Radius.circular(8),
      );

      // Shadow
      canvas.drawRRect(
        badgeRect.shift(const Offset(0, 3)),
        Paint()
          ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Background
      canvas.drawRRect(
        badgeRect,
        Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white,
      );

      // Border with teacher color
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = targetSeries.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );

      // Triangle Caret pointing towards circle dot
      final caretPath = Path();
      final caretX =
          (pt.dx - badgeCenterX).clamp(-badgeWidth / 2 + 10, badgeWidth / 2 - 10);
      if (fitsAbove) {
        caretPath.moveTo(caretX - 5, badgeHeight / 2);
        caretPath.lineTo(caretX + 5, badgeHeight / 2);
        caretPath.lineTo(caretX, badgeHeight / 2 + 5);
      } else {
        caretPath.moveTo(caretX - 5, -badgeHeight / 2);
        caretPath.lineTo(caretX + 5, -badgeHeight / 2);
        caretPath.lineTo(caretX, -badgeHeight / 2 - 5);
      }
      caretPath.close();

      canvas.drawPath(
        caretPath,
        Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white,
      );
      canvas.drawPath(
        caretPath,
        Paint()
          ..color = targetSeries.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );

      // Paint texts inside badge
      double currY = -badgeHeight / 2 + 6;
      tpName.paint(canvas, Offset(-tpName.width / 2, currY));
      currY += tpName.height + 2;

      if (tpDate != null) {
        tpDate.paint(canvas, Offset(-tpDate.width / 2, currY));
        currY += tpDate.height + 2;
      }

      tpTime.paint(canvas, Offset(-tpTime.width / 2, currY));

      canvas.restore();
    }

    // X-Axis Text Labels
    final textStyle = TextStyle(
      fontSize: 11,
      color: isDark ? Colors.white60 : const Color(0xFF64748B),
      fontWeight: FontWeight.w600,
    );

    final firstPoints = effectiveSeries.first.points;
    for (int i = 0; i < firstPoints.length; i++) {
      final x = dx * i;
      final tp = TextPainter(
        text: TextSpan(text: firstPoints[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      double drawX = x - (tp.width / 2);
      if (i == 0) drawX = 0;
      if (i == firstPoints.length - 1) drawX = chartWidth - tp.width;

      tp.paint(canvas, Offset(drawX, size.height - bottomPadding + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _CurveChartPainter oldDelegate) {
    return oldDelegate.seriesList != seriesList ||
        oldDelegate.points != points ||
        oldDelegate.isDark != isDark ||
        oldDelegate.hoveredPointIndex != hoveredPointIndex ||
        oldDelegate.hoveredSeriesIndex != hoveredSeriesIndex ||
        oldDelegate.hoverAnimValue != hoverAnimValue ||
        oldDelegate.activeFilter != activeFilter;
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
        : const Color(0xFFE2E8F0);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.white;

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
