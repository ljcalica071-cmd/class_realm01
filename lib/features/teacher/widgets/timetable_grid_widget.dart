import 'package:flutter/material.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/core/theme/subject_palette.dart';

class _PositionedSchedule {
  final ScheduleModel schedule;
  final int columnIndex;
  final int totalColumns;

  _PositionedSchedule({
    required this.schedule,
    required this.columnIndex,
    required this.totalColumns,
  });
}

class TimetableGridWidget extends StatelessWidget {
  final List<ScheduleModel> schedules;
  final Function(ScheduleModel)? onEdit;
  final String? currentTeacherId;

  const TimetableGridWidget({
    super.key,
    required this.schedules,
    this.onEdit,
    this.currentTeacherId,
  });

  static const int startHour = 7;
  static const int endHour = 20; // Expanded for full range
  static const int slotsPerHour = 2;
  static const int totalSlots = (endHour - startHour) * slotsPerHour;
  static const double rowHeight = 60.0;
  static const double timeColumnWidth = 90.0;

  static const List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  List<_PositionedSchedule> _calculateDayLayout(List<ScheduleModel> daySchedules) {
    if (daySchedules.isEmpty) return [];

    final sorted = List<ScheduleModel>.from(daySchedules)
      ..sort((a, b) {
        final cmp = a.startMinutes.compareTo(b.startMinutes);
        if (cmp != 0) return cmp;
        return b.durationMinutes.compareTo(a.durationMinutes);
      });

    final positioned = <_PositionedSchedule>[];

    for (int i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      final overlapping = sorted.where((other) {
        return !(other.endMinutes <= s.startMinutes ||
            other.startMinutes >= s.endMinutes);
      }).toList();

      final usedCols = <int>{};
      for (final pos in positioned) {
        if (overlapping.contains(pos.schedule)) {
          usedCols.add(pos.columnIndex);
        }
      }
      int col = 0;
      while (usedCols.contains(col)) {
        col++;
      }

      positioned.add(
        _PositionedSchedule(
          schedule: s,
          columnIndex: col,
          totalColumns: 1,
        ),
      );
    }

    for (int i = 0; i < positioned.length; i++) {
      final p = positioned[i];
      final s = p.schedule;
      final overlappingPos = positioned.where((other) {
        return !(other.schedule.endMinutes <= s.startMinutes ||
            other.schedule.startMinutes >= s.endMinutes);
      }).toList();

      final maxCol = overlappingPos
          .map((e) => e.columnIndex)
          .fold(0, (max, c) => c > max ? c : max);
      final count = maxCol + 1;
      positioned[i] = _PositionedSchedule(
        schedule: p.schedule,
        columnIndex: p.columnIndex,
        totalColumns: count,
      );
    }

    for (int i = 0; i < positioned.length; i++) {
      final p = positioned[i];
      final s = p.schedule;
      final overlappingPos = positioned.where((other) {
        return !(other.schedule.endMinutes <= s.startMinutes ||
            other.schedule.startMinutes >= s.endMinutes);
      }).toList();

      final maxTotal = overlappingPos
          .map((e) => e.totalColumns)
          .fold(p.totalColumns, (max, t) => t > max ? t : max);
      if (maxTotal != p.totalColumns) {
        positioned[i] = _PositionedSchedule(
          schedule: p.schedule,
          columnIndex: p.columnIndex,
          totalColumns: maxTotal,
        );
      }
    }

    return positioned;
  }

