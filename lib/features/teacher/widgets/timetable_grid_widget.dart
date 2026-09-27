import 'package:flutter/material.dart';
import 'package:class_realm/models/academic_models.dart';

class TimetableGridWidget extends StatelessWidget {
  final List<ScheduleModel> schedules;
  final Function(ScheduleModel)? onEdit;

  const TimetableGridWidget({
    super.key,
    required this.schedules,
    this.onEdit,
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

  Color _getSectionColor(String section) {
    switch (section) {
      case 'Section A':
        return const Color(0xFFE0F2FE);
      case 'Section B':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFFFEDD5);
    }
  }

  Color _getSubjectDarkColor(String subject) {
    final hash = subject.hashCode.abs();
    final colors = const [
      Color(0xFF1E3A8A),
      Color(0xFF14532D),
      Color(0xFF7C2D12),
      Color(0xFF831843),
      Color(0xFF4C1D95),
      Color(0xFF92400E),
    ];
    return colors[hash % colors.length];
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1400.0;
        final double minDayWidth = 110.0;
        final double calculatedDayWidth =
            (maxWidth - timeColumnWidth) / days.length;
        final double dayWidth =
            calculatedDayWidth < minDayWidth ? minDayWidth : calculatedDayWidth;
        final double totalGridWidth =
            timeColumnWidth + (dayWidth * days.length);
        final bool needsHorizontalScroll = totalGridWidth > maxWidth;

        if (schedules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 16),
                  const Text(
                    'No schedule entries yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Add Schedule Entry" to get started',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget gridContent = Container(
          width: totalGridWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(dayWidth),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Stack(
                    children: [
                      _buildGridBackground(dayWidth),
                      ...schedules.map((s) => _buildScheduleBlock(s, dayWidth)),
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
            child: SizedBox(
              width: totalGridWidth,
              child: gridContent,
            ),
          );
        }

        return gridContent;
      },
    );
  }

  Widget _buildHeader(double dayWidth) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const SizedBox(width: timeColumnWidth),
          ...days.map((day) => Container(
                width: dayWidth,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Text(
                  day.substring(0, 3).toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF475569),
                    letterSpacing: 1.2,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGridBackground(double dayWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSlots, (index) {
        final bool isHourStart = index % slotsPerHour == 0;
        return Container(
          height: rowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isHourStart ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
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
                    color: isHourStart ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...List.generate(days.length, (d) => Container(
                    width: dayWidth,
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Color(0xFFF1F5F9),
                          width: 1,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildScheduleBlock(ScheduleModel s, double dayWidth) {
    final int dayIndex = days.indexOf(s.dayOfWeek);
    if (dayIndex == -1) return const SizedBox.shrink();

    // Precise shading calculation
    final double pixelsPerMinute = rowHeight / 30;
    final int startMinutesRelative = s.startMinutes - (startHour * 60);
    
    if (startMinutesRelative < 0) return const SizedBox.shrink();

    final double topOffset = startMinutesRelative * pixelsPerMinute;
    final double blockHeight = s.durationMinutes * pixelsPerMinute;

    final Color bgColor = _getSectionColor(s.section);
    final Color textColor = _getSubjectDarkColor(s.subject);

    return Positioned(
      left: timeColumnWidth + (dayIndex * dayWidth) + 4,
      top: topOffset + 1,
      width: dayWidth - 8,
      height: blockHeight - 2,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: textColor.withValues(alpha: 0.15),
            width: 1.5,
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${s.section} • ${s.room}',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
