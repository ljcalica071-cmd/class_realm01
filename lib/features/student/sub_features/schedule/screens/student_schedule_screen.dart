import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/features/teacher/widgets/timetable_grid_widget.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

enum ScheduleViewMode { list, grid }

class StudentScheduleScreen extends StatefulWidget {
  final StudentDashboardData dashboardData;

  const StudentScheduleScreen({super.key, required this.dashboardData});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  ScheduleViewMode _viewMode = ScheduleViewMode.list;
  List<ScheduleModel> _schedules = [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules({bool silent = false}) async {
    setState(() {
      if (!silent) {
        _isLoading = true;
      }
      _loadError = null;
    });

    try {
      final rows = await SupabaseScheduleRepository.instance.getSchedules(
        section: widget.dashboardData.student.departmentOrSection,
      );
      if (!mounted) return;
      setState(() {
        _schedules = rows;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (!silent || _schedules.isEmpty) {
          _loadError = error;
        }
        _isLoading = false;
      });
    }
  }

  final List<String> _days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  void _showScheduleDetailsDialog(BuildContext context, ScheduleModel s) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.class_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.subject,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    s.section,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.calendar_today_outlined,
              label: 'Day',
              value: s.dayOfWeek,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: '${s.startTime} - ${s.endTime}',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.place_outlined,
              label: 'Room / Venue',
              value: s.room,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rawSection = widget.dashboardData.student.departmentOrSection;
    final section = rawSection?.trim().isNotEmpty == true
        ? rawSection!.trim()
        : 'Class';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == ScheduleViewMode.list
                  ? Icons.calendar_view_week_rounded
                  : Icons.view_agenda_outlined,
            ),
            tooltip: _viewMode == ScheduleViewMode.list
                ? 'Switch to Timetable Grid'
                : 'Switch to List View',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == ScheduleViewMode.list
                    ? ScheduleViewMode.grid
                    : ScheduleViewMode.list;
              });
            },
          ),
        ],
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // Top View Switcher Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$section Schedule',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _viewMode == ScheduleViewMode.list
                              ? 'Daily Agenda View'
                              : 'Weekly Timetable Grid',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SegmentedButton<ScheduleViewMode>(
                    segments: const [
                      ButtonSegment<ScheduleViewMode>(
                        value: ScheduleViewMode.list,
                        label: Text('List'),
                        icon: Icon(Icons.view_agenda_outlined, size: 16),
                      ),
                      ButtonSegment<ScheduleViewMode>(
                        value: ScheduleViewMode.grid,
                        label: Text('Timetable'),
                        icon: Icon(Icons.calendar_view_week_rounded, size: 16),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (Set<ScheduleViewMode> newSelection) {
                      setState(() {
                        _viewMode = newSelection.first;
                      });
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area with Branded Mobile Swipe-Down Refresh
            Expanded(
              child: _isLoading
                  ? Center(
                      child: LoadingAnimationWidget.staggeredDotsWave(
                        color: theme.colorScheme.primary,
                        size: 40,
                      ),
                    )
                  : AppPullToRefresh(
                      onRefresh: () => _loadSchedules(silent: true),
                      child: _loadError != null
                          ? AppPullToRefresh.scrollableState(
                              child: Text(
                                'Error loading schedule: $_loadError',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            )
                          : _schedules.isEmpty
                          ? AppPullToRefresh.scrollableState(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: isDark ? 0.14 : 0.1),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(
                                              alpha: isDark ? 0.18 : 0.1,
                                            ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.calendar_today_outlined,
                                        size: 30,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No schedule records found.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Pull down to refresh once your class schedule is plotted.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _viewMode == ScheduleViewMode.list
                                  ? _buildListView(context, theme, _schedules)
                                  : _buildGridView(context, theme, _schedules),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    ThemeData theme,
    List<ScheduleModel> schedules,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _days.length,
      itemBuilder: (ctx, i) {
        final day = _days[i];
        final daySchedules = schedules
            .where((s) => s.dayOfWeek == day)
            .toList();

        if (daySchedules.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8, top: 12),
              child: Text(
                day.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...daySchedules.map(
              (s) => InkWell(
                onTap: () => _showScheduleDetailsDialog(context, s),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: isDark ? 0.14 : 0.11,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.03,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  s.room,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            s.startTime,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            s.endTime,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridView(
    BuildContext context,
    ThemeData theme,
    List<ScheduleModel> schedules,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Row(
            children: [
              Icon(
                Icons.swipe_left_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: Swipe horizontally to view full weekly timetable.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TimetableGridWidget(
              schedules: schedules,
              onEdit: (s) => _showScheduleDetailsDialog(context, s),
            ),
          ),
        ),
      ],
    );
  }
}