  Color _getSectionColor(String subject, BuildContext context) {
    final uniqueSubjects = schedules.map((s) => s.subject).toSet().toList();
    final baseColor = SubjectPalette.getColorForSubject(
      subject,
      teacherSubjectNames: uniqueSubjects,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SubjectPalette.getPastelBackground(baseColor, isDark: isDark);
  }

  Color _getSubjectDarkColor(String subject, BuildContext context) {
    final uniqueSubjects = schedules.map((s) => s.subject).toSet().toList();
    final baseColor = SubjectPalette.getColorForSubject(
      subject,
      teacherSubjectNames: uniqueSubjects,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SubjectPalette.getTextColor(baseColor, isDark: isDark);
  }

  String _formatTimeLabel(int slotIndex) {
    final hour = startHour + (slotIndex ~/ slotsPerHour);
    final minute = (slotIndex % slotsPerHour == 0) ? 0 : 30;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = (hour % 12 == 0) ? 12 : (hour % 12);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1400.0;
        final double minDayWidth = 110.0;
        final double calculatedDayWidth =
            (maxWidth - timeColumnWidth) / days.length;
        final double dayWidth = calculatedDayWidth < minDayWidth
            ? minDayWidth
            : calculatedDayWidth;
        final double totalGridWidth =
            timeColumnWidth + (dayWidth * days.length) + 16.0;
        final bool needsHorizontalScroll = totalGridWidth > maxWidth;

        if (schedules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No schedule entries yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Schedule entries will appear here once added',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFE2E8F0);

        final allPositioned = <_PositionedSchedule>[];
        for (final day in days) {
          final dayList = schedules.where((s) => s.dayOfWeek == day).toList();
          allPositioned.addAll(_calculateDayLayout(dayList));
        }

        Widget gridContent = Container(
          width: totalGridWidth,
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(dayWidth, theme, isDark),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Stack(
                    children: [
                      _buildGridBackground(dayWidth, theme, isDark),
                      ...allPositioned.map(
                        (pos) => _buildScheduleBlock(pos, dayWidth, context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (needsHorizontalScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(width: totalGridWidth, child: gridContent),
          );
        }

        return gridContent;
      },
    );
  }

  Widget _buildHeader(double dayWidth, ThemeData theme, bool isDark) {
    final headerBg = isDark
        ? theme.colorScheme.secondary
        : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFE2E8F0);
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
        : const Color(0xFF475569);

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: timeColumnWidth),
          ...days.map(
            (day) => Container(
              width: dayWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor)),
              ),
              child: Text(
                day.substring(0, 3).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBackground(double dayWidth, ThemeData theme, bool isDark) {
    final majorLineColor = isDark
        ? Colors.white.withValues(alpha: 0.13)
        : const Color(0xFFE2E8F0);
    final minorLineColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF1F5F9);
    final hourLabelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.9)
        : const Color(0xFF1E293B);
    final subLabelColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
        : const Color(0xFF94A3B8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSlots, (index) {
        final bool isHourStart = index % slotsPerHour == 0;
        return Container(
          height: rowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isHourStart ? majorLineColor : minorLineColor,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: timeColumnWidth,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: Text(
                  isHourStart ? _formatTimeLabel(index) : '',
                  style: TextStyle(
                    fontSize: 11,
                    color: isHourStart ? hourLabelColor : subLabelColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...List.generate(
                days.length,
                (d) => Container(
                  width: dayWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: minorLineColor, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildScheduleBlock(
    _PositionedSchedule pos,
    double dayWidth,
    BuildContext context,
  ) {
    final s = pos.schedule;
    final int dayIndex = days.indexOf(s.dayOfWeek);
    if (dayIndex == -1) return const SizedBox.shrink();

    // Precise shading calculation
    final double pixelsPerMinute = rowHeight / 30;
    final int startMinutesRelative = s.startMinutes - (startHour * 60);

    if (startMinutesRelative < 0) return const SizedBox.shrink();

    final double topOffset = startMinutesRelative * pixelsPerMinute;
    final double blockHeight = s.durationMinutes * pixelsPerMinute;

    final Color bgColor = _getSectionColor(s.subject, context);
    final Color textColor = _getSubjectDarkColor(s.subject, context);

    final bool isOtherTeacher = currentTeacherId != null &&
        s.teacherId != null &&
        s.teacherId != currentTeacherId;

    final double availableWidth = dayWidth - 8;
    final double subWidth = availableWidth / pos.totalColumns;
    final double leftOffset = timeColumnWidth +
        (dayIndex * dayWidth) +
        4 +
        (pos.columnIndex * subWidth);

    return Positioned(
      left: leftOffset,
      top: topOffset + 1,
      width: subWidth - (pos.totalColumns > 1 ? 2 : 0),
      height: blockHeight - 2,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOtherTeacher
                ? textColor.withValues(alpha: 0.35)
                : textColor.withValues(alpha: 0.15),
            width: isOtherTeacher ? 1.8 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onEdit?.call(s),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: pos.totalColumns > 1 ? 6.0 : 10.0,
                  vertical: 6.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: pos.totalColumns > 1 ? 12 : 14,
                        color: textColor,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s.room.trim().isEmpty
                          ? s.section
                          : '${s.section} • ${s.room.trim()}',
                      style: TextStyle(
                        fontSize: pos.totalColumns > 1 ? 10 : 11,
                        color: textColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.teacherName != null &&
                        s.teacherName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 11,
                            color: textColor.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              isOtherTeacher
                                  ? s.teacherName!.trim()
                                  : '${s.teacherName!.trim()} (You)',
                              style: TextStyle(
                                fontSize: pos.totalColumns > 1 ? 9 : 10,
                                fontWeight: FontWeight.w600,
                                color: textColor.withValues(alpha: 0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
