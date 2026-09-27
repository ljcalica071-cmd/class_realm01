import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/widgets/timetable_grid_widget.dart';

enum ScheduleViewMode { list, grid }

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  ScheduleViewMode _viewMode = ScheduleViewMode.list;

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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section =
        MockDatabase.instance.currentUser?.departmentOrSection ?? 'Section A';
    final schedules = MockDatabase.instance.scheduleForSection(section);

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
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
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
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: schedules.isEmpty
                  ? const Center(child: Text('No schedule records found.'))
                  : _viewMode == ScheduleViewMode.list
                      ? _buildListView(context, theme, schedules)
                      : _buildGridView(context, theme, schedules),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _days.length,
      itemBuilder: (ctx, i) {
        final day = _days[i];
        final daySchedules =
            schedules.where((s) => s.dayOfWeek == day).toList();

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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...daySchedules.map(
              (s) => InkWell(
                onTap: () => _showScheduleDetailsDialog(context, s),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    ),
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
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
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
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
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
