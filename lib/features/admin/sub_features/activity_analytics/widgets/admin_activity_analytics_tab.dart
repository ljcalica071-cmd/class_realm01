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
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
  int _loadSequence = 0;
  String _activeFilter = 'today'; // 'today', 'week', 'month', 'custom', 'all'
  DateTime? _selectedCustomDate;
  int _currentHistoryPage = 1;
  static const int _historyItemsPerPage = 10;
  String? _selectedTeacherId; // null = all teachers

  static const List<Color> _teacherColorPalette = [
    AppTheme.catGreen, // Emerald (#10B981) - Sir Naruto Uzumaki
    Color(0xFF8B5CF6), // Purple / Violet - Ma'am Jhon Calantina
    Color(0xFFF59E0B), // Amber - Sir Rex San Juan
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF43F5E), // Coral / Rose
    Color(0xFF3B82F6), // Blue
    Color(0xFF14B8A6), // Teal
    Color(0xFFEC4899), // Pink
  ];

  static final Map<String, Color> _cachedTeacherColors = {};

  /// Returns a permanent, deterministic color for each teacher that NEVER changes across filters
  static Color getTeacherColor(String teacherId, [String? teacherName]) {
    if (_cachedTeacherColors.containsKey(teacherId)) {
      return _cachedTeacherColors[teacherId]!;
    }

    final nameLower = (teacherName ?? '').toLowerCase();
    final idLower = teacherId.toLowerCase();

    // 1. Permanent canonical assignments for primary teachers
    if (nameLower.contains('naruto') || idLower.contains('naruto')) {
      _cachedTeacherColors[teacherId] = _teacherColorPalette[0]; // Always Emerald Green
      return _teacherColorPalette[0];
    }
    if (nameLower.contains('calantina') ||
        nameLower.contains('jhon') ||
        idLower.contains('calantina') ||
        idLower.contains('jhon')) {
      _cachedTeacherColors[teacherId] = _teacherColorPalette[1]; // Always Purple
      return _teacherColorPalette[1];
    }
    if (nameLower.contains('rex') ||
        nameLower.contains('san juan') ||
        idLower.contains('rex')) {
      _cachedTeacherColors[teacherId] = _teacherColorPalette[2]; // Always Amber
      return _teacherColorPalette[2];
    }

    // 2. Persistent storage in AppDataCache
    try {
      final savedRegistry =
          AppDataCache.instance.getCached<Map<String, dynamic>>(
        'admin_teacher_color_registry',
        (raw) => Map<String, dynamic>.from(raw as Map),
      );
      if (savedRegistry != null && savedRegistry.containsKey(teacherId)) {
        final idx = (savedRegistry[teacherId] as num).toInt();
        final color = _teacherColorPalette[idx % _teacherColorPalette.length];
        _cachedTeacherColors[teacherId] = color;
        return color;
      }
    } catch (_) {}

    // 3. Deterministically pick next available distinct color
    final usedColors = _cachedTeacherColors.values.toSet();
    Color? assignedColor;
    int assignedIdx = 0;
    for (int i = 0; i < _teacherColorPalette.length; i++) {
      if (!usedColors.contains(_teacherColorPalette[i])) {
        assignedColor = _teacherColorPalette[i];
        assignedIdx = i;
        break;
      }
    }
    assignedColor ??= _teacherColorPalette[
        teacherId.hashCode.abs() % _teacherColorPalette.length];

    _cachedTeacherColors[teacherId] = assignedColor;

    try {
      final savedRegistry =
          AppDataCache.instance.getCached<Map<String, dynamic>>(
                'admin_teacher_color_registry',
                (raw) => Map<String, dynamic>.from(raw as Map),
              ) ??
              <String, dynamic>{};
      savedRegistry[teacherId] = assignedIdx;
      unawaited(
        AppDataCache.instance.setCache(
          'admin_teacher_color_registry',
          savedRegistry,
        ),
      );
    } catch (_) {}

    return assignedColor;
  }

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
        .channel(
          'admin_activity_realtime_${DateTime.now().millisecondsSinceEpoch}',
        )
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

  String _getCacheKey() => _getCacheKeyFor(_activeFilter, _selectedCustomDate);

  String _getCacheKeyFor(String filter, DateTime? customDate) {
    if (filter == 'custom' && customDate != null) {
      final d = customDate;
      return 'custom_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    return filter;
  }

  void _switchFilter(String key) {
    if (_activeFilter == key) return;

    final nextCacheKey = _getCacheKeyFor(key, _selectedCustomDate);
    final cachedLogs = _sessionLogsCache[nextCacheKey];
    final cachedWorkloads = _workloadCache[nextCacheKey];

    setState(() {
      _activeFilter = key;
      _currentHistoryPage = 1;
      if (cachedLogs != null) {
        _sessionLogs = cachedLogs;
        if (cachedWorkloads != null) {
          _workloadSummaries = cachedWorkloads;
        }
        _isSwitchingFilter = false;
      } else {
        final restored = _restoreCachedData(nextCacheKey);
        if (!restored) {
          // Do not leak old filter's logs into new filter's timeline
          _sessionLogs = [];
        }
        _isSwitchingFilter = !restored;
      }
    });

    _loadData(isFilterSwitch: true, expectedFilter: key);
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
    String? expectedFilter,
  }) async {
    final targetFilter = expectedFilter ?? _activeFilter;
    final thisSequence = ++_loadSequence;
    final cacheKey = _getCacheKeyFor(targetFilter, _selectedCustomDate);

    if (isFilterSwitch && !_sessionLogsCache.containsKey(cacheKey)) {
      _restoreCachedData(cacheKey);
    }

    // If cached and switching filters, immediately display cached data with zero latency
    if (isFilterSwitch && _sessionLogsCache.containsKey(cacheKey)) {
      if (mounted && _activeFilter == targetFilter) {
        setState(() {
          _currentHistoryPage = 1;
          _sessionLogs = _sessionLogsCache[cacheKey]!;
          if (_workloadCache.containsKey(cacheKey)) {
            _workloadSummaries = _workloadCache[cacheKey]!;
          }
          _isSwitchingFilter = false;
        });
      }
      // Fetch in background silently to verify sync
      isSilent = true;
    } else if (isFilterSwitch) {
      if (mounted && _activeFilter == targetFilter) {
        setState(() {
          _currentHistoryPage = 1;
          _isSwitchingFilter = true;
        });
      }
    }

    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    if (targetFilter == 'today') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day);
    } else if (targetFilter == 'week') {
      // Monday to Sunday of current week
      startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      endDate = startDate.add(const Duration(days: 6));
    } else if (targetFilter == 'month') {
      // 1st of current month to end of current month
      startDate = DateTime(now.year, now.month, 1);
      final nextMonth = now.month == 12
          ? DateTime(now.year + 1, 1, 1)
          : DateTime(now.year, now.month + 1, 1);
      endDate = nextMonth.subtract(const Duration(days: 1));
    } else if (targetFilter == 'custom' && _selectedCustomDate != null) {
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

      final wasInitial = !_hasInitialLoaded;
      // Discard stale in-flight responses if user already clicked another filter
      if (mounted && thisSequence == _loadSequence && _activeFilter == targetFilter) {
        setState(() {
          _sessionLogs = logs;
          _workloadSummaries = workloads;
          _hasInitialLoaded = true;
          _isSwitchingFilter = false;
        });
      }
      if (wasInitial) {
        unawaited(_prewarmAllFilters());
      }
    } catch (_) {
      if (mounted && thisSequence == _loadSequence && _activeFilter == targetFilter) {
        setState(() {
          _hasInitialLoaded = true;
          _isSwitchingFilter = false;
        });
      }
    }
  }

  /// Silently pre-fetches and caches standard filters ('week', 'month', 'all')
  /// in the background so switching between them is 100% instantaneous with zero loading flicker!
  Future<void> _prewarmAllFilters() async {
    final filtersToPrewarm = ['week', 'month', 'all'];
    for (final filter in filtersToPrewarm) {
      if (!mounted) return;
      final cacheKey = _getCacheKeyFor(filter, null);
      if (_sessionLogsCache.containsKey(cacheKey)) continue;

      // Try restoring from persistent cache first
      final restored = _restoreCachedData(cacheKey);
      if (restored && _sessionLogsCache.containsKey(cacheKey)) continue;

      try {
        final now = DateTime.now();
        DateTime? startDate;
        DateTime? endDate;

        if (filter == 'week') {
          startDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1));
          endDate = startDate.add(const Duration(days: 6));
        } else if (filter == 'month') {
          startDate = DateTime(now.year, now.month, 1);
          final nextMonth = now.month == 12
              ? DateTime(now.year + 1, 1, 1)
              : DateTime(now.year, now.month + 1, 1);
          endDate = nextMonth.subtract(const Duration(days: 1));
        }

        final logs = await AdminRepository.instance.getTeacherSessionLogs(
          startDate: startDate,
          endDate: endDate,
        );

        if (!mounted) return;
        _sessionLogsCache[cacheKey] = logs;

        unawaited(
          AppDataCache.instance.setCache(_persistentCacheKey(cacheKey), {
            'logs': logs.map((log) {
              return {...log.toJson(), 'teacher_name': log.teacherName};
            }).toList(),
            'workloads': _workloadSummaries.map((summary) {
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
      } catch (_) {}
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

    final customKey =
        'custom_${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final cachedLogs = _sessionLogsCache[customKey];
    final cachedWorkloads = _workloadCache[customKey];

    setState(() {
      _activeFilter = 'custom';
      _selectedCustomDate = picked;
      _currentHistoryPage = 1;
      if (cachedLogs != null) {
        _sessionLogs = cachedLogs;
        if (cachedWorkloads != null) {
          _workloadSummaries = cachedWorkloads;
        }
        _isSwitchingFilter = false;
      } else {
        final restored = _restoreCachedData(customKey);
        if (!restored) {
          _sessionLogs = [];
        }
        _isSwitchingFilter = !restored;
      }
    });

    _loadData(isFilterSwitch: true, expectedFilter: 'custom');
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

  static String _shortWeekday(int weekday) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekday >= 1 && weekday <= 7) return days[weekday];
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
    final teachersMap = <String, _TeacherInfo>{};

    for (final w in _workloadSummaries) {
      if (!teachersMap.containsKey(w.teacherId)) {
        teachersMap[w.teacherId] = _TeacherInfo(
          id: w.teacherId,
          name: w.teacherName,
          color: getTeacherColor(w.teacherId, w.teacherName),
        );
      }
    }

    for (final log in _sessionLogs) {
      if (!teachersMap.containsKey(log.userId)) {
        teachersMap[log.userId] = _TeacherInfo(
          id: log.userId,
          name: log.teacherName ?? 'Teacher',
          color: getTeacherColor(log.userId, log.teacherName),
        );
      }
    }

    if (teachersMap.isEmpty) {
      return const [
        _TeacherInfo(id: 'faculty', name: 'Faculty', color: AppTheme.catGreen),
      ];
    }

    final teachers = teachersMap.values.toList();
    // Deterministic sort: Naruto first, Jhon second, then alphabetical
    teachers.sort((a, b) {
      final aIsNaruto = a.name.toLowerCase().contains('naruto');
      final bIsNaruto = b.name.toLowerCase().contains('naruto');
      if (aIsNaruto && !bIsNaruto) return -1;
      if (!aIsNaruto && bIsNaruto) return 1;

      final aIsJhon = a.name.toLowerCase().contains('jhon') ||
          a.name.toLowerCase().contains('calantina');
      final bIsJhon = b.name.toLowerCase().contains('jhon') ||
          b.name.toLowerCase().contains('calantina');
      if (aIsJhon && !bIsJhon) return -1;
      if (!aIsJhon && bIsJhon) return 1;

      return a.name.compareTo(b.name);
    });

    return teachers;
  }

  String _getChartSubtitle() {
    if (_selectedTeacherId != null) {
      final teachers = _getTeacherInfoList();
      final match = teachers.where((t) => t.id == _selectedTeacherId);
      final teacherName = match.isNotEmpty
          ? match.first.name
          : 'Selected Faculty';
      return 'Session telemetry & usage timeline for $teacherName';
    }

    if (_activeFilter == 'all') {
      return 'Historical timeline across all recorded session dates';
    } else if (_activeFilter == 'month') {
      return 'Daily faculty usage breakdown this month (${_shortMonth(DateTime.now().month)})';
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
          setState(() => _selectedTeacherId = (teacherId == null || teacherId == '__ALL_FACULTY__') ? null : teacherId);
        },
        itemBuilder: (context) => [
          PopupMenuItem<String?>(
            value: '__ALL_FACULTY__',
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
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isCurrent
                            ? t.color
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent) Icon(Icons.check, size: 16, color: t.color),
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

  static const int _maxDailyDurationSeconds = 86400; // 24h strict daily ceiling

  /// Clamps a single session's duration so it never exceeds the remaining seconds
  /// in its login calendar day or 24 hours (86,400s).
  static int _effectiveSessionSeconds(UserSessionLog log, DateTime currentNow) {
    int sessionSec = log.durationSeconds;
    if (log.isActive) {
      final activeSec = currentNow.difference(log.loginAt).inSeconds;
      if (activeSec > sessionSec) sessionSec = activeSec;
    }
    if (sessionSec < 0) sessionSec = 0;

    // A session logged on a calendar day cannot exceed the time remaining until midnight of that day
    final localLogin = log.loginAt.toLocal();
    final nextMidnight = DateTime(
      localLogin.year,
      localLogin.month,
      localLogin.day + 1,
    );
    final maxSecondsInLoginDay = nextMidnight.difference(localLogin).inSeconds;
    if (maxSecondsInLoginDay > 0 && sessionSec > maxSecondsInLoginDay) {
      sessionSec = maxSecondsInLoginDay;
    }
    return sessionSec.clamp(0, _maxDailyDurationSeconds);
  }

  /// Calculates total usage seconds across logs while strictly enforcing a max of
  /// 24 hours (86,400s) per teacher per calendar day across all filters.
  static int _calculateCappedTotalSeconds(
    List<UserSessionLog> logs,
    DateTime currentNow,
  ) {
    final Map<String, int> dailyTeacherTotals = {};
    for (final s in logs) {
      final localLogin = s.loginAt.toLocal();
      final dayKey =
          '${s.userId}_${localLogin.year}-${localLogin.month}-${localLogin.day}';
      final sec = _effectiveSessionSeconds(s, currentNow);
      final currentTotal = dailyTeacherTotals[dayKey] ?? 0;
      dailyTeacherTotals[dayKey] =
          (currentTotal + sec).clamp(0, _maxDailyDurationSeconds);
    }
    return dailyTeacherTotals.values.fold<int>(0, (sum, val) => sum + val);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use skeleton loading ONLY on initial load when cache is empty (prevents double animation on filter switch)
    if (!_hasInitialLoaded) {
      return _buildSkeletonLoading(context, isDark);
    }

    final currentNow = DateTime.now();
    final effectiveDisplayLogs = _selectedTeacherId != null
        ? _sessionLogs.where((s) => s.userId == _selectedTeacherId).toList()
        : _sessionLogs;

    final activeNowCount = effectiveDisplayLogs
        .where((s) => s.isActive)
        .map((s) => s.userId)
        .toSet()
        .length;
    final totalTrackedTeachers = _selectedTeacherId != null
        ? 1
        : (_workloadSummaries.isNotEmpty
            ? _workloadSummaries.length
            : math.max(activeNowCount, 1));
    final totalDurationSeconds = _calculateCappedTotalSeconds(
      effectiveDisplayLogs,
      currentNow,
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
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _isSwitchingFilter ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
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
              _buildFilterButton('This Month', 'month'),
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
      onTap: () => _switchFilter(key),
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
    } else if (_activeFilter == 'month') {
      filterSubtitle = 'This month (${_shortMonth(DateTime.now().month)})';
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

    final currentCacheKey = _getCacheKey();
    final bool isFilterDataReady = _sessionLogsCache.containsKey(currentCacheKey);
    final bool showGraphLoader = _isSwitchingFilter && !isFilterDataReady;

    // Prepare chart series data based on active filter and teacher selection
    final seriesList = showGraphLoader ? <_TeacherSeries>[] : _generateChartData();

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
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.catBlue.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.activity,
                  size: 16,
                  color: AppTheme.catBlue,
                ),
              ),
              const SizedBox(width: 10),
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
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildTeacherFilterMenu(context, isDark),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Curve Chart with smooth entrance animation or clean in-graph loading state
          SizedBox(
            height: 260,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: showGraphLoader
                  ? _buildGraphLoadingPlaceholder(theme, isDark)
                  : _TeacherActivityCurveChart(
                      key: ValueKey(
                        'chart_${_activeFilter}_${_selectedTeacherId}_${_selectedCustomDate?.toIso8601String()}_${_sessionLogs.length}',
                      ),
                      seriesList: seriesList,
                      isDark: isDark,
                      activeFilter: _activeFilter,
                      selectedTeacherId: _selectedTeacherId,
                      selectedCustomDate: _selectedCustomDate,
                      onTeacherSelected: (teacherId) {
                        setState(() => _selectedTeacherId = teacherId);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphLoadingPlaceholder(ThemeData theme, bool isDark) {
    return Container(
      key: const ValueKey('chart_loading_placeholder'),
      height: 260,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ChartGridPlaceholderPainter(isDark: isDark),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.staggeredDotsWave(
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading activity analytics...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
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
    return _TeacherActivityDonutCard(
      isDark: isDark,
      activeNowCount: activeNowCount,
      totalTrackedTeachers: totalTrackedTeachers,
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
      final matched = allTeachers
          .where((t) => t.id == _selectedTeacherId)
          .toList();
      targetTeachers = matched.isNotEmpty ? matched : allTeachers;
    } else {
      targetTeachers = allTeachers;
    }

    // Filter session logs for target teachers if single teacher selected
    final List<UserSessionLog> relevantLogs;
    if (_selectedTeacherId != null) {
      relevantLogs = _sessionLogs
          .where((s) => s.userId == _selectedTeacherId)
          .toList();
    } else {
      relevantLogs = _sessionLogs;
    }

    if (_activeFilter == 'all') {
      // Collect sorted unique dates across relevant logs
      final allDatesSet = <DateTime>{};
      for (final log in relevantLogs) {
        allDatesSet.add(
          DateTime(
            log.loginAt.year,
            log.loginAt.month,
            log.loginAt.day,
          ),
        );
      }
      final sortedDates = allDatesSet.toList()..sort((a, b) => a.compareTo(b));

      List<DateTime> displayDates;
      if (sortedDates.isEmpty) {
        displayDates = List.generate(
          7,
          (i) => DateTime(
            currentNow.year,
            currentNow.month,
            currentNow.day,
          ).subtract(Duration(days: 6 - i)),
        );
      } else if (sortedDates.length == 1) {
        final singleDate = sortedDates.first;
        displayDates = List.generate(
          7,
          (i) => singleDate.subtract(Duration(days: 6 - i)),
        );
      } else {
        final firstDate = sortedDates.first;
        final lastDate = sortedDates.last;
        final spanDays = lastDate.difference(firstDate).inDays;
        if (spanDays <= 14) {
          // Generate continuous calendar days so the timeline does not skip dates
          displayDates = List.generate(
            spanDays + 1,
            (i) => firstDate.add(Duration(days: i)),
          );
        } else if (sortedDates.length > 10) {
          displayDates = sortedDates.sublist(sortedDates.length - 10);
        } else {
          displayDates = sortedDates;
        }
      }

      return targetTeachers.map((teacher) {
        final teacherLogs = relevantLogs
            .where((s) => s.userId == teacher.id)
            .toList();
        final points = displayDates.map((date) {
          int sec = 0;
          for (final log in teacherLogs) {
            if (log.loginAt.year == date.year &&
                log.loginAt.month == date.month &&
                log.loginAt.day == date.day) {
              sec += _effectiveSessionSeconds(log, currentNow);
            }
          }
          // Strictly enforce 24h (86,400s) daily ceiling per teacher
          sec = sec.clamp(0, _maxDailyDurationSeconds);
          final hoursVal = (sec / 3600.0).clamp(0.0, 24.0);
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

    if (_activeFilter == 'month') {
      final totalDays = DateTime(currentNow.year, currentNow.month + 1, 0).day;
      final upToDay = currentNow.day.clamp(1, totalDays);
      final displayDates = List.generate(
        upToDay,
        (i) => DateTime(currentNow.year, currentNow.month, i + 1),
      );

      return targetTeachers.map((teacher) {
        final teacherLogs = relevantLogs
            .where((s) => s.userId == teacher.id)
            .toList();
        final points = displayDates.map((dayDate) {
          int sec = 0;
          for (final log in teacherLogs) {
            if (log.loginAt.year == dayDate.year &&
                log.loginAt.month == dayDate.month &&
                log.loginAt.day == dayDate.day) {
              sec += _effectiveSessionSeconds(log, currentNow);
            }
          }
          sec = sec.clamp(0, _maxDailyDurationSeconds);
          final hoursVal = (sec / 3600.0).clamp(0.0, 24.0);
          final dateLabel = '${_shortMonth(dayDate.month)} ${dayDate.day}';
          return _ChartPoint(
            label: dateLabel,
            value: hoursVal,
            totalSeconds: sec,
            teacherId: teacher.id,
            teacherName: teacher.name,
            date: dayDate,
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
      final monday = DateTime(
        currentNow.year,
        currentNow.month,
        currentNow.day,
      ).subtract(Duration(days: currentNow.weekday - 1));

      return targetTeachers.map((teacher) {
        final teacherLogs = relevantLogs
            .where((s) => s.userId == teacher.id)
            .toList();
        final points = List.generate(7, (weekdayIdx) {
          final dayDate = monday.add(Duration(days: weekdayIdx));
          int sec = 0;
          for (final log in teacherLogs) {
            // Strictly match the EXACT calendar date of this week
            if (log.loginAt.year == dayDate.year &&
                log.loginAt.month == dayDate.month &&
                log.loginAt.day == dayDate.day) {
              sec += _effectiveSessionSeconds(log, currentNow);
            }
          }
          // Strictly enforce 24h (86,400s) daily ceiling per teacher
          sec = sec.clamp(0, _maxDailyDurationSeconds);
          final hoursVal = (sec / 3600.0).clamp(0.0, 24.0);
          return _ChartPoint(
            label: '${days[weekdayIdx]} ${dayDate.day}',
            value: hoursVal,
            totalSeconds: sec,
            teacherId: teacher.id,
            teacherName: teacher.name,
            date: dayDate,
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

    // Hourly buckets (8 AM to 6 PM) for 'today' and 'custom'
    final targetDate = _activeFilter == 'custom' && _selectedCustomDate != null
        ? _selectedCustomDate!
        : currentNow;
    final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final hours = ['8 AM', '10 AM', '12 PM', '2 PM', '4 PM', '6 PM'];
    final hourBuckets = [8, 10, 12, 14, 16, 18];

    return targetTeachers.map((teacher) {
      final teacherLogs = relevantLogs
          .where((s) => s.userId == teacher.id)
          .toList();
      int remainingDayBudget = _maxDailyDurationSeconds;
      final points = List.generate(6, (i) {
        int sec = 0;
        final bucketHour = hourBuckets[i];
        final nextBucketHour = i < hourBuckets.length - 1
            ? hourBuckets[i + 1]
            : 24;

        for (final log in teacherLogs) {
          final logDay = DateTime(
            log.loginAt.year,
            log.loginAt.month,
            log.loginAt.day,
          );
          if (logDay != targetDay) continue;

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
            sec += _effectiveSessionSeconds(log, currentNow);
          }
        }

        // Enforce 24h daily ceiling across all buckets of the day
        sec = sec.clamp(0, remainingDayBudget);
        remainingDayBudget = (remainingDayBudget - sec).clamp(
          0,
          _maxDailyDurationSeconds,
        );

        final hoursVal = (sec / 3600.0).clamp(0.0, 24.0);
        return _ChartPoint(
          label: hours[i],
          value: hoursVal,
          totalSeconds: sec,
          teacherId: teacher.id,
          teacherName: teacher.name,
          date: targetDay,
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
              : () {
                  final sortedSummaries =
                      List<TeacherWorkloadSummary>.from(_workloadSummaries)
                        ..sort((a, b) {
                          final aIsNaruto =
                              a.teacherName.toLowerCase().contains('naruto');
                          final bIsNaruto =
                              b.teacherName.toLowerCase().contains('naruto');
                          if (aIsNaruto && !bIsNaruto) return -1;
                          if (!aIsNaruto && bIsNaruto) return 1;

                          final aIsJhon =
                              a.teacherName.toLowerCase().contains('jhon') ||
                              a.teacherName.toLowerCase().contains('calantina');
                          final bIsJhon =
                              b.teacherName.toLowerCase().contains('jhon') ||
                              b.teacherName.toLowerCase().contains('calantina');
                          if (aIsJhon && !bIsJhon) return -1;
                          if (!aIsJhon && bIsJhon) return 1;

                          return a.teacherName.compareTo(b.teacherName);
                        });

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: sortedSummaries.map((w) {
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
                              } else if (_activeFilter == 'month') {
                                periodLabel = 'This Month Usage:';
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
                );
              }(),
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
                            0: FlexColumnWidth(2.0),
                            1: FlexColumnWidth(1.1),
                            2: FlexColumnWidth(1.3),
                            3: FlexColumnWidth(1.3),
                            4: FlexColumnWidth(1.6),
                            5: FlexColumnWidth(1.7),
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
                                _TableHeaderCell('Logout Method'),
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
                                        ? Text(
                                            '—',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white38
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          )
                                        : Text(
                                            _formatTimestamp(
                                              log.effectiveLogoutAt,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                            ),
                                          ),
                                  ),
                                  // Logout Method
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: isLive
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.catGreen
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color:
                                                            AppTheme.catGreen,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Online Now',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.catGreen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : _buildLogoutReasonBadge(
                                            log.logoutReason,
                                            isDark,
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

  Widget _buildLogoutReasonBadge(String? reason, bool isDark) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (reason) {
      case 'manual':
        bg = isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
            : const Color(0xFFDBEAFE);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        icon = LucideIcons.logOut;
        label = 'Manual Logout';
        break;
      case 'inactivity':
      case 'inactivity_timeout':
        bg = isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.35)
            : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
        icon = LucideIcons.clock;
        label = 'Inactivity';
        break;
      case 'terminated':
      case 'app_closed':
      case 'session_superseded':
      default:
        bg = isDark
            ? const Color(0xFF334155).withValues(alpha: 0.4)
            : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        icon = LucideIcons.power;
        label = 'Terminated';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
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
                    _skeletonBar(
                      width: 300,
                      height: 24,
                      borderRadius: 8,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _skeletonBar(
                      width: 400,
                      height: 14,
                      borderRadius: 6,
                      isDark: isDark,
                    ),
                  ],
                ),
                _skeletonBar(
                  width: 280,
                  height: 38,
                  borderRadius: 10,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Overview KPI Cards Skeleton
          Row(
            children: [
              Expanded(
                child: _buildMetricCardSkeleton(cardBg, borderColor, isDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCardSkeleton(cardBg, borderColor, isDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCardSkeleton(cardBg, borderColor, isDark),
              ),
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
            child: _skeletonBar(
              width: 280,
              height: 18,
              borderRadius: 6,
              isDark: isDark,
            ),
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

  static Widget _skeletonCircle({required double size, bool isDark = false}) {
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
  final String? selectedTeacherId;
  final DateTime? selectedCustomDate;
  final ValueChanged<String?>? onTeacherSelected;

  const _TeacherActivityCurveChart({
    super.key,
    required this.isDark,
    this.seriesList = const [],
    this.activeFilter = 'today',
    this.selectedTeacherId,
    this.selectedCustomDate,
    this.onTeacherSelected,
  }) : points = const [],
       lineColor = AppTheme.catGreen;

  @override
  State<_TeacherActivityCurveChart> createState() =>
      _TeacherActivityCurveChartState();
}

class _TeacherActivityCurveChartState extends State<_TeacherActivityCurveChart>
    with TickerProviderStateMixin {
  int? _hoveredPointIndex;
  int? _hoveredSeriesIndex;
  late final AnimationController _hoverAnimController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _entranceAnimController;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _entranceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceAnimController,
      curve: Curves.easeOutCubic,
    );
    _entranceAnimController.forward();

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
  void didUpdateWidget(covariant _TeacherActivityCurveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger entrance animation when user changes filter, custom date,
    // selected teacher, or when new series data arrives
    final filterChanged = oldWidget.activeFilter != widget.activeFilter ||
        oldWidget.selectedTeacherId != widget.selectedTeacherId ||
        oldWidget.selectedCustomDate != widget.selectedCustomDate;
    final seriesChanged = oldWidget.seriesList != widget.seriesList;

    if (filterChanged || seriesChanged) {
      _hoveredPointIndex = null;
      _hoveredSeriesIndex = null;
      _entranceAnimController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _entranceAnimController.dispose();
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
      return Container(
        height: 230,
        alignment: Alignment.center,
        child: Text(
          'No activity recorded for this period',
          style: TextStyle(
            fontSize: 12.5,
            color: widget.isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    final pointsCount = effectiveSeries.first.points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const leftPadding = 42.0;
              const rightPadding = 18.0;
              const topPadding = 20.0;
              const bottomPadding = 26.0;

              return MouseRegion(
                onHover: (event) {
                  final x = event.localPosition.dx;
                  final y = event.localPosition.dy;
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  // If mouse moves outside active plot region, clear hover immediately
                  if (x < leftPadding - 16 ||
                      x > width - rightPadding + 16 ||
                      y < topPadding - 12 ||
                      y > height - bottomPadding + 14) {
                    if (_hoveredPointIndex != null) {
                      setState(() {
                        _hoveredPointIndex = null;
                        _hoveredSeriesIndex = null;
                      });
                      _hoverAnimController.reverse();
                    }
                    return;
                  }

                  final innerWidth = width - leftPadding - rightPadding;
                  final dxPerPoint = pointsCount > 1
                      ? innerWidth / (pointsCount - 1)
                      : innerWidth;

                  final nearestPointIndex = ((x - leftPadding) / dxPerPoint)
                      .round()
                      .clamp(0, pointsCount - 1);

                  // If multiple series, determine which series line is closest in Y
                  int nearestSeriesIndex = 0;
                  if (effectiveSeries.length > 1) {
                    double minDiff = double.infinity;
                    final chartHeight =
                        constraints.maxHeight - topPadding - bottomPadding;
                    double peakVal = 0.0;
                    for (final s in effectiveSeries) {
                      for (final p in s.points) {
                        if (p.value > peakVal) peakVal = p.value;
                      }
                    }
                    final double ceiling;
                    if (peakVal <= 2.5) {
                      ceiling = 3.0;
                    } else if (peakVal <= 5.0) {
                      ceiling = 6.0;
                    } else if (peakVal <= 7.5) {
                      ceiling = 9.0;
                    } else if (peakVal <= 10.0) {
                      ceiling = 12.0;
                    } else if (peakVal <= 15.0) {
                      ceiling = 18.0;
                    } else {
                      ceiling = 24.0;
                    }

                    for (int sIdx = 0; sIdx < effectiveSeries.length; sIdx++) {
                      final p = effectiveSeries[sIdx].points[nearestPointIndex];
                      final normalizedY = (p.value / ceiling).clamp(0.0, 1.0);
                      final ptY = topPadding + chartHeight * (1.0 - normalizedY);
                      final diff = (y - ptY).abs();
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
                  animation: Listenable.merge([
                    _entranceAnimation,
                    _scaleAnimation,
                  ]),
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
                        entranceProgress: _entranceAnimation.value,
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
                      color: series.color.withValues(
                        alpha: widget.isDark ? 0.14 : 0.08,
                      ),
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
  final double entranceProgress;

  _CurveChartPainter({
    required this.isDark,
    this.lineColor = AppTheme.catGreen,
    this.seriesList = const [],
    this.activeFilter = 'today',
    this.hoveredPointIndex,
    this.hoveredSeriesIndex,
    this.hoverAnimValue = 0.0,
    this.entranceProgress = 1.0,
  }) : hoveredIndex = null,
       points = const [];

  /// Generates a smooth natural curved path using Monotone Cubic Splines (Fritsch-Carlson)
  /// to eliminate straight-line segments while preventing overshoot or dipping below zero.
  static Path _buildSmoothCurvedPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;

    if (points.length == 2) {
      final p0 = points[0];
      final p1 = points[1];
      final dx = (p1.dx - p0.dx) / 2;
      path.cubicTo(p0.dx + dx, p0.dy, p1.dx - dx, p1.dy, p1.dx, p1.dy);
      return path;
    }

    final n = points.length;
    final deltas = List<double>.filled(n - 1, 0.0);
    final m = List<double>.filled(n, 0.0);

    for (int i = 0; i < n - 1; i++) {
      final dx = points[i + 1].dx - points[i].dx;
      deltas[i] = dx.abs() > 1e-6 ? (points[i + 1].dy - points[i].dy) / dx : 0.0;
    }

    m[0] = deltas[0];
    m[n - 1] = deltas[n - 2];

    for (int i = 1; i < n - 1; i++) {
      if (deltas[i - 1] * deltas[i] <= 0) {
        m[i] = 0;
      } else {
        m[i] = (deltas[i - 1] + deltas[i]) / 2;
      }
    }

    for (int i = 0; i < n - 1; i++) {
      if (deltas[i].abs() < 1e-6) {
        m[i] = 0;
        m[i + 1] = 0;
      } else {
        final a = m[i] / deltas[i];
        final b = m[i + 1] / deltas[i];
        final h = a * a + b * b;
        if (h > 9.0) {
          final t = 3.0 / math.sqrt(h);
          m[i] = t * a * deltas[i];
          m[i + 1] = t * b * deltas[i];
        }
      }
    }

    for (int i = 0; i < n - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final dx = p1.dx - p0.dx;
      final cp1 = Offset(p0.dx + dx / 3, p0.dy + m[i] * dx / 3);
      final cp2 = Offset(p1.dx - dx / 3, p1.dy - m[i + 1] * dx / 3);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    return path;
  }

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

    const leftPadding = 42.0;
    const rightPadding = 18.0;
    const bottomPadding = 26.0;
    const topPadding = 20.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final innerWidth = size.width - leftPadding - rightPadding;
    final baseY = size.height - bottomPadding;

    double peakVal = 0.0;
    for (final s in effectiveSeries) {
      for (final p in s.points) {
        if (p.value > peakVal) peakVal = p.value;
      }
    }
    final double ceiling;
    if (peakVal <= 2.5) {
      ceiling = 3.0;
    } else if (peakVal <= 5.0) {
      ceiling = 6.0;
    } else if (peakVal <= 7.5) {
      ceiling = 9.0;
    } else if (peakVal <= 10.0) {
      ceiling = 12.0;
    } else if (peakVal <= 15.0) {
      ceiling = 18.0;
    } else {
      ceiling = 24.0;
    }

    // Horizontal grid lines and Y-axis level labels
    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final yAxisStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
    );

    for (int i = 0; i <= 3; i++) {
      final y = topPadding + (chartHeight / 3.0) * i;

      // Draw grid line across the plot area
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y-axis scale value label (e.g. 12h, 8h, 4h, 0h)
      final levelVal = ceiling * (1.0 - (i / 3.0));
      final levelText = '${levelVal.round()}h';
      final tpLevel = TextPainter(
        text: TextSpan(text: levelText, style: yAxisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpLevel.paint(
        canvas,
        Offset(leftPadding - tpLevel.width - 8, y - tpLevel.height / 2),
      );
    }

    final pointsCount = effectiveSeries.first.points.length;
    final dx = pointsCount > 1 ? innerWidth / (pointsCount - 1) : innerWidth;

    // Collect coordinates for every series with entrance animation applied
    final allSeriesCoords = <List<Offset>>[];

    for (int sIdx = 0; sIdx < effectiveSeries.length; sIdx++) {
      final series = effectiveSeries[sIdx];
      final pointCoords = <Offset>[];

      for (int i = 0; i < pointsCount; i++) {
        final x = leftPadding + (dx * i);
        final normalizedY = (series.points[i].value / ceiling).clamp(0.0, 1.0);
        final targetY = topPadding + chartHeight * (1.0 - normalizedY);
        // Animate smoothly upward from baseY
        final animatedY = baseY - (baseY - targetY) * entranceProgress;
        pointCoords.add(Offset(x, animatedY));
      }
      allSeriesCoords.add(pointCoords);

      if (pointCoords.isNotEmpty) {
        // Natural smooth curved spline
        final curvePath = _buildSmoothCurvedPath(pointCoords);

        // Fill path under the curve
        final fillPath = Path.from(curvePath);
        fillPath.lineTo(pointCoords.last.dx, baseY);
        fillPath.lineTo(pointCoords.first.dx, baseY);
        fillPath.close();

        // Gradient fill under curve with glassmorphic transparency
        final gradientPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              series.color.withValues(
                alpha: (isDark ? 0.28 : 0.16) * entranceProgress,
              ),
              series.color.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTWH(leftPadding, topPadding, innerWidth, chartHeight),
          );
        canvas.drawPath(fillPath, gradientPaint);

        // Curve stroke with smooth round cap & join
        final strokePaint = Paint()
          ..color = series.color.withValues(alpha: entranceProgress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveSeries.length == 1 ? 3.0 : 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(curvePath, strokePaint);
      }
    }

    // Draw Points on each curve
    for (int sIdx = 0; sIdx < effectiveSeries.length; sIdx++) {
      final series = effectiveSeries[sIdx];
      final coords = allSeriesCoords[sIdx];

      for (int i = 0; i < coords.length; i++) {
        final pt = coords[i];
        final isHovered =
            (hoveredPointIndex == i) && (hoveredSeriesIndex == sIdx);

        if (isHovered && hoverAnimValue > 0) {
          // Animated glowing ring on hover
          final outerGlowRadius = 5.0 + (4.0 * hoverAnimValue);
          canvas.drawCircle(
            pt,
            outerGlowRadius,
            Paint()
              ..color = series.color.withValues(alpha: 0.30 * hoverAnimValue),
          );

          // Center ring
          canvas.drawCircle(
            pt,
            6.5,
            Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white,
          );
          // Inner dot
          canvas.drawCircle(pt, 4.5, Paint()..color = series.color);
        } else {
          // Normal point
          canvas.drawCircle(
            pt,
            4.5,
            Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white,
          );
          canvas.drawCircle(
            pt,
            3.0,
            Paint()..color = series.color,
          );
        }
      }
    }

    // CRITICAL: Details tooltip box appears ONLY when hovering cursor over a point!
    // NO idle fallback to peak point!
    final int? targetPointIdx = hoveredPointIndex;
    final int targetSeriesIdx = hoveredSeriesIndex ?? 0;

    if (targetPointIdx != null &&
        targetSeriesIdx < effectiveSeries.length &&
        targetSeriesIdx < allSeriesCoords.length &&
        targetPointIdx < effectiveSeries[targetSeriesIdx].points.length &&
        targetPointIdx < allSeriesCoords[targetSeriesIdx].length) {
      final targetSeries = effectiveSeries[targetSeriesIdx];
      final targetPoint = targetSeries.points[targetPointIdx];
      final pt = allSeriesCoords[targetSeriesIdx][targetPointIdx];

      final durationStr =
          _AdminActivityAnalyticsTabState._formatTooltipDuration(
            targetPoint.totalSeconds,
          );

      final teacherName = targetPoint.teacherName ?? targetSeries.teacherName;

      // Text Painters
      final nameSpan = TextSpan(
        text: teacherName,
        style: TextStyle(
          fontSize: 11,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: targetSeries.color,
        ),
      );
      final tpTime = TextPainter(
        text: timeSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Show the date label if available
      TextPainter? tpDate;
      String? dateText;
      if (targetPoint.date != null) {
        final d = targetPoint.date!;
        dateText =
            '${_AdminActivityAnalyticsTabState._shortWeekday(d.weekday)}, ${_AdminActivityAnalyticsTabState._shortMonth(d.month)} ${d.day}';
      } else if (activeFilter == 'all') {
        dateText = targetPoint.label;
      }
      if (dateText != null) {
        tpDate = TextPainter(
          text: TextSpan(
            text: dateText,
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

      final badgeWidth = maxContentWidth + 24;
      final badgeHeight =
          tpName.height +
          tpTime.height +
          (tpDate != null ? tpDate.height + 4 : 0) +
          16;

      // Check whether tooltip fits comfortably above the point
      final fitsAbove = (pt.dy - badgeHeight - 16) >= 0;
      final badgeCenterY = fitsAbove
          ? pt.dy - (badgeHeight / 2) - 12
          : pt.dy + (badgeHeight / 2) + 12;

      final badgeCenterX = pt.dx.clamp(
        badgeWidth / 2 + 6,
        size.width - badgeWidth / 2 - 6,
      );

      canvas.save();
      canvas.translate(badgeCenterX, badgeCenterY);

      // Smooth scale spring animation on hover
      final scale = 0.85 + (0.15 * hoverAnimValue.clamp(0.0, 1.0));
      canvas.scale(scale, scale);

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: badgeWidth,
          height: badgeHeight,
        ),
        const Radius.circular(10),
      );

      // Glassmorphism soft shadow
      canvas.drawRRect(
        badgeRect.shift(const Offset(0, 4)),
        Paint()
          ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Glowing halo matching teacher color
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = targetSeries.color.withValues(
            alpha: isDark ? 0.22 : 0.14,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // Frosted glass background
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.95),
      );

      // Glowing border with teacher color
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = targetSeries.color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Caret pointing towards circle dot
      final caretPath = Path();
      final caretX = (pt.dx - badgeCenterX).clamp(
        -badgeWidth / 2 + 10,
        badgeWidth / 2 - 10,
      );
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
        Paint()
          ..color = isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawPath(
        caretPath,
        Paint()
          ..color = targetSeries.color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Paint texts inside badge
      double currY = -badgeHeight / 2 + 7;
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
    final int step = pointsCount > 22
        ? 4
        : pointsCount > 13
            ? 2
            : 1;

    for (int i = 0; i < firstPoints.length; i++) {
      final isEdge = (i == 0 || i == firstPoints.length - 1);
      if (!isEdge && (i % step != 0)) continue;

      final x = leftPadding + (dx * i);
      final tp = TextPainter(
        text: TextSpan(text: firstPoints[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final drawX = (x - (tp.width / 2)).clamp(
        leftPadding - 8,
        size.width - rightPadding - tp.width + 8,
      );

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
        oldDelegate.entranceProgress != entranceProgress ||
        oldDelegate.activeFilter != activeFilter;
  }
}

class _ChartGridPlaceholderPainter extends CustomPainter {
  final bool isDark;

  const _ChartGridPlaceholderPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 42.0;
    const rightPadding = 18.0;
    const topPadding = 20.0;
    const bottomPadding = 26.0;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final yAxisStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
    );

    final levels = ['18h', '12h', '6h', '0h'];
    for (int i = 0; i <= 3; i++) {
      final y = topPadding + (chartHeight / 3.0) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final tpLevel = TextPainter(
        text: TextSpan(text: levels[i], style: yAxisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpLevel.paint(
        canvas,
        Offset(leftPadding - tpLevel.width - 8, y - tpLevel.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartGridPlaceholderPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

// =========================================================================
// Component Mastery Style: Teacher Online Status Card (Inspired by Image 1)
// =========================================================================
class _TeacherActivityDonutCard extends StatefulWidget {
  final bool isDark;
  final int activeNowCount;
  final int totalTrackedTeachers;

  const _TeacherActivityDonutCard({
    required this.isDark,
    required this.activeNowCount,
    required this.totalTrackedTeachers,
  });

  @override
  State<_TeacherActivityDonutCard> createState() =>
      _TeacherActivityDonutCardState();
}

class _TeacherActivityDonutCardState extends State<_TeacherActivityDonutCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _donutAnimController;
  late final Animation<double> _donutAnimation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _donutAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _donutAnimation = CurvedAnimation(
      parent: _donutAnimController,
      curve: Curves.easeOutCubic,
    );
    _donutAnimController.forward();
  }

  @override
  void dispose() {
    _donutAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idleCount =
        math.max(0, widget.totalTrackedTeachers - widget.activeNowCount);
    final totalSafe = math.max(1, widget.totalTrackedTeachers);
    final onlinePct = widget.totalTrackedTeachers > 0
        ? ((widget.activeNowCount / widget.totalTrackedTeachers) * 100).round()
        : 0;
    final offlinePct = widget.totalTrackedTeachers > 0 ? 100 - onlinePct : 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header matching Image 1
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.catGreen.withValues(
                    alpha: widget.isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.pieChart,
                  size: 16,
                  color: AppTheme.catGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                    const SizedBox(height: 2),
                    Text(
                      'Current teacher login status and system usage',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart + Component status rows
          LayoutBuilder(
            builder: (context, constraints) {
              final donutWidget = SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _donutAnimation,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(140, 140),
                          painter: _ActivityDonutPainter(
                            slices: [
                              _ActivityDonutSliceData(
                                count: widget.activeNowCount,
                                pct: onlinePct.toDouble(),
                                color: AppTheme.catGreen,
                              ),
                              _ActivityDonutSliceData(
                                count: idleCount,
                                pct: offlinePct.toDouble(),
                                color: widget.isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1),
                              ),
                            ],
                            progress: _donutAnimation.value,
                            strokeWidth: 14,
                            isDark: widget.isDark,
                            hoveredIndex: _hoveredIndex,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Online Rate',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                color: widget.isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '$onlinePct%',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '${widget.activeNowCount}/${widget.totalTrackedTeachers} Online',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              );

              final rightColumnWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildComponentStatusRow(
                    title: 'Online Now',
                    countText: '${widget.activeNowCount} Faculty',
                    badgeText: '$onlinePct% Active',
                    progressValue: (widget.activeNowCount / totalSafe),
                    color: AppTheme.catGreen,
                    initials: 'ON',
                    isDark: widget.isDark,
                    isHovered: _hoveredIndex == 0,
                    onEnter: () => setState(() => _hoveredIndex = 0),
                    onExit: () => setState(() => _hoveredIndex = null),
                  ),
                  const SizedBox(height: 10),
                  _buildComponentStatusRow(
                    title: 'Offline',
                    countText: '$idleCount Faculty',
                    badgeText: '$offlinePct% Idle',
                    progressValue: (idleCount / totalSafe),
                    color: widget.isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    initials: 'OFF',
                    isDark: widget.isDark,
                    isHovered: _hoveredIndex == 1,
                    onEnter: () => setState(() => _hoveredIndex = 1),
                    onExit: () => setState(() => _hoveredIndex = null),
                  ),
                ],
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  children: [
                    Center(child: donutWidget),
                    const SizedBox(height: 14),
                    rightColumnWidget,
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    donutWidget,
                    const SizedBox(width: 16),
                    Expanded(child: rightColumnWidget),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComponentStatusRow({
    required String title,
    required String countText,
    required String badgeText,
    required double progressValue,
    required Color color,
    required String initials,
    required bool isDark,
    required bool isHovered,
    required VoidCallback onEnter,
    required VoidCallback onExit,
  }) {
    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isHovered
              ? color.withValues(alpha: isDark ? 0.16 : 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHovered
                ? color.withValues(alpha: isDark ? 0.6 : 0.45)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
            width: isHovered ? 1.5 : 1.0,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            countText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: color.withValues(
                                  alpha: isDark ? 0.4 : 0.25,
                                ),
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progressValue.clamp(0.0, 1.0),
                      minHeight: 3.5,
                      backgroundColor: isDark
                          ? Colors.white10
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityDonutSliceData {
  final int count;
  final double pct;
  final Color color;

  const _ActivityDonutSliceData({
    required this.count,
    required this.pct,
    required this.color,
  });
}

class _ActivityDonutPainter extends CustomPainter {
  final List<_ActivityDonutSliceData> slices;
  final double progress;
  final double strokeWidth;
  final bool isDark;
  final int? hoveredIndex;

  _ActivityDonutPainter({
    required this.slices,
    required this.progress,
    required this.strokeWidth,
    required this.isDark,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track Ring
    final trackPaint = Paint()
      ..color = isDark ? Colors.white10 : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (slices.isEmpty) return;

    var startAngle = -math.pi / 2;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      if (slice.pct <= 0) continue;
      final sweepAngle = (slice.pct / 100) * 2 * math.pi * progress;

      final isHovered = hoveredIndex == i;
      final effectiveStroke = isHovered ? strokeWidth + 3.0 : strokeWidth;

      if (isHovered) {
        final glowPaint = Paint()
          ..color = slice.color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveStroke + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      final slicePaint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStroke
        ..strokeCap = StrokeCap.round;

      if (sweepAngle > 0.02) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle - 0.02,
          false,
          slicePaint,
        );
      }

      startAngle += (slice.pct / 100) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityDonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.slices != slices ||
        oldDelegate.isDark != isDark ||
        oldDelegate.hoveredIndex != hoveredIndex;
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
