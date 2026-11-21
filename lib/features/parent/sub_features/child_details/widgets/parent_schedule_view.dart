import 'dart:async';
import 'package:flutter/material.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
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
    _hydrateCache();
    _loadSchedules(silent: _schedules.isNotEmpty);
  }

  void _hydrateCache() {
    final sId = widget.linkedStudent?.id;
    if (sId != null && sId.isNotEmpty) {
      final cached = AppDataCache.instance.getCached<List<dynamic>>(
        'parent_schedule_$sId',
        (json) => json as List<dynamic>,
      );
      if (cached != null && cached.isNotEmpty) {
        _schedules = cached
            .whereType<Map>()
            .map((m) => ScheduleModel.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        _isLoading = false;
      }
    }
  }

  @override
  void didUpdateWidget(covariant ParentScheduleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.linkedStudent?.id != widget.linkedStudent?.id ||
        oldWidget.linkedStudent?.departmentOrSection !=
            widget.linkedStudent?.departmentOrSection) {
      _hydrateCache();
      _loadSchedules(silent: _schedules.isNotEmpty);
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

    if (!silent || (_schedules.isEmpty && _isLoading)) {
      setState(() => _isLoading = true);
    }

    try {
      final rows = await SupabaseParentRepository().getSchedulesForStudent(
        student.id,
        fallbackSection: student.departmentOrSection,
      );
      if (student.id.isNotEmpty) {
        unawaited(
          AppDataCache.instance.setCache(
            'parent_schedule_${student.id}',
            rows.map((s) => s.toMap()).toList(),
          ),
        );
      }
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
          : AppPullToRefresh(
              onRefresh: () => _loadSchedules(silent: true),
              child: Column(
                children: [
                // Top Student Info & View Switcher Banner (2-row layout for full readability)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Row 1: Full-width Student Name & Section/Mode Subtitle
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onSwitchChildTap,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.2 : 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.school_outlined,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.fullName,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          height: 1.25,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$section • ${_viewMode == ParentScheduleViewMode.list ? "Daily Agenda" : "Timetable"}',
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.25,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.68),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.onSwitchChildTap != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(
                                            alpha: isDark ? 0.18 : 0.08,
                                          ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Row 2: Full-width, Easy-to-Read List / Timetable Switcher
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: isDark ? 0.16 : 0.1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildViewModeSegment(
                                theme: theme,
                                isDark: isDark,
                                label: 'List',
                                icon: Icons.view_agenda_outlined,
                                isSelected:
                                    _viewMode == ParentScheduleViewMode.list,
                                onTap: () {
                                  if (_viewMode !=
                                      ParentScheduleViewMode.list) {
                                    setState(() {
                                      _viewMode = ParentScheduleViewMode.list;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildViewModeSegment(
                                theme: theme,
                                isDark: isDark,
                                label: 'Timetable',
                                icon: Icons.calendar_view_week_rounded,
                                isSelected:
                                    _viewMode == ParentScheduleViewMode.grid,
                                onTap: () {
                                  if (_viewMode !=
                                      ParentScheduleViewMode.grid) {
                                    setState(() {
                                      _viewMode = ParentScheduleViewMode.grid;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Area with Branded Mobile Swipe-Down Refresh
                Expanded(
                  child: _isLoading
                      ? ShimmerStudentScheduleSkeleton(
                          isTimetable:
                              _viewMode == ParentScheduleViewMode.grid,
                        )
                      : _schedules.isEmpty
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
              ],
            ),
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

  Widget _buildViewModeSegment({
    required ThemeData theme,
    required bool isDark,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final fgColor = isSelected
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.85 : 0.78);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label view',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.35 : 0.22,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fgColor),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
