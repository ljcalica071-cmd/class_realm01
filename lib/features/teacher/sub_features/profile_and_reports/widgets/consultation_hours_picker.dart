import 'package:flutter/material.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';

/// Class representing consultation start and end times for a specific day.
class DayConsultationTime {
  final TimeOfDay start;
  final TimeOfDay end;

  const DayConsultationTime({required this.start, required this.end});

  DayConsultationTime copyWith({TimeOfDay? start, TimeOfDay? end}) {
    return DayConsultationTime(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

/// Interactive consultation schedule builder allowing teachers to:
/// - Configure specific hours per day (e.g. Mon 10:00 AM - 11:00 AM, Tue 03:00 PM - 04:00 PM)
/// - Pick digital time using ClassRealm's standard [showAppTimePickerDialog]
/// - Stretch day boxes edge-to-edge across the container
/// - Fully optional: can clear individual days or wipe all consultation hours
class ConsultationHoursPicker extends StatefulWidget {
  final String? initialValue;
  final void Function(String? formattedValue, bool isValid) onChanged;

  const ConsultationHoursPicker({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<ConsultationHoursPicker> createState() =>
      _ConsultationHoursPickerState();
}

class _ConsultationHoursPickerState extends State<ConsultationHoursPicker> {
  static const List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const Map<String, String> _fullDayNames = {
    'Mon': 'Monday',
    'Tue': 'Tuesday',
    'Wed': 'Wednesday',
    'Thu': 'Thursday',
    'Fri': 'Friday',
    'Sat': 'Saturday',
    'Sun': 'Sunday',
  };

  final Map<String, DayConsultationTime> _daySchedules = {};
  String _activeDay = 'Mon';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _parseInitialValue(widget.initialValue);
  }

  void _parseInitialValue(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == 'Not specified') {
      return;
    }

    try {
      final cleanRaw = raw.trim();
      // Handle pipe-delimited or comma-delimited multi-day schedule strings
      // e.g. "Mon 10:00 AM - 11:00 AM | Tue 03:00 PM - 04:00 PM"
      // or "Mon, Wed • 01:00 PM - 03:00 PM"
      // or "Mon, Wed 01:00 PM - 03:00 PM"
      final segments = cleanRaw.contains('|')
          ? cleanRaw.split('|')
          : (cleanRaw.contains('•') ? [cleanRaw] : [cleanRaw]);

      for (final segment in segments) {
        final seg = segment.trim();
        if (seg.isEmpty) continue;

        // Extract days
        final daysInSegment = <String>[];
        for (final d in _weekDays) {
          if (RegExp(r'\b' + d + r'\b', caseSensitive: false).hasMatch(seg)) {
            daysInSegment.add(d);
          }
        }

        // Extract time range
        final times = _extractStartAndEnd(seg);
        if (times != null && daysInSegment.isNotEmpty) {
          for (final d in daysInSegment) {
            _daySchedules[d] = DayConsultationTime(
              start: times.$1,
              end: times.$2,
            );
          }
        }
      }

      if (_daySchedules.isNotEmpty) {
        // Default active day to the first configured day
        _activeDay = _weekDays.firstWhere(
          (d) => _daySchedules.containsKey(d),
          orElse: () => 'Mon',
        );
      }
    } catch (_) {
      // Fallback gracefully on parsing edge cases
    }
    _validateAndEmit();
  }

  (TimeOfDay, TimeOfDay)? _extractStartAndEnd(String text) {
    try {
      // Look for pattern like "10:00 AM - 11:00 AM" or "01:00 PM to 03:00 PM"
      final timePartMatch = RegExp(
        r'(\d{1,2}:\d{2}\s*(?:AM|PM))\s*(?:-|to)\s*(\d{1,2}:\d{2}\s*(?:AM|PM))',
        caseSensitive: false,
      ).firstMatch(text);

      if (timePartMatch != null) {
        final start = _parseTimeOfDay(timePartMatch.group(1)!);
        final end = _parseTimeOfDay(timePartMatch.group(2)!);
        if (start != null && end != null) {
          return (start, end);
        }
      }
    } catch (_) {}
    return null;
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final rawDigits = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = rawDigits.split(':');
      if (parts.length == 2) {
        int hour = int.parse(parts[0].trim());
        final int minute = int.parse(parts[1].trim());
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  void _validateAndEmit() {
    // If empty: perfectly valid, teacher chose not to specify consultation hours
    if (_daySchedules.isEmpty) {
      _validationError = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(null, true);
      });
      return;
    }

    // Validate each configured day's time range
    String? foundError;
    for (final entry in _daySchedules.entries) {
      final day = entry.key;
      final schedule = entry.value;

      final startMinutes = schedule.start.hour * 60 + schedule.start.minute;
      final endMinutes = schedule.end.hour * 60 + schedule.end.minute;

      if (endMinutes <= startMinutes) {
        foundError =
            '${_fullDayNames[day]}: End time must be later than start time.';
        break;
      }

      if (endMinutes - startMinutes < 30) {
        foundError =
            '${_fullDayNames[day]}: Duration must be at least 30 minutes.';
        break;
      }
    }

    _validationError = foundError;

    // Group days that have identical start and end times for clean storage and display
    final timeToDays = <String, List<String>>{};
    for (final day in _weekDays) {
      if (_daySchedules.containsKey(day)) {
        final sched = _daySchedules[day]!;
        final key =
            '${_formatTimeOfDay(sched.start)} - ${_formatTimeOfDay(sched.end)}';
        timeToDays.putIfAbsent(key, () => []).add(day);
      }
    }

    final formattedSegments = <String>[];
    for (final entry in timeToDays.entries) {
      final daysStr = entry.value.join(', ');
      formattedSegments.add('$daysStr ${entry.key}');
    }

    final result = formattedSegments.join(' | ');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(result, foundError == null);
    });
  }

  Future<void> _pickTimeForActiveDay({required bool isStart}) async {
    final current = _daySchedules[_activeDay];
    final defaultEnd = (current?.start != null)
        ? TimeOfDay(
            hour: (current!.start.hour + 1).clamp(0, 23),
            minute: current.start.minute,
          )
        : const TimeOfDay(hour: 11, minute: 0);

    final initial = isStart
        ? (current?.start ?? const TimeOfDay(hour: 9, minute: 0))
        : (current?.end ?? defaultEnd);

    final picked = await showAppTimePickerDialog(
      context,
      initialTime: initial,
      title: isStart
          ? 'Select Start Time (${_fullDayNames[_activeDay]})'
          : 'Select End Time (${_fullDayNames[_activeDay]})',
    );

    if (picked != null) {
      setState(() {
        final existing =
            _daySchedules[_activeDay] ??
            DayConsultationTime(
              start: const TimeOfDay(hour: 9, minute: 0),
              end: const TimeOfDay(hour: 11, minute: 0),
            );

        if (isStart) {
          _daySchedules[_activeDay] = existing.copyWith(start: picked);
          final sM = picked.hour * 60 + picked.minute;
          final eM = existing.end.hour * 60 + existing.end.minute;
          if (eM <= sM) {
            final nextHour = (picked.hour + 1).clamp(0, 23);
            _daySchedules[_activeDay] = _daySchedules[_activeDay]!.copyWith(
              end: TimeOfDay(hour: nextHour, minute: picked.minute),
            );
          }
        } else {
          var finalEnd = picked;
          if (finalEnd.period == DayPeriod.am &&
              finalEnd.hourOfPeriod >= 1 &&
              finalEnd.hourOfPeriod <= 6 &&
              existing.start.hour >= 7) {
            finalEnd = TimeOfDay(
              hour: finalEnd.hourOfPeriod + 12,
              minute: finalEnd.minute,
            );
          }
          _daySchedules[_activeDay] = existing.copyWith(end: finalEnd);
        }
        _validateAndEmit();
      });
    }
  }

  void _toggleOrAddDay(String day) {
    setState(() {
      _activeDay = day;
      if (!_daySchedules.containsKey(day)) {
        // Add with sensible default: 09:00 AM - 11:00 AM or copy from last active schedule
        final template = _daySchedules.isNotEmpty
            ? _daySchedules.values.last
            : const DayConsultationTime(
                start: TimeOfDay(hour: 9, minute: 0),
                end: TimeOfDay(hour: 11, minute: 0),
              );
        _daySchedules[day] = DayConsultationTime(
          start: template.start,
          end: template.end,
        );
      }
      _validateAndEmit();
    });
  }

  void _removeDay(String day) {
    setState(() {
      _daySchedules.remove(day);
      _validateAndEmit();
    });
  }

  void _clearAll() {
    setState(() {
      _daySchedules.clear();
      _validationError = null;
      _validateAndEmit();
    });
  }

  void _applyToMonFri() {
    final activeSchedule =
        _daySchedules[_activeDay] ??
        const DayConsultationTime(
          start: TimeOfDay(hour: 9, minute: 0),
          end: TimeOfDay(hour: 11, minute: 0),
        );

    setState(() {
      for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
        _daySchedules[d] = DayConsultationTime(
          start: activeSchedule.start,
          end: activeSchedule.end,
        );
      }
      _validateAndEmit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSchedule = _daySchedules[_activeDay];
    final hasHoursForActiveDay = activeSchedule != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _validationError != null
              ? const Color(0xFFDC2626)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _applyToMonFri,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mon–Fri',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_daySchedules.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Edge-to-Edge Day Selector: all 7 days stretched equally across full row
          Row(
            children: _weekDays.map((day) {
              final isConfigured = _daySchedules.containsKey(day);
              final isActive = _activeDay == day;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (isActive && isConfigured) {
                          // Tap already active configured day toggles removal
                          _removeDay(day);
                        } else {
                          _toggleOrAddDay(day);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isConfigured
                              ? theme.colorScheme.primary
                              : (isActive
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      )
                                    : theme.colorScheme.surface),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? (isConfigured
                                      ? Colors.white
                                      : theme.colorScheme.primary)
                                : (isConfigured
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.5)),
                            width: isActive ? 2.0 : 1.0,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: (isConfigured || isActive)
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isConfigured
                                ? Colors.white
                                : (isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.8,
                                        )),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Active Day Configuration Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_fullDayNames[_activeDay]} Schedule',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (hasHoursForActiveDay)
                      InkWell(
                        onTap: () => _removeDay(_activeDay),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            'Remove $_activeDay',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (hasHoursForActiveDay) ...[
                  // Start and End Time Pickers
                  Row(
                    children: [
                      // Start Time Button
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTimeForActiveDay(isStart: true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeOfDay(activeSchedule.start),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      // End Time Button
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTimeForActiveDay(isStart: false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeOfDay(activeSchedule.end),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Not set for this day
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'No consultation hours set for ${_fullDayNames[_activeDay]}.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _toggleOrAddDay(_activeDay),
                        icon: const Icon(Icons.add, size: 14),
                        label: Text('Set $_activeDay Hours'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Configured Schedule Chips Summary
          if (_daySchedules.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Configured Schedule:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _weekDays.where((d) => _daySchedules.containsKey(d)).map((
                d,
              ) {
                final s = _daySchedules[d]!;
                return Chip(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  label: Text(
                    '$d: ${_formatTimeOfDay(s.start)} - ${_formatTimeOfDay(s.end)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 13),
                  onDeleted: () => _removeDay(d),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'No consultation schedule set (Optional).',
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],

          // Inline Validation Error (if any day duration is invalid)
          if (_validationError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _validationError!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
