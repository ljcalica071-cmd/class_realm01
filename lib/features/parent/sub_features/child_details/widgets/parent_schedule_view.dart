import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/features/teacher/widgets/timetable_grid_widget.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

enum ParentScheduleViewMode { list, grid }

class ParentScheduleView extends StatefulWidget {
  final UserModel? linkedStudent;
  final bool embedded;
  final VoidCallback? onSwitchChildTap;

  const ParentScheduleView({
    super.key,
    required this.linkedStudent,
    this.embedded = false,
    this.onSwitchChildTap,
  });

  @override
  State<ParentScheduleView> createState() => _ParentScheduleViewState();
}

class _ParentScheduleViewState extends State<ParentScheduleView> {
  ParentScheduleViewMode _viewMode = ParentScheduleViewMode.list;
  List<ScheduleModel> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void didUpdateWidget(covariant ParentScheduleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.linkedStudent?.id != widget.linkedStudent?.id ||
        oldWidget.linkedStudent?.departmentOrSection !=
            widget.linkedStudent?.departmentOrSection) {
      _loadSchedules();
    }
  }

  Future<void> _loadSchedules({bool silent = false}) async {
    final student = widget.linkedStudent;
    if (student == null ||
        (student.id.trim().isEmpty &&
            (student.departmentOrSection == null ||
                student.departmentOrSection!.trim().isEmpty))) {
      if (mounted) {
        setState(() {
          _schedules = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final rows = await SupabaseParentRepository().getSchedulesForStudent(
        student.id,
        fallbackSection: student.departmentOrSection,
      );
      if (!mounted) return;
      setState(() {
        _schedules = rows;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    final isDark = theme.brightness == Brightness.dark;
    final student = widget.linkedStudent;
    final section = student?.departmentOrSection?.trim().isNotEmpty == true
        ? student!.departmentOrSection!.trim()
        : 'Enrolled Section';

    final bodyContent = Container(
      color: theme.scaffoldBackgroundColor,
      child: student == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: AppEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No Linked Student Found',
                  message:
                      'Please select a linked student to view their weekly class schedule.',
                ),
              ),
            )
          : Column(
              children: [
                // Top View Switcher Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                        child: InkWell(
                          onTap: widget.onSwitchChildTap,
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${student.fullName} • $section',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (widget.onSwitchChildTap != null) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _viewMode == ParentScheduleViewMode.list
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
                      ),
                      const SizedBox(width: 10),
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
                        onSelectionChanged:
                            (Set<ParentScheduleViewMode> newSelection) {
                              setState(() {
                                _viewMode = newSelection.first;
                              });
                            },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return theme.colorScheme.primary;
                            }
                            return isDark
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.surface;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return theme.colorScheme.onSurface;
                          }),
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: isDark ? 0.24 : 0.18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Area with Branded Mobile Swipe-Down Refresh
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
                          child: _schedules.isEmpty
                              ? AppPullToRefresh.scrollableState(
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.all(24),
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: theme.colorScheme.onSurface
                                            .withValues(
                                              alpha: isDark ? 0.14 : 0.1,
                                            ),
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
                                          'No Schedule Plotted Yet',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Weekly class schedules for ${student.fullName} ($section) will appear here once plotted by the teacher.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.65),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _viewMode == ParentScheduleViewMode.list
                              ? _buildListView(context, theme, _schedules)
                              : Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TimetableGridWidget(
                                    schedules: _schedules,
                                  ),
                                ),
                        ),
                ),
              ],
            ),
    );

    if (widget.embedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          student == null
              ? 'Student Schedule'
              : "${student.firstName ?? student.fullName}'s Schedule",
        ),
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
                _viewMode = _viewMode == ParentScheduleViewMode.list
                    ? ParentScheduleViewMode.grid
                    : ParentScheduleViewMode.list;
              });
            },
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildListView(
    BuildContext context,
    ThemeData theme,
    List<ScheduleModel> schedules,
  ) {
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
    final isDark = theme.brightness == Brightness.dark;
    final roomTrimmed = s.room.trim();
    final timeAndRoomLabel = roomTrimmed.isEmpty
        ? '${s.startTime} - ${s.endTime}'
        : '${s.startTime} - ${s.endTime} • Room $roomTrimmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.school_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timeAndRoomLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
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
