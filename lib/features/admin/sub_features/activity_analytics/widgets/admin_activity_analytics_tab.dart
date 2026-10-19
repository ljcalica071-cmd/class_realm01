import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/models/admin_portal_models.dart';
import 'package:class_realm/core/theme/app_theme.dart';

class AdminActivityAnalyticsTab extends StatefulWidget {
  const AdminActivityAnalyticsTab({super.key});

  @override
  State<AdminActivityAnalyticsTab> createState() => _AdminActivityAnalyticsTabState();
}

class _AdminActivityAnalyticsTabState extends State<AdminActivityAnalyticsTab> {
  bool _isLoading = true;
  String _activeFilter = 'today'; // 'today', 'week', 'all'

  List<UserSessionLog> _sessionLogs = [];
  List<TeacherWorkloadSummary> _workloadSummaries = [];

  // Edge Case #20: 1-second ticker using ValueNotifier to isolate rebuilds
  late final ValueNotifier<DateTime> _tickerNotifier;
  Timer? _oneSecondTimer;

  // Realtime debounce buffer (5-second throttle for 150+ teachers)
  RealtimeChannel? _realtimeChannel;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tickerNotifier = ValueNotifier<DateTime>(DateTime.now());
    _startTicker();
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
    // Edge Case #20: Buffer/debounce incoming Supabase Realtime updates
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

  Future<void> _loadData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    final now = DateTime.now();
    DateTime? startDate;

    if (_activeFilter == 'today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (_activeFilter == 'week') {
      // Monday of current week
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    }

    final activeSy = await AdminRepository.instance.getActiveSchoolYear();
    final syId = activeSy?.id ?? '';

    final logs = await AdminRepository.instance.getTeacherSessionLogs(startDate: startDate);
    final workloads = await AdminRepository.instance.getTeacherWorkloadSummaries(syId);

    if (mounted) {
      setState(() {
        _sessionLogs = logs;
        _workloadSummaries = workloads;
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeNowCount = _sessionLogs.where((s) => s.isActive).map((s) => s.userId).toSet().length;
    final totalTrackedTeachers = _workloadSummaries.length;

    // Filtered logs
    final displayedLogs = _sessionLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher Activity & Analytics Hub',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Real-time system telemetry and usage monitoring for teachers.',
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              // Filter Segmented Buttons
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildFilterButton('Today', 'today'),
                    _buildFilterButton('This Week', 'week'),
                    _buildFilterButton('All Records', 'all'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overview KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Active Teachers Now',
                  value: '$activeNowCount Online',
                  icon: Icons.wifi_tethering_rounded,
                  color: AppTheme.catGreen,
                  subtitle: 'Live session heartbeats',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Teachers Monitored',
                  value: '$totalTrackedTeachers Teachers',
                  icon: Icons.people_outline_rounded,
                  color: theme.colorScheme.primary,
                  subtitle: 'In active School Year',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Filter Period',
                  value: _activeFilter == 'today'
                      ? 'Today'
                      : (_activeFilter == 'week' ? 'Mon - Sun' : 'All Time'),
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.catPurple,
                  subtitle: 'Midnight-split boundary',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Workload Telemetry Cards (Strict Data Privacy: Counts Only!)
          Text(
            'Teacher Workload & Total Usage Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: _workloadSummaries.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No teacher telemetry available.')))
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _workloadSummaries.map((w) {
                      return Container(
                        width: 280,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: w.isActiveNow
                                ? AppTheme.catGreen.withValues(alpha: 0.5)
                                : Colors.transparent,
                            width: 1.5,
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subjects Handled:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                Text('${w.totalSubjectsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sections Handled:', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                Text('${w.totalSectionsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Today Duration:', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                Text(
                                  AdminRepository.formatHumanReadableDuration(w.todayDurationSeconds),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.catGreen),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 28),

          // Real-Time Session Logs Table
          Text(
            'Live Teacher Session Logs & Duration Ticker',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (displayedLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No session logs found for this period.',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ValueListenableBuilder<DateTime>(
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
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                          ),
                          children: const [
                            _TableHeaderCell('Teacher Name'),
                            _TableHeaderCell('Date'),
                            _TableHeaderCell('Login Time'),
                            _TableHeaderCell('Logout Time'),
                            _TableHeaderCell('System Usage Duration'),
                          ],
                        ),
                        // Data Rows
                        ...displayedLogs.map((log) {
                          final isLive = log.isActive;
                          int elapsedSeconds = log.durationSeconds;
                          if (isLive) {
                            elapsedSeconds = currentNow.difference(log.loginAt).inSeconds;
                            if (elapsedSeconds < 0) elapsedSeconds = 0;
                          }

                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                                ),
                              ),
                            ),
                            children: [
                              // Teacher Name
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    if (isLive)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.catGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        log.teacherName ?? 'Teacher (${log.userId})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Date
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(_formatDate(log.sessionDate), style: const TextStyle(fontSize: 12.5)),
                              ),
                              // Login Time
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(_formatTimestamp(log.loginAt), style: const TextStyle(fontSize: 12.5)),
                              ),
                              // Logout Time
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: isLive
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.catGreen.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ACTIVE NOW',
                                          style: TextStyle(
                                            color: AppTheme.catGreen,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        log.logoutAt != null ? _formatTimestamp(log.logoutAt!) : '-',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                              ),
                              // Duration Ticker
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  AdminRepository.formatHumanReadableDuration(elapsedSeconds),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    color: isLive ? AppTheme.catGreen : theme.colorScheme.primary,
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String key) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = key);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
