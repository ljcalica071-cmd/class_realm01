import 'package:flutter/material.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/features/teacher/widgets/timetable_grid_widget.dart';

enum ParentScheduleViewMode { list, grid }

class ParentScheduleView extends StatefulWidget {
  final UserModel? linkedStudent;

  const ParentScheduleView({super.key, required this.linkedStudent});

  @override
  State<ParentScheduleView> createState() => _ParentScheduleViewState();
}

class _ParentScheduleViewState extends State<ParentScheduleView> {
  ParentScheduleViewMode _viewMode = ParentScheduleViewMode.list;
  late Future<List<ScheduleModel>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    final sec = widget.linkedStudent?.departmentOrSection;
    if (sec != null && sec.isNotEmpty) {
      _schedulesFuture =
          SupabaseScheduleRepository.instance.getSchedules(section: sec);
    } else {
      _schedulesFuture = Future.value([]);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = widget.linkedStudent;
    final section = student?.departmentOrSection ?? 'Enrolled';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          student == null
              ? 'Student Schedule'
              : "${student.firstName}'s Schedule",
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == ParentScheduleViewMode.list
                  ? Icons.calendar_view_week_rounded
                  : Icons.view_agenda_outlined,
            ),
            tooltip: 'Toggle Schedule View',
            onPressed: () {
              setState(() {
                _viewMode =
                    _viewMode == ParentScheduleViewMode.list
                        ? ParentScheduleViewMode.grid
                        : ParentScheduleViewMode.list;
              });
            },
          ),
        ],
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child:
            student == null
                ? const Center(child: Text('No linked student found.'))
                : Column(
                  children: [
                    // Top View Switcher Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            ),
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
                                  '${student.fullName} • $section',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _viewMode == ParentScheduleViewMode.list
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
                          SegmentedButton<ParentScheduleViewMode>(
                            segments: const [
                              ButtonSegment<ParentScheduleViewMode>(
                                value: ParentScheduleViewMode.list,
                                label: Text('List'),
                                icon: Icon(Icons.view_agenda_outlined, size: 16),
                              ),
                              ButtonSegment<ParentScheduleViewMode>(
                                value: ParentScheduleViewMode.grid,
                                label: Text('Timetable'),
                                icon: Icon(
                                  Icons.calendar_view_week_rounded,
                                  size: 16,
                                ),
                              ),
                            ],
                            selected: {_viewMode},
                            onSelectionChanged: (
                              Set<ParentScheduleViewMode> newSelection,
                            ) {
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

                    // Content Area
                    Expanded(
                      child: FutureBuilder<List<ScheduleModel>>(
                        future: _schedulesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final schedules = snapshot.data ?? [];
                          if (schedules.isEmpty) {
                            return const Center(
                              child: Text('No schedule records found.'),
                            );
                          }
                          return _viewMode == ParentScheduleViewMode.list
                              ? _buildListView(context, theme, schedules)
                              : Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TimetableGridWidget(
                                  schedules: schedules,
                                ),
                              );
                        },
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
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ...daySchedules.map((s) => _buildScheduleCard(context, theme, s)),
          ],
        );
      },
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    ThemeData theme,
    ScheduleModel s,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.school_outlined, color: theme.colorScheme.primary),
        ),
        title: Text(
          s.subject,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${s.startTime} - ${s.endTime} • Room: ${s.room}'),
      ),
    );
  }
}
