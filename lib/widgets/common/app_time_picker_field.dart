import 'package:flutter/material.dart';

/// A modern, intuitive Time Picker Field for ClassRealm that replaces the
/// cumbersome Material analog dial clock with a clean digital selector,
/// quick presets, and AM/PM toggles.
class AppTimePickerField extends FormField<TimeOfDay> {
  final String label;
  final String? hint;
  final TimeOfDay? minTime; // Used when scheduled date is today
  final ValueChanged<TimeOfDay>? onTimeSelected;

  AppTimePickerField({
    super.key,
    required this.label,
    this.hint = 'HH:MM AM/PM',
    TimeOfDay? initialTime,
    this.minTime,
    this.onTimeSelected,
    super.validator,
    super.autovalidateMode,
  }) : super(
          initialValue: initialTime ?? const TimeOfDay(hour: 8, minute: 0),
          builder: (FormFieldState<TimeOfDay> field) {
            final theme = Theme.of(field.context);
            final time = field.value;
            final hasTime = time != null;
            final hasError = field.hasError;
            final formattedText = hasTime ? _formatTimeOfDay(time) : '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showAppTimePickerDialog(
                      field.context,
                      initialTime: field.value ?? const TimeOfDay(hour: 8, minute: 0),
                      minTime: minTime,
                      title: 'Select $label',
                    );
                    if (picked != null) {
                      field.didChange(picked);
                      field.validate();
                      onTimeSelected?.call(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      errorText: hasError ? field.errorText : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: hasError
                              ? const Color(0xFFDC2626)
                              : theme.colorScheme.outline.withValues(alpha: 0.3),
                          width: hasError ? 1.5 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: hasError
                              ? const Color(0xFFDC2626)
                              : theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFDC2626),
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFDC2626),
                          width: 2.0,
                        ),
                      ),
                      errorStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 20,
                          color: hasError
                              ? const Color(0xFFDC2626)
                              : (hasTime
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasTime ? formattedText : hint ?? 'HH:MM AM/PM',
                            style: TextStyle(
                              fontSize: 14,
                              color: hasError && !hasTime
                                  ? const Color(0xFFDC2626)
                                  : (hasTime
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                              fontWeight: hasTime ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: hasError
                              ? const Color(0xFFDC2626)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );

  static String format(TimeOfDay time) => _formatTimeOfDay(time);
}

String _formatTimeOfDay(TimeOfDay time) {
  final hourOfPeriod = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minuteStr = time.minute.toString().padLeft(2, '0');
  final periodStr = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${hourOfPeriod.toString().padLeft(2, '0')}:$minuteStr $periodStr';
}

/// Custom Dialog that avoids the Material Analog Clock Dial and provides a sleek
/// digit selector with steppers, presets, and AM/PM toggles.
Future<TimeOfDay?> showAppTimePickerDialog(
  BuildContext context, {
  TimeOfDay? initialTime,
  TimeOfDay? minTime,
  String title = 'Select Start Time',
}) async {
  final theme = Theme.of(context);
  final start = initialTime ?? const TimeOfDay(hour: 8, minute: 0);

  int hour = start.hourOfPeriod == 0 ? 12 : start.hourOfPeriod;
  int minute = start.minute;
  bool isPm = start.period == DayPeriod.pm;

  return showDialog<TimeOfDay>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          int to24Hour(int h, bool pm) {
            if (pm) {
              return h == 12 ? 12 : h + 12;
            } else {
              return h == 12 ? 0 : h;
            }
          }

          final candidate24 = to24Hour(hour, isPm);
          final candidateMinutes = candidate24 * 60 + minute;

          bool isPastMinTime = false;
          if (minTime != null) {
            final minMinutes = minTime.hour * 60 + minTime.minute;
            if (candidateMinutes < minMinutes) {
              isPastMinTime = true;
            }
          }

          final presets = [
            const TimeOfDay(hour: 7, minute: 0),
            const TimeOfDay(hour: 7, minute: 30),
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 8, minute: 30),
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 13, minute: 0),
            const TimeOfDay(hour: 13, minute: 30),
            const TimeOfDay(hour: 14, minute: 0),
            const TimeOfDay(hour: 15, minute: 0),
          ];

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: theme.colorScheme.surface,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.schedule, color: theme.colorScheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Digital Clock Cards + AM/PM Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isPastMinTime
                            ? const Color(0xFFDC2626)
                            : theme.colorScheme.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hour Column
                        _buildDigitSpinBox(
                          theme: theme,
                          value: hour.toString().padLeft(2, '0'),
                          label: 'Hour',
                          onIncrement: () => setDialogState(() {
                            hour = hour >= 12 ? 1 : hour + 1;
                          }),
                          onDecrement: () => setDialogState(() {
                            hour = hour <= 1 ? 12 : hour - 1;
                          }),
                        ),

                        // Colon separator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),

                        // Minute Column
                        _buildDigitSpinBox(
                          theme: theme,
                          value: minute.toString().padLeft(2, '0'),
                          label: 'Minute',
                          onIncrement: () => setDialogState(() {
                            minute = (minute + 5) % 60;
                          }),
                          onDecrement: () => setDialogState(() {
                            minute = (minute - 5 + 60) % 60;
                          }),
                        ),

                        const SizedBox(width: 16),

                        // AM / PM Toggle Column
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildPeriodChip(
                                theme: theme,
                                label: 'AM',
                                isSelected: !isPm,
                                onTap: () => setDialogState(() => isPm = false),
                              ),
                              Container(
                                width: 48,
                                height: 1,
                                color: theme.colorScheme.outline.withValues(alpha: 0.15),
                              ),
                              _buildPeriodChip(
                                theme: theme,
                                label: 'PM',
                                isSelected: isPm,
                                onTap: () => setDialogState(() => isPm = true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isPastMinTime) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.error_outline, size: 14, color: Color(0xFFDC2626)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Start time cannot be in the past for today.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Presets Section
                  Text(
                    'Quick Presets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: presets.map((p) {
                      final p24 = p.hour;
                      final pMin = p.minute;
                      final pTot = p24 * 60 + pMin;
                      final isDisabled = minTime != null && pTot < (minTime.hour * 60 + minTime.minute);

                      final isCurrent = (p.hourOfPeriod == 0 ? 12 : p.hourOfPeriod) == hour &&
                          p.minute == minute &&
                          (p.period == DayPeriod.pm) == isPm;

                      return ActionChip(
                        label: Text(
                          _formatTimeOfDay(p),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isDisabled
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                : (isCurrent ? Colors.white : theme.colorScheme.onSurface),
                          ),
                        ),
                        backgroundColor: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onPressed: isDisabled
                            ? null
                            : () => setDialogState(() {
                                  hour = p.hourOfPeriod == 0 ? 12 : p.hourOfPeriod;
                                  minute = p.minute;
                                  isPm = p.period == DayPeriod.pm;
                                }),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        onPressed: isPastMinTime
                            ? null
                            : () {
                                final finalHour24 = to24Hour(hour, isPm);
                                Navigator.pop(
                                  ctx,
                                  TimeOfDay(hour: finalHour24, minute: minute),
                                );
                              },
                        child: const Text('Confirm Time', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildDigitSpinBox({
  required ThemeData theme,
  required String value,
  required String label,
  required VoidCallback onIncrement,
  required VoidCallback onDecrement,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      InkWell(
        onTap: onIncrement,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Icon(Icons.keyboard_arrow_up, size: 20, color: theme.colorScheme.primary),
        ),
      ),
      Container(
        width: 58,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      InkWell(
        onTap: onDecrement,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Icon(Icons.keyboard_arrow_down, size: 20, color: theme.colorScheme.primary),
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    ],
  );
}

Widget _buildPeriodChip({
  required ThemeData theme,
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 48,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ),
  );
}
