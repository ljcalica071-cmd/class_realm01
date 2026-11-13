import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/models/admin_portal_models.dart';
import 'package:class_realm/core/theme/app_theme.dart';
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
  String _activeFilter = 'today'; // 'today', 'week', 'month', 'all'
  int _currentHistoryPage = 1;
  static const int _historyItemsPerPage = 10;
  String? _selectedTeacherId; // null = all teachers

  // Fixed Status Indicators across the timeline and analytics.
  // Teachers must NEVER be assigned any of these colors to prevent confusion.
  static const Color statusOnlineColor = AppTheme.catGreen; // Emerald (#10B981)
  static const Color statusManualLogoutColor = Color(0xFF2563EB); // Royal Blue (#2563EB)
  static const Color statusInactivityColor = Color(0xFFF59E0B); // Amber (#F59E0B)
  static const Color statusTerminatedColor = Color(0xFF64748B); // Slate Gray (#64748B)

  /// Distinct, non-colliding palette dedicated EXCLUSIVELY to Teachers.
  /// Strictly excludes Green (Online), Blue (Manual Logout), Amber (Inactivity), and Slate Gray (Terminated).
  static const List<Color> _teacherColorPalette = [
    Color(0xFF8B5CF6), // 0: Vivid Purple / Violet
    Color(0xFF06B6D4), // 1: Cyan / Electric Cyan
    Color(0xFFF43F5E), // 2: Coral / Rose
    Color(0xFF14B8A6), // 3: Teal / Deep Sea Green (distinct from catGreen)
    Color(0xFFEC4899), // 4: Pink / Magenta
    Color(0xFFD97706), // 5: Burnt Orange (distinct from status Amber)
    Color(0xFF6366F1), // 6: Indigo
    Color(0xFF84CC16), // 7: Lime Green
    Color(0xFFA855F7), // 8: Bright Purple
    Color(0xFFE11D48), // 9: Crimson
    Color(0xFF0D9488), // 10: Deep Teal
    Color(0xFFDB2777), // 11: Deep Rose
  ];

  static final Map<String, Color> _cachedTeacherColors = {};

  /// Returns a permanent, deterministic color for each teacher that NEVER changes across filters
  /// and NEVER collides with another teacher or with the 4 status indicators (Online, Manual Logout, Inactivity, Terminated).
  static Color getTeacherColor(String teacherId, [String? teacherName]) {
    if (_cachedTeacherColors.containsKey(teacherId)) {
      return _cachedTeacherColors[teacherId]!;
    }

    // 1. Persistent storage in AppDataCache
    try {
      final savedRegistry = AppDataCache.instance
          .getCached<Map<String, dynamic>>(
            'admin_teacher_color_registry_v2',
            (raw) => Map<String, dynamic>.from(raw as Map),
          );
      if (savedRegistry != null && savedRegistry.containsKey(teacherId)) {
        final idx = (savedRegistry[teacherId] as num).toInt();
        final color = _teacherColorPalette[idx % _teacherColorPalette.length];
        _cachedTeacherColors[teacherId] = color;
        return color;
      }
    } catch (_) {}

    // 2. Deterministically pick next available distinct color from palette
    final usedColors = _cachedTeacherColors.values.toSet();
    Color? assignedColor;
    int assignedIdx = -1;
    for (int i = 0; i < _teacherColorPalette.length; i++) {
      if (!usedColors.contains(_teacherColorPalette[i])) {
        assignedColor = _teacherColorPalette[i];
        assignedIdx = i;
        break;
      }
    }

    // If more teachers than palette length, cycle deterministically by hash
    if (assignedColor == null) {
      assignedIdx = teacherId.hashCode.abs() % _teacherColorPalette.length;
      assignedColor = _teacherColorPalette[assignedIdx];
    }

    _cachedTeacherColors[teacherId] = assignedColor;

    try {
      final savedRegistry =
          AppDataCache.instance.getCached<Map<String, dynamic>>(
            'admin_teacher_color_registry_v2',
            (raw) => Map<String, dynamic>.from(raw as Map),
          ) ??
          <String, dynamic>{};
      savedRegistry[teacherId] = assignedIdx;
      unawaited(
        AppDataCache.instance.setCache(
          'admin_teacher_color_registry_v2',
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

  String _getCacheKey() => _activeFilter;

  void _switchFilter(String key) {
    if (_activeFilter == key) return;

    final cachedLogs = _sessionLogsCache[key];
    final cachedWorkloads = _workloadCache[key];

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
        final restored = _restoreCachedData(key);
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
    final cacheKey = targetFilter;

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
      if (mounted &&
          thisSequence == _loadSequence &&
          _activeFilter == targetFilter) {
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
      if (mounted &&
          thisSequence == _loadSequence &&
          _activeFilter == targetFilter) {
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
      final cacheKey = filter;
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
        _TeacherInfo(
          id: 'faculty',
          name: 'Faculty',
          color: Color(0xFF8B5CF6),
        ),
      ];
    }

    final teachers = teachersMap.values.toList();
    // Deterministic sort: Naruto first, Jhon second, then alphabetical
    teachers.sort((a, b) {
      final aIsNaruto = a.name.toLowerCase().contains('naruto');
      final bIsNaruto = b.name.toLowerCase().contains('naruto');
      if (aIsNaruto && !bIsNaruto) return -1;
      if (!aIsNaruto && bIsNaruto) return 1;

      final aIsJhon =
          a.name.toLowerCase().contains('jhon') ||
          a.name.toLowerCase().contains('calantina');
      final bIsJhon =
          b.name.toLowerCase().contains('jhon') ||
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
      return 'Cumulative faculty engagement breakdown across all records';
    } else if (_activeFilter == 'month') {
      return 'Weekly faculty engagement breakdown this month (${_shortMonth(DateTime.now().month)})';
    } else if (_activeFilter == 'week') {
      return 'Daily faculty engagement breakdown this week (Monday – Sunday)';
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
          setState(
            () => _selectedTeacherId =
                (teacherId == null || teacherId == '__ALL_FACULTY__')
                ? null
                : teacherId,
          );
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

  /// Computes the accurate local [start, end] interval for a single session log.
  /// - Active sessions advance in real-time up to [currentNow] (capped at +30m if stale).
  /// - Closed sessions clamp to recorded duration and +30m inactivity bound, and never bleed past midnight.
  static DateTimeRange _effectiveSessionInterval(
    UserSessionLog log,
    DateTime currentNow,
  ) {
    final start = log.loginAt.toLocal();
    final nowLocal = currentNow.toLocal();
    DateTime end;

    if (log.isActive) {
      final lastActiveLocal = log.lastActiveAt.toLocal();
      if (nowLocal.difference(lastActiveLocal).inMinutes > 35) {
        end = lastActiveLocal.add(const Duration(minutes: 30));
      } else {
        end = nowLocal;
      }
    } else {
      end = (log.logoutAt ?? log.lastActiveAt).toLocal();
      if (log.durationSeconds > 0) {
        final durEnd = start.add(Duration(seconds: log.durationSeconds));
        if (durEnd.isBefore(end)) {
          end = durEnd;
        }
      }
      final lastActiveLocal = log.lastActiveAt.toLocal();
      final maxInactivityEnd = lastActiveLocal.add(const Duration(minutes: 30));
      if (end.isAfter(maxInactivityEnd) &&
          (log.logoutReason == 'inactivity' ||
              log.logoutReason == 'terminated')) {
        end = maxInactivityEnd;
      }
    }

    final nextMidnight = DateTime(start.year, start.month, start.day + 1);
    if (end.isAfter(nextMidnight)) {
      end = nextMidnight;
    }
    if (end.isBefore(start)) {
      end = start;
    }
    return DateTimeRange(start: start, end: end);
  }

  /// Merges overlapping or adjacent [DateTimeRange] intervals so parallel/duplicate
  /// sessions are never double-counted.
  static List<DateTimeRange> _mergeIntervals(List<DateTimeRange> rawIntervals) {
    final valid = rawIntervals.where((r) => r.end.isAfter(r.start)).toList();
    if (valid.isEmpty) return const [];
    valid.sort((a, b) => a.start.compareTo(b.start));

    final merged = <DateTimeRange>[valid.first];
    for (int i = 1; i < valid.length; i++) {
      final current = valid[i];
      final last = merged.last;
      if (!current.start.isAfter(last.end)) {
        final newEnd = current.end.isAfter(last.end) ? current.end : last.end;
        merged[merged.length - 1] = DateTimeRange(
          start: last.start,
          end: newEnd,
        );
      } else {
        merged.add(current);
      }
    }
    return merged;
  }

  /// Returns merged non-overlapping intervals for a single teacher on [dayDate].
  static List<DateTimeRange> _getTeacherMergedDayIntervals(
    List<UserSessionLog> teacherLogs,
    DateTime dayDate,
    DateTime currentNow,
  ) {
    final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final raw = <DateTimeRange>[];

    for (final log in teacherLogs) {
      final interval = _effectiveSessionInterval(log, currentNow);
      if (!interval.end.isAfter(dayStart) || !interval.start.isBefore(dayEnd)) {
        continue;
      }
      final clippedStart = interval.start.isBefore(dayStart)
          ? dayStart
          : interval.start;
      final clippedEnd = interval.end.isAfter(dayEnd) ? dayEnd : interval.end;
      if (clippedEnd.isAfter(clippedStart)) {
        raw.add(DateTimeRange(start: clippedStart, end: clippedEnd));
      }
    }
    return _mergeIntervals(raw);
  }

  /// Calculates exact union seconds for a single teacher on [dayDate] (max 24h).
  static int _calculateTeacherDaySeconds(
    List<UserSessionLog> teacherLogs,
    DateTime dayDate,
    DateTime currentNow,
  ) {
    final merged = _getTeacherMergedDayIntervals(
      teacherLogs,
      dayDate,
      currentNow,
    );
    int total = 0;
    for (final r in merged) {
      total += r.duration.inSeconds;
    }
    return total.clamp(0, _maxDailyDurationSeconds);
  }

  /// Calculates total usage seconds across logs using per-teacher interval union
  /// while strictly enforcing a max of 24 hours (86,400s) per teacher per calendar day.
  static int _calculateCappedTotalSeconds(
    List<UserSessionLog> logs,
    DateTime currentNow,
  ) {
    if (logs.isEmpty) return 0;
    final byTeacherAndDay = <String, List<DateTimeRange>>{};

    for (final s in logs) {
      final interval = _effectiveSessionInterval(s, currentNow);
      if (!interval.end.isAfter(interval.start)) continue;
      final d = interval.start;
      final key = '${s.userId}_${d.year}-${d.month}-${d.day}';
      byTeacherAndDay.putIfAbsent(key, () => <DateTimeRange>[]).add(interval);
    }

    int grandTotal = 0;
    for (final intervals in byTeacherAndDay.values) {
      final merged = _mergeIntervals(intervals);
      int daySec = 0;
      for (final r in merged) {
        daySec += r.duration.inSeconds;
      }
      grandTotal += daySec.clamp(0, _maxDailyDurationSeconds);
    }
    return grandTotal;
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

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final screenW = outerConstraints.maxWidth;
        final double outerPadding = screenW < 600
            ? 14.0
            : (screenW < 900 ? 18.0 : 24.0);

        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(outerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & Filter Bar
                  _buildHeaderAndFilters(context, isDark),
                  SizedBox(height: screenW < 600 ? 16 : 22),

                  // KPI Metric Cards (live-updated via _tickerNotifier)
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _tickerNotifier,
                    builder: (context, liveNow, _) {
                      final liveTotalSeconds = _calculateCappedTotalSeconds(
                        effectiveDisplayLogs,
                        liveNow,
                      );
                      return _buildMetricCardsRow(
                        context,
                        isDark,
                        activeNowCount,
                        totalTrackedTeachers,
                        liveTotalSeconds,
                      );
                    },
                  ),
                  SizedBox(height: screenW < 600 ? 18 : 24),

                  // Visual Analytics Charts Row (Session Timeline + 1h Bars on Today/Custom, Curve Chart on Week/Month/All)
                  _buildAnalyticsChartsRow(
                    context,
                    isDark,
                    activeNowCount,
                    totalTrackedTeachers,
                  ),
                  SizedBox(height: screenW < 600 ? 20 : 28),

                  // Teacher Workload & Total Usage Summary Cards
                  _buildTeacherWorkloadSection(context, isDark),
                  SizedBox(height: screenW < 600 ? 20 : 28),

                  // Live Teacher Session Logs Table / Responsive Cards
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
      },
    );
  }

  // =========================================================================
  // Header and Filter Controls
  // =========================================================================
  Widget _buildHeaderAndFilters(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 820;
        final isMobile = constraints.maxWidth < 520;

        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.chartColumn,
                  size: isMobile ? 20 : 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Teacher Activity & Analytics Hub',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Track how long teachers use the system and view their class workloads.',
              style: TextStyle(
                fontSize: isMobile ? 12.5 : 13.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        );

        final filterBar = Container(
          width: isMobile ? double.infinity : null,
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
              _buildFilterButton('All Records', 'all'),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [headerText, const SizedBox(height: 14), filterBar],
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



  // =========================================================================
  // Overview KPI Metric Cards
  // =========================================================================
  String _getMetricFilterSubtitle() {
    if (_activeFilter == 'today') {
      return 'Recorded today';
    } else if (_activeFilter == 'week') {
      return 'This week (Mon - Sun)';
    } else if (_activeFilter == 'month') {
      return 'This month (${_shortMonth(DateTime.now().month)})';
    }
    return 'All recorded sessions';
  }

  Widget _buildMetricCardsRow(
    BuildContext context,
    bool isDark,
    int activeNowCount,
    int totalTrackedTeachers,
    int totalDurationSeconds,
  ) {
    final theme = Theme.of(context);
    final filterSubtitle = _getMetricFilterSubtitle();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final bool isMobile = maxW < 560;
        final bool isTablet = maxW >= 560 && maxW < 900;

        final double cardWidth;
        if (isMobile) {
          cardWidth = maxW;
        } else if (isTablet) {
          cardWidth = (maxW - 12) / 2;
        } else {
          cardWidth = (maxW - 24) / 3;
        }

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
              width: isTablet ? maxW : cardWidth,
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
    final bool isFilterDataReady = _sessionLogsCache.containsKey(
      currentCacheKey,
    );
    final bool showGraphLoader = _isSwitchingFilter && !isFilterDataReady;
    final bool isTodayTimeline = _activeFilter == 'today';

    final allTeachers = _getTeacherInfoList();
    final List<_TeacherInfo> targetTeachers = _selectedTeacherId != null
        ? (allTeachers
                  .where((t) => t.id == _selectedTeacherId)
                  .toList()
                  .isNotEmpty
              ? allTeachers.where((t) => t.id == _selectedTeacherId).toList()
              : allTeachers)
        : allTeachers;
    final List<UserSessionLog> relevantLogs = _selectedTeacherId != null
        ? _sessionLogs.where((s) => s.userId == _selectedTeacherId).toList()
        : _sessionLogs;

    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final isCompactHeader = cardConstraints.maxWidth < 540;
        final cardPad = cardConstraints.maxWidth < 540 ? 15.0 : 22.0;

        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.catBlue.withValues(alpha: isDark ? 0.2 : 0.1),
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
                      fontSize: isCompactHeader ? 14.5 : 15.5,
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
          ],
        );

        return Container(
          padding: EdgeInsets.all(cardPad),
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
              if (isCompactHeader) ...[
                titleBlock,
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildTeacherFilterMenu(context, isDark),
                ),
              ] else
                Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    _buildTeacherFilterMenu(context, isDark),
                  ],
                ),
              const SizedBox(height: 18),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: showGraphLoader
                    ? _buildGraphLoadingPlaceholder(theme, isDark)
                    : isTodayTimeline
                    ? ValueListenableBuilder<DateTime>(
                        key: ValueKey(
                          'timeline_${_activeFilter}_$_selectedTeacherId',
                        ),
                        valueListenable: _tickerNotifier,
                        builder: (context, liveNow, _) {
                          return _TeacherSessionTimelineAndHourlyView(
                            teachers: targetTeachers,
                            logs: relevantLogs,
                            targetDate: liveNow,
                            isToday: true,
                            currentNow: liveNow,
                            isDark: isDark,
                            selectedTeacherId: _selectedTeacherId,
                            onTeacherSelected: (teacherId) {
                              setState(
                                () => _selectedTeacherId =
                                    _selectedTeacherId == teacherId
                                    ? null
                                    : teacherId,
                              );
                            },
                          );
                        },
                      )
                    : _TeacherEngagementBarChart(
                        key: ValueKey(
                          'barchart_${_activeFilter}_$_selectedTeacherId',
                        ),
                        activeFilter: _activeFilter,
                        teachers: targetTeachers,
                        logs: relevantLogs,
                        currentNow: DateTime.now(),
                        isDark: isDark,
                        selectedTeacherId: _selectedTeacherId,
                        onTeacherSelected: (teacherId) {
                          setState(
                            () => _selectedTeacherId =
                                _selectedTeacherId == teacherId
                                ? null
                                : teacherId,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
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
                          final aIsNaruto = a.teacherName
                              .toLowerCase()
                              .contains('naruto');
                          final bIsNaruto = b.teacherName
                              .toLowerCase()
                              .contains('naruto');
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

                  return LayoutBuilder(
                    builder: (context, wlConstraints) {
                      final maxW = wlConstraints.maxWidth;
                      const double minCardWidth = 240.0;
                      const double spacing = 12.0;

                      // Compute optimal columns and stretch items equally to fill full available width
                      final int columns = math.max(
                        1,
                        ((maxW + spacing) / (minCardWidth + spacing)).floor(),
                      );
                      final double itemWidth = (maxW - (spacing * (columns - 1))) /
                          columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: sortedSummaries.map((w) {
                          final teacherSessions = _sessionLogs
                              .where((s) => s.userId == w.teacherId)
                              .toList();

                          return Container(
                            width: itemWidth,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subjects Handled:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Sections Handled:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
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
                                    final totalSecs =
                                        _calculateCappedTotalSeconds(
                                          teacherSessions,
                                          currentNow,
                                        );

                                    String periodLabel;
                                    if (_activeFilter == 'today') {
                                      periodLabel = 'Today Usage:';
                                    } else if (_activeFilter == 'week') {
                                      periodLabel = 'This Week Usage:';
                                    } else if (_activeFilter == 'month') {
                                      periodLabel = 'This Month Usage:';
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
                    },
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
                        return LayoutBuilder(
                          builder: (context, tableConstraints) {
                            final isCompactTable =
                                tableConstraints.maxWidth < 720;

                            if (isCompactTable) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: pageLogs.map((log) {
                                  final isLive = log.isActive;
                                  final interval = _effectiveSessionInterval(
                                    log,
                                    currentNow,
                                  );
                                  final elapsedSeconds =
                                      interval.duration.inSeconds;

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isDark
                                              ? Colors.white10
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
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
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            isLive
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.catGreen
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          width: 6,
                                                          height: 6,
                                                          child: DecoratedBox(
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: AppTheme
                                                                      .catGreen,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 5),
                                                        Text(
                                                          'Online Now',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: AppTheme
                                                                .catGreen,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : _buildLogoutReasonBadge(
                                                    log.logoutReason,
                                                    isDark,
                                                  ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              'Date: ${_formatDate(log.sessionDate)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                            Text(
                                              'In: ${_formatTimestamp(interval.start)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                            Text(
                                              isLive
                                                  ? 'Out: —'
                                                  : 'Out: ${_formatTimestamp(interval.end)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Time Spent in System:',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: isDark
                                                    ? Colors.white54
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                            Text(
                                              AdminRepository.formatHumanReadableDuration(
                                                elapsedSeconds,
                                              ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                                fontSize: 12.5,
                                                color: isLive
                                                    ? AppTheme.catGreen
                                                    : theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            }

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
                                  final interval = _effectiveSessionInterval(
                                    log,
                                    currentNow,
                                  );
                                  final elapsedSeconds =
                                      interval.duration.inSeconds;

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
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
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
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      // Login Time
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          _formatTimestamp(interval.start),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                          ),
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
                                                _formatTimestamp(interval.end),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: AppTheme
                                                                .catGreen,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Text(
                                                      'Online Now',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppTheme.catGreen,
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
                        );
                      },
                    ),

                    // Bottom Container: Entry count and pagination (Responsive across mobile/tablet/desktop)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Showing ${totalLogs == 0 ? 0 : startIndex + 1} to $endIndex of $totalLogs entries',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (totalPages > 1)
                            Wrap(
                              spacing: 2,
                              runSpacing: 4,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final isNarrow = maxW < 850;
        final isMobile = maxW < 560;
        final pad = isMobile ? 14.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Skeleton
              _SkeletonShimmer(
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skeletonBar(
                            width: math.min(280, maxW - 32),
                            height: 24,
                            borderRadius: 8,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _skeletonBar(
                            width: math.min(360, maxW - 32),
                            height: 14,
                            borderRadius: 6,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          _skeletonBar(
                            width: math.min(280, maxW - 32),
                            height: 38,
                            borderRadius: 10,
                            isDark: isDark,
                          ),
                        ],
                      )
                    : Row(
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
              if (isMobile)
                Column(
                  children: [
                    _buildMetricCardSkeleton(cardBg, borderColor, isDark),
                    const SizedBox(height: 12),
                    _buildMetricCardSkeleton(cardBg, borderColor, isDark),
                    const SizedBox(height: 12),
                    _buildMetricCardSkeleton(cardBg, borderColor, isDark),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCardSkeleton(
                        cardBg,
                        borderColor,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCardSkeleton(
                        cardBg,
                        borderColor,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCardSkeleton(
                        cardBg,
                        borderColor,
                        isDark,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Charts Skeleton Row
              if (isNarrow)
                Column(
                  children: [
                    Container(
                      height: 240,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: _SkeletonShimmer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _skeletonBar(
                              width: math.min(220, maxW - 80),
                              height: 16,
                              isDark: isDark,
                            ),
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
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: _SkeletonShimmer(
                          child: _skeletonCircle(size: 130, isDark: isDark),
                        ),
                      ),
                    ),
                  ],
                )
              else
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
                        child: _SkeletonShimmer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _skeletonBar(
                                width: 220,
                                height: 16,
                                isDark: isDark,
                              ),
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
            ],
          ),
        );
      },
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
}

// =========================================================================
// Real-Time Gantt Session Timeline + 1-Hour Split Bar Mini-Chart
// (Used for 'Today' and 'Select Date' filters)
// =========================================================================
class _TimelineSessionBarData {
  final String sessionId;
  final String teacherId;
  final String teacherName;
  final Color color;
  final DateTime start;
  final DateTime end;
  final bool isActive;
  final String logoutReason;

  const _TimelineSessionBarData({
    required this.sessionId,
    required this.teacherId,
    required this.teacherName,
    required this.color,
    required this.start,
    required this.end,
    required this.isActive,
    required this.logoutReason,
  });

  int get durationSeconds => math.max(0, end.difference(start).inSeconds);
}

class _TeacherSessionTimelineAndHourlyView extends StatefulWidget {
  final List<_TeacherInfo> teachers;
  final List<UserSessionLog> logs;
  final DateTime targetDate;
  final bool isToday;
  final DateTime currentNow;
  final bool isDark;
  final String? selectedTeacherId;
  final ValueChanged<String?>? onTeacherSelected;

  const _TeacherSessionTimelineAndHourlyView({
    required this.teachers,
    required this.logs,
    required this.targetDate,
    required this.isToday,
    required this.currentNow,
    required this.isDark,
    this.selectedTeacherId,
    this.onTeacherSelected,
  });

  @override
  State<_TeacherSessionTimelineAndHourlyView> createState() =>
      _TeacherSessionTimelineAndHourlyViewState();
}

class _TeacherSessionTimelineAndHourlyViewState
    extends State<_TeacherSessionTimelineAndHourlyView> {
  String? _selectedBarId;
  int? _hoveredHour;

  static String _formatHourTick(int hour) {
    final h = hour % 24;
    if (h == 0) return '12 AM';
    if (h == 12) return '12 PM';
    if (h < 12) return '$h AM';
    return '${h - 12} PM';
  }

  static String _formatTimeShort(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s $ampm';
  }

  static String _formatCompactDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String _statusLabel(bool isActive, String reason) {
    if (isActive) return 'Online Now';
    switch (reason) {
      case 'manual':
        return 'Manual Logout';
      case 'inactivity':
      case 'inactivity_timeout':
        return 'Inactivity (30m)';
      default:
        return 'Terminated';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(
      widget.targetDate.year,
      widget.targetDate.month,
      widget.targetDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final nowLocal = widget.currentNow.toLocal();

    // Build session bars per teacher for targetDate
    final Map<String, List<_TimelineSessionBarData>> teacherBars = {};
    final Map<String, List<DateTimeRange>> teacherMergedIntervals = {};
    final Map<String, int> teacherTotalSeconds = {};
    final Map<String, bool> teacherOnlineMap = {};
    final List<_TimelineSessionBarData> allBars = [];

    DateTime? earliestStart;
    DateTime? latestEnd;

    for (final teacher in widget.teachers) {
      final tLogs = widget.logs.where((l) => l.userId == teacher.id).toList();
      final bars = <_TimelineSessionBarData>[];
      final rawRanges = <DateTimeRange>[];
      bool isOnline = false;

      for (final log in tLogs) {
        final interval =
            _AdminActivityAnalyticsTabState._effectiveSessionInterval(
              log,
              widget.currentNow,
            );
        if (!interval.end.isAfter(dayStart) ||
            !interval.start.isBefore(dayEnd)) {
          continue;
        }
        final clippedStart = interval.start.isBefore(dayStart)
            ? dayStart
            : interval.start;
        final clippedEnd = interval.end.isAfter(dayEnd) ? dayEnd : interval.end;
        if (!clippedEnd.isAfter(clippedStart) && !log.isActive) continue;

        if (log.isActive) isOnline = true;
        rawRanges.add(DateTimeRange(start: clippedStart, end: clippedEnd));

        final bar = _TimelineSessionBarData(
          sessionId: log.id,
          teacherId: teacher.id,
          teacherName: teacher.name,
          color: teacher.color,
          start: clippedStart,
          end: clippedEnd,
          isActive: log.isActive,
          logoutReason: log.logoutReason ?? 'terminated',
        );
        bars.add(bar);
        allBars.add(bar);

        if (earliestStart == null || clippedStart.isBefore(earliestStart)) {
          earliestStart = clippedStart;
        }
        if (latestEnd == null || clippedEnd.isAfter(latestEnd)) {
          latestEnd = clippedEnd;
        }
      }

      bars.sort((a, b) => a.start.compareTo(b.start));
      final merged = _AdminActivityAnalyticsTabState._mergeIntervals(rawRanges);
      int totalSec = 0;
      for (final r in merged) {
        totalSec += r.duration.inSeconds;
      }

      teacherBars[teacher.id] = bars;
      teacherMergedIntervals[teacher.id] = merged;
      teacherTotalSeconds[teacher.id] = totalSec.clamp(0, 86400);
      teacherOnlineMap[teacher.id] = isOnline;
    }

    // Dynamic startHour and endHour
    int startHour;
    int endHour;
    if (earliestStart != null && latestEnd != null) {
      startHour = earliestStart.hour;
      final rawEndHour = widget.isToday
          ? math.max(latestEnd.hour + 1, nowLocal.hour + 1)
          : (latestEnd.minute > 0 || latestEnd.second > 0
                ? latestEnd.hour + 1
                : latestEnd.hour + 1);
      endHour = rawEndHour.clamp(startHour + 4, 24);
      if (endHour - startHour < 4) {
        startHour = math.max(0, endHour - 4);
      }
    } else {
      if (widget.isToday) {
        endHour = (nowLocal.hour + 1).clamp(4, 24);
        startHour = math.max(0, endHour - 6);
      } else {
        startHour = 7;
        endHour = 17;
      }
    }

    final axisStart = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      startHour,
    );
    final axisEnd = dayStart.add(Duration(hours: endHour));
    final totalAxisSeconds = math.max(
      3600,
      axisEnd.difference(axisStart).inSeconds,
    );
    final hourCount = math.max(1, endHour - startHour);

    _TimelineSessionBarData? activeTooltipBar;
    if (_selectedBarId != null) {
      for (final b in allBars) {
        if (b.sessionId == _selectedBarId) {
          activeTooltipBar = b;
          break;
        }
      }
    }
    activeTooltipBar ??= allBars.isNotEmpty ? allBars.last : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final isMobile = maxW < 540;
        final double nameColW = isMobile ? 104.0 : 148.0;
        final double totalColW = isMobile ? 64.0 : 78.0;
        final double availableTrackW = math.max(
          180.0,
          maxW - nameColW - totalColW - 20,
        );
        final double minTrackW = math.max(availableTrackW, hourCount * 46.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1 Header: Live Session Timeline
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 13.5,
                      color: widget.isDark
                          ? Colors.white70
                          : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isToday
                          ? 'Live Session Timeline (Login → Logout / Now)'
                          : 'Session Timeline (Login → Logout)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                // Legend for bar end types
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _buildLegendIndicator(
                      color: _AdminActivityAnalyticsTabState.statusOnlineColor,
                      label: 'Online Now ▶',
                      isDark: widget.isDark,
                    ),
                    _buildLegendIndicator(
                      color: _AdminActivityAnalyticsTabState.statusManualLogoutColor,
                      label: 'Manual Logout',
                      isDark: widget.isDark,
                    ),
                    _buildLegendIndicator(
                      color: _AdminActivityAnalyticsTabState.statusInactivityColor,
                      label: 'Inactivity',
                      isDark: widget.isDark,
                    ),
                    _buildLegendIndicator(
                      color: _AdminActivityAnalyticsTabState.statusTerminatedColor,
                      label: 'Terminated',
                      isDark: widget.isDark,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Interactive Selected/Hovered Session Details Banner
            if (activeTooltipBar != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: activeTooltipBar.color.withValues(
                    alpha: widget.isDark ? 0.14 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: activeTooltipBar.color.withValues(alpha: 0.35),
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: activeTooltipBar.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          activeTooltipBar.teacherName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'In: ${_formatTimeShort(activeTooltipBar.start)} → ${activeTooltipBar.isActive ? 'Online Now' : 'Out: ${_formatTimeShort(activeTooltipBar.end)}'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white70
                            : const Color(0xFF334155),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: activeTooltipBar.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AdminRepository.formatHumanReadableDuration(
                          activeTooltipBar.durationSeconds,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: activeTooltipBar.color,
                        ),
                      ),
                    ),
                    Text(
                      '• ${_statusLabel(activeTooltipBar.isActive, activeTooltipBar.logoutReason)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: activeTooltipBar.isActive
                            ? AppTheme.catGreen
                            : (widget.isDark
                                  ? Colors.white60
                                  : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),

            // Horizontally scrollable timeline container on small screens, full width on large screens
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: nameColW + minTrackW + totalColW + 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Axis Header Row
                    Row(
                      children: [
                        SizedBox(
                          width: nameColW,
                          child: Text(
                            'Faculty',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: minTrackW,
                          height: 22,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (int i = 0; i <= hourCount; i++)
                                Positioned(
                                  left:
                                      (i / hourCount) * minTrackW -
                                      (i == 0 ? 0 : (i == hourCount ? 34 : 17)),
                                  top: 2,
                                  child: Text(
                                    _formatHourTick(startHour + i),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: widget.isDark
                                          ? Colors.white54
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              if (widget.isToday &&
                                  nowLocal.isAfter(axisStart) &&
                                  nowLocal.isBefore(axisEnd))
                                Positioned(
                                  left:
                                      ((nowLocal
                                                      .difference(axisStart)
                                                      .inSeconds /
                                                  totalAxisSeconds)
                                              .clamp(0.0, 1.0) *
                                          minTrackW) -
                                      16,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.catGreen,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'NOW',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: totalColW,
                          child: Text(
                            'Total',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Teacher Gantt Rows
                    ...widget.teachers.map((teacher) {
                      final bars = teacherBars[teacher.id] ?? const [];
                      final totalSec = teacherTotalSeconds[teacher.id] ?? 0;
                      final isOnline = teacherOnlineMap[teacher.id] == true;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            // Left: Teacher Name + Online Indicator
                            SizedBox(
                              width: nameColW,
                              child: InkWell(
                                onTap: () =>
                                    widget.onTeacherSelected?.call(teacher.id),
                                borderRadius: BorderRadius.circular(6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: teacher.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            teacher.name,
                                            style: TextStyle(
                                              fontSize: isMobile ? 11.5 : 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: widget.isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isOnline)
                                            const Text(
                                              '● Online Now',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.catGreen,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Middle: Gantt Session Track
                            Container(
                              width: minTrackW,
                              height: 30,
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: widget.isDark
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Vertical hour grid lines
                                  for (int i = 1; i < hourCount; i++)
                                    Positioned(
                                      left: (i / hourCount) * minTrackW,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 1,
                                        color: widget.isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.06,
                                              )
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),

                                  // Empty state label if no session today
                                  if (bars.isEmpty)
                                    Center(
                                      child: Text(
                                        'No session recorded',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: widget.isDark
                                              ? Colors.white24
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),

                                  // Session interval bars
                                  ...bars.map((bar) {
                                    final startRatio =
                                        (bar.start
                                                    .difference(axisStart)
                                                    .inSeconds /
                                                totalAxisSeconds)
                                            .clamp(0.0, 1.0);
                                    final endRatio =
                                        (bar.end
                                                    .difference(axisStart)
                                                    .inSeconds /
                                                totalAxisSeconds)
                                            .clamp(0.0, 1.0);
                                    final leftPx = startRatio * minTrackW;
                                    final widthPx = math.max(
                                      8.0,
                                      (endRatio - startRatio) * minTrackW,
                                    );
                                    final isSelected =
                                        activeTooltipBar?.sessionId ==
                                        bar.sessionId;

                                    Color endCapColor = bar.color;
                                    if (!bar.isActive) {
                                      if (bar.logoutReason == 'inactivity' ||
                                          bar.logoutReason == 'inactivity_timeout') {
                                        endCapColor = _AdminActivityAnalyticsTabState.statusInactivityColor;
                                      } else if (bar.logoutReason == 'terminated') {
                                        endCapColor = _AdminActivityAnalyticsTabState.statusTerminatedColor;
                                      } else {
                                        endCapColor = _AdminActivityAnalyticsTabState.statusManualLogoutColor;
                                      }
                                    }

                                    return Positioned(
                                      left: leftPx.clamp(
                                        0.0,
                                        math.max(0.0, minTrackW - 8.0),
                                      ),
                                      top: 4,
                                      bottom: 4,
                                      width: math.min(
                                        widthPx,
                                        math.max(8.0, minTrackW - leftPx),
                                      ),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        onEnter: (_) {
                                          setState(
                                            () =>
                                                _selectedBarId = bar.sessionId,
                                          );
                                        },
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(
                                              () => _selectedBarId =
                                                  bar.sessionId,
                                            );
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            decoration: BoxDecoration(
                                              color: bar.color.withValues(
                                                alpha:
                                                    bar.logoutReason ==
                                                            'terminated' &&
                                                        !bar.isActive
                                                    ? 0.72
                                                    : 0.92,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              border: Border.all(
                                                color: isSelected
                                                    ? (widget.isDark
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF0F172A,
                                                            ))
                                                    : endCapColor,
                                                width: isSelected ? 1.6 : 1.0,
                                              ),
                                              boxShadow:
                                                  bar.isActive || isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: bar.color
                                                            .withValues(
                                                              alpha: 0.35,
                                                            ),
                                                        blurRadius: 6,
                                                        offset: const Offset(
                                                          0,
                                                          1,
                                                        ),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: bar.isActive
                                                  ? const Padding(
                                                      padding: EdgeInsets.only(
                                                        right: 2,
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        size: 13,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 4,
                                                      decoration: BoxDecoration(
                                                        color: endCapColor,
                                                        borderRadius:
                                                            const BorderRadius.horizontal(
                                                              right:
                                                                  Radius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  // Live "Now" vertical indicator line
                                  if (widget.isToday &&
                                      nowLocal.isAfter(axisStart) &&
                                      nowLocal.isBefore(axisEnd))
                                    Positioned(
                                      left:
                                          (nowLocal
                                                      .difference(axisStart)
                                                      .inSeconds /
                                                  totalAxisSeconds)
                                              .clamp(0.0, 1.0) *
                                          minTrackW,
                                      top: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 1.5,
                                        color: AppTheme.catGreen,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Right: Total union duration for this teacher today
                            SizedBox(
                              width: totalColW,
                              child: Text(
                                _formatCompactDuration(totalSec),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: isMobile ? 11.5 : 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: isOnline
                                      ? AppTheme.catGreen
                                      : (totalSec > 0
                                            ? (widget.isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A))
                                            : (widget.isDark
                                                  ? Colors.white38
                                                  : const Color(0xFF94A3B8))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: widget.isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 12),

            // Section 2: 1-Hour Split Bar Mini-Chart (Minutes per Hour, Max 60m)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.chartBar,
                      size: 13.5,
                      color: widget.isDark
                          ? Colors.white70
                          : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hourly Usage Breakdown (Minutes per Hour · Max 60m)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                if (_hoveredHour != null)
                  Text(
                    '${_formatHourTick(_hoveredHour!)} – ${_formatHourTick(_hoveredHour! + 1)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.catBlue,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(maxW, hourCount * 54.0 + 42.0),
                height: 126,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Y-Axis Labels (60m, 30m, 0m)
                    SizedBox(
                      width: 34,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22, top: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '60m',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              '30m',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              '0m',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 1-Hour Buckets
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(hourCount, (idx) {
                          final h = startHour + idx;
                          final slotStart = dayStart.add(Duration(hours: h));
                          final slotEnd = dayStart.add(Duration(hours: h + 1));
                          final isHoveredSlot = _hoveredHour == h;

                          // Compute exact minutes per teacher in [slotStart, slotEnd)
                          final slotTeacherMinutes =
                              <({Color color, String name, double minutes})>[];
                          for (final teacher in widget.teachers) {
                            final merged =
                                teacherMergedIntervals[teacher.id] ?? const [];
                            int secInHour = 0;
                            for (final r in merged) {
                              final oStart = r.start.isAfter(slotStart)
                                  ? r.start
                                  : slotStart;
                              final oEnd = r.end.isBefore(slotEnd)
                                  ? r.end
                                  : slotEnd;
                              if (oEnd.isAfter(oStart)) {
                                secInHour += oEnd.difference(oStart).inSeconds;
                              }
                            }
                            final mins = (secInHour / 60.0).clamp(0.0, 60.0);
                            slotTeacherMinutes.add((
                              color: teacher.color,
                              name: teacher.name,
                              minutes: mins,
                            ));
                          }

                          final tooltipLines = slotTeacherMinutes
                              .where((e) => e.minutes >= 0.1)
                              .map(
                                (e) =>
                                    '${e.name}: ${e.minutes >= 1 ? '${e.minutes.round()}m' : '<1m'}',
                              )
                              .join('\n');

                          return Expanded(
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _hoveredHour = h),
                              onExit: (_) =>
                                  setState(() => _hoveredHour = null),
                              child: Tooltip(
                                message: tooltipLines.isEmpty
                                    ? '${_formatHourTick(h)}: 0m'
                                    : '${_formatHourTick(h)} – ${_formatHourTick(h + 1)}\n$tooltipLines',
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHoveredSlot
                                        ? (widget.isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.04,
                                                )
                                              : const Color(0xFFF1F5F9))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          alignment: Alignment.bottomCenter,
                                          children: [
                                            // Horizontal reference lines (60m top, 30m middle, 0m bottom)
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                  height: 1,
                                                  color: widget.isDark
                                                      ? Colors.white10
                                                      : const Color(0xFFE2E8F0),
                                                ),
                                                Container(
                                                  height: 1,
                                                  color: widget.isDark
                                                      ? Colors.white10
                                                      : const Color(0xFFE2E8F0),
                                                ),
                                                Container(
                                                  height: 1,
                                                  color: widget.isDark
                                                      ? Colors.white12
                                                      : const Color(0xFFCBD5E1),
                                                ),
                                              ],
                                            ),
                                            // Teacher bars for this hour
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: slotTeacherMinutes.map((
                                                  entry,
                                                ) {
                                                  final ratio =
                                                      (entry.minutes / 60.0)
                                                          .clamp(0.0, 1.0);
                                                  return Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 1,
                                                          ),
                                                      child: FractionallySizedBox(
                                                        heightFactor:
                                                            entry.minutes > 0
                                                            ? math.max(
                                                                0.06,
                                                                ratio,
                                                              )
                                                            : 0.0,
                                                        alignment: Alignment
                                                            .bottomCenter,
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: entry.color,
                                                            borderRadius:
                                                                const BorderRadius.vertical(
                                                                  top:
                                                                      Radius.circular(
                                                                        3,
                                                                      ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatHourTick(h),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: isHoveredSlot
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isHoveredSlot
                                              ? AppTheme.catBlue
                                              : (widget.isDark
                                                    ? Colors.white54
                                                    : const Color(0xFF64748B)),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendIndicator({
    required Color color,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
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

// =========================================================================
// Faculty Engagement Bar Chart & Leaderboard for Week, Month, and All Records
// =========================================================================

class _TeacherEngagementBarChart extends StatefulWidget {
  final String activeFilter; // 'week', 'month', 'all'
  final List<_TeacherInfo> teachers;
  final List<UserSessionLog> logs;
  final DateTime currentNow;
  final bool isDark;
  final String? selectedTeacherId;
  final ValueChanged<String?>? onTeacherSelected;

  const _TeacherEngagementBarChart({
    super.key,
    required this.activeFilter,
    required this.teachers,
    required this.logs,
    required this.currentNow,
    required this.isDark,
    this.selectedTeacherId,
    this.onTeacherSelected,
  });

  @override
  State<_TeacherEngagementBarChart> createState() =>
      _TeacherEngagementBarChartState();
}

class _TeacherEngagementBarChartState
    extends State<_TeacherEngagementBarChart> {
  int? _hoveredGroupIndex;
  String? _hoveredTeacherId;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  String _formatExactDuration(int seconds) {
    if (seconds <= 0) return '0 minutes';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return minutes > 0 ? '$hours hrs $minutes mins' : '$hours hrs';
    }
    if (minutes > 0) {
      return '$minutes mins';
    }
    return '$secs secs';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    if (widget.activeFilter == 'all') {
      return _buildAllRecordsLeaderboard(context, isDark);
    } else if (widget.activeFilter == 'month') {
      return _buildMonthGroupedChart(context, isDark);
    } else {
      return _buildWeekGroupedChart(context, isDark);
    }
  }

  // ---------------------------------------------------------------------------
  // Week View: Mon - Sun Grouped Columns
  // ---------------------------------------------------------------------------
  Widget _buildWeekGroupedChart(BuildContext context, bool isDark) {
    final now = widget.currentNow;
    final monday = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final activeTeachers = widget.selectedTeacherId != null
        ? widget.teachers.where((t) => t.id == widget.selectedTeacherId).toList()
        : widget.teachers;

    // Build data per day
    final dayGroups = <_EngagementBarGroup>[];
    int maxGroupTotalSeconds = 0;

    for (int i = 0; i < 7; i++) {
      final day = days[i];
      final teacherBars = <_TeacherBarValue>[];
      int groupTotal = 0;

      for (final teacher in activeTeachers) {
        final tLogs = widget.logs.where((l) => l.userId == teacher.id).toList();
        final sec = _AdminActivityAnalyticsTabState._calculateTeacherDaySeconds(
          tLogs,
          day,
          now,
        );
        teacherBars.add(
          _TeacherBarValue(
            teacherId: teacher.id,
            teacherName: teacher.name,
            color: teacher.color,
            seconds: sec,
          ),
        );
        groupTotal += sec;
      }

      if (groupTotal > maxGroupTotalSeconds) {
        maxGroupTotalSeconds = groupTotal;
      }

      final isToday = day.year == now.year &&
          day.month == now.month &&
          day.day == now.day;

      dayGroups.add(
        _EngagementBarGroup(
          label: dayNames[i],
          subLabel: '${day.month}/${day.day}',
          isHighlighted: isToday,
          totalSeconds: groupTotal,
          bars: teacherBars,
        ),
      );
    }

    if (maxGroupTotalSeconds == 0) {
      return _buildEmptyState(
        isDark,
        'No usage recorded this week',
        'Faculty active sessions from Monday to Sunday will be displayed here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendRow(isDark),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final double chartWidth = math.max(constraints.maxWidth, 560.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: chartWidth,
                height: 290,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(dayGroups.length, (index) {
                    final group = dayGroups[index];
                    return Expanded(
                      child: _buildBarGroupColumn(
                        group: group,
                        groupIndex: index,
                        maxTotalSeconds: maxGroupTotalSeconds,
                        isDark: isDark,
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Month View: 4-5 Weekly Buckets
  // ---------------------------------------------------------------------------
  Widget _buildMonthGroupedChart(BuildContext context, bool isDark) {
    final now = widget.currentNow;
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final activeTeachers = widget.selectedTeacherId != null
        ? widget.teachers.where((t) => t.id == widget.selectedTeacherId).toList()
        : widget.teachers;

    // Define 4-5 bucket ranges
    final buckets = <_MonthBucket>[
      _MonthBucket(label: 'Week 1', rangeStr: 'Days 1–7', startDay: 1, endDay: 7),
      _MonthBucket(label: 'Week 2', rangeStr: 'Days 8–14', startDay: 8, endDay: 14),
      _MonthBucket(label: 'Week 3', rangeStr: 'Days 15–21', startDay: 15, endDay: 21),
      _MonthBucket(label: 'Week 4', rangeStr: 'Days 22–28', startDay: 22, endDay: 28),
    ];
    if (totalDaysInMonth > 28) {
      buckets.add(
        _MonthBucket(
          label: 'Week 5',
          rangeStr: 'Days 29–$totalDaysInMonth',
          startDay: 29,
          endDay: totalDaysInMonth,
        ),
      );
    }

    final groups = <_EngagementBarGroup>[];
    int maxGroupTotalSeconds = 0;

    for (int b = 0; b < buckets.length; b++) {
      final bucket = buckets[b];
      final teacherBars = <_TeacherBarValue>[];
      int groupTotal = 0;

      for (final teacher in activeTeachers) {
        final tLogs = widget.logs.where((l) => l.userId == teacher.id).toList();
        int teacherBucketSeconds = 0;

        for (int dayNum = bucket.startDay; dayNum <= bucket.endDay; dayNum++) {
          final targetDate = DateTime(now.year, now.month, dayNum);
          teacherBucketSeconds +=
              _AdminActivityAnalyticsTabState._calculateTeacherDaySeconds(
                tLogs,
                targetDate,
                now,
              );
        }

        teacherBars.add(
          _TeacherBarValue(
            teacherId: teacher.id,
            teacherName: teacher.name,
            color: teacher.color,
            seconds: teacherBucketSeconds,
          ),
        );
        groupTotal += teacherBucketSeconds;
      }

      if (groupTotal > maxGroupTotalSeconds) {
        maxGroupTotalSeconds = groupTotal;
      }

      final isCurrentBucket = now.day >= bucket.startDay && now.day <= bucket.endDay;

      groups.add(
        _EngagementBarGroup(
          label: bucket.label,
          subLabel: bucket.rangeStr,
          isHighlighted: isCurrentBucket,
          totalSeconds: groupTotal,
          bars: teacherBars,
        ),
      );
    }

    if (maxGroupTotalSeconds == 0) {
      return _buildEmptyState(
        isDark,
        'No usage recorded this month',
        'Weekly teacher telemetry for ${_AdminActivityAnalyticsTabState._shortMonth(now.month)} ${now.year} will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendRow(isDark),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final double chartWidth = math.max(constraints.maxWidth, 500.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: chartWidth,
                height: 290,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(groups.length, (index) {
                    final group = groups[index];
                    return Expanded(
                      child: _buildBarGroupColumn(
                        group: group,
                        groupIndex: index,
                        maxTotalSeconds: maxGroupTotalSeconds,
                        isDark: isDark,
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bar Group Column Widget (for Week & Month)
  // ---------------------------------------------------------------------------
  Widget _buildBarGroupColumn({
    required _EngagementBarGroup group,
    required int groupIndex,
    required int maxTotalSeconds,
    required bool isDark,
  }) {
    final isHovered = _hoveredGroupIndex == groupIndex;
    const double maxBarHeight = 180.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredGroupIndex = groupIndex),
      onExit: (_) => setState(() => _hoveredGroupIndex = null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Top Badge: Total Duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isHovered
                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatDuration(group.totalSeconds),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: group.totalSeconds > 0 ? FontWeight.w700 : FontWeight.w500,
                  color: group.totalSeconds > 0
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Vertical Bar Container
            Container(
              height: maxBarHeight,
              alignment: Alignment.bottomCenter,
              child: group.totalSeconds == 0
                  ? Container(
                      width: 28,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: group.bars.map((bar) {
                        final ratio = maxTotalSeconds > 0
                            ? (bar.seconds / maxTotalSeconds).clamp(0.0, 1.0)
                            : 0.0;
                        final barH = math.max(ratio * maxBarHeight, 6.0);
                        final isTeacherHovered = _hoveredTeacherId == bar.teacherId;

                        return Tooltip(
                          message:
                              '${bar.teacherName}\n${_formatExactDuration(bar.seconds)}',
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: bar.color.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              widget.onTeacherSelected?.call(bar.teacherId);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoveredTeacherId = bar.teacherId),
                              onExit: (_) =>
                                  setState(() => _hoveredTeacherId = null),
                              child: Container(
                                width: group.bars.length == 1 ? 32 : 16,
                                height: barH,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: bar.seconds > 0
                                      ? (isTeacherHovered
                                          ? bar.color
                                          : bar.color.withValues(alpha: 0.85))
                                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                  boxShadow: isTeacherHovered && bar.seconds > 0
                                      ? [
                                          BoxShadow(
                                            color: bar.color.withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, -2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 10),

            // Base Divider Line
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: group.isHighlighted
                    ? (isDark ? AppTheme.catGreen : const Color(0xFF16A34A))
                    : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 8),

            // Column Labels
            Text(
              group.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: group.isHighlighted ? FontWeight.w800 : FontWeight.w600,
                color: group.isHighlighted
                    ? (isDark ? AppTheme.catGreen : const Color(0xFF16A34A))
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
            Text(
              group.subLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // All Records View: Faculty Leaderboard & Cumulative Progress
  // ---------------------------------------------------------------------------
  Widget _buildAllRecordsLeaderboard(BuildContext context, bool isDark) {
    final now = widget.currentNow;
    final List<_TeacherLeaderboardEntry> entries = [];

    int highestTotalSeconds = 0;

    for (final teacher in widget.teachers) {
      final tLogs = widget.logs.where((l) => l.userId == teacher.id).toList();
      final totalSec = _AdminActivityAnalyticsTabState._calculateCappedTotalSeconds(
        tLogs,
        now,
      );
      if (totalSec > highestTotalSeconds) {
        highestTotalSeconds = totalSec;
      }
      entries.add(
        _TeacherLeaderboardEntry(
          teacher: teacher,
          totalSeconds: totalSec,
          sessionCount: tLogs.length,
        ),
      );
    }

    // Sort descending by usage
    entries.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

    if (highestTotalSeconds == 0) {
      return _buildEmptyState(
        isDark,
        'No historical usage records found',
        'Teacher session activity will accumulate here over time.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendRow(isDark),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMultiCol = constraints.maxWidth >= 720;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMultiCol ? 2 : 1,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 104,
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final rank = index + 1;
                final isSelected = widget.selectedTeacherId == entry.teacher.id;
                final progressRatio = highestTotalSeconds > 0
                    ? (entry.totalSeconds / highestTotalSeconds).clamp(0.0, 1.0)
                    : 0.0;

                return InkWell(
                  onTap: () {
                    widget.onTeacherSelected?.call(entry.teacher.id);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? entry.teacher.color.withValues(alpha: isDark ? 0.2 : 0.1)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? entry.teacher.color
                            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Rank Badge
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Teacher Avatar Initials
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: entry.teacher.color.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: entry.teacher.color,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                entry.teacher.name.isNotEmpty
                                    ? entry.teacher.name[0].toUpperCase()
                                    : 'T',
                                style: TextStyle(
                                  color: entry.teacher.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Name & Sessions
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.teacher.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '${entry.sessionCount} total sessions',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Total Time Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: entry.teacher.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.clock,
                                    size: 12,
                                    color: entry.teacher.color,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatDuration(entry.totalSeconds),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: entry.teacher.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(entry.teacher.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Teacher Legend Row
  // ---------------------------------------------------------------------------
  Widget _buildLegendRow(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.selectedTeacherId != null)
          InkWell(
            onTap: () => widget.onTeacherSelected?.call(null),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.x,
                    size: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Clear Filter',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...widget.teachers.map((t) {
          final isSelected = widget.selectedTeacherId == t.id;
          return InkWell(
            onTap: () => widget.onTeacherSelected?.call(isSelected ? null : t.id),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? t.color.withValues(alpha: isDark ? 0.25 : 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? t.color
                      : (isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: t.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State Widget
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(bool isDark, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.barChart2,
              size: 26,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementBarGroup {
  final String label;
  final String subLabel;
  final bool isHighlighted;
  final int totalSeconds;
  final List<_TeacherBarValue> bars;

  const _EngagementBarGroup({
    required this.label,
    required this.subLabel,
    required this.isHighlighted,
    required this.totalSeconds,
    required this.bars,
  });
}

class _TeacherBarValue {
  final String teacherId;
  final String teacherName;
  final Color color;
  final int seconds;

  const _TeacherBarValue({
    required this.teacherId,
    required this.teacherName,
    required this.color,
    required this.seconds,
  });
}

class _MonthBucket {
  final String label;
  final String rangeStr;
  final int startDay;
  final int endDay;

  const _MonthBucket({
    required this.label,
    required this.rangeStr,
    required this.startDay,
    required this.endDay,
  });
}

class _TeacherLeaderboardEntry {
  final _TeacherInfo teacher;
  final int totalSeconds;
  final int sessionCount;

  const _TeacherLeaderboardEntry({
    required this.teacher,
    required this.totalSeconds,
    required this.sessionCount,
  });
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
    final idleCount = math.max(
      0,
      widget.totalTrackedTeachers - widget.activeNowCount,
    );
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
