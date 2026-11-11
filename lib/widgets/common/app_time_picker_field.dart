import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                     initialTime:
                         field.value ?? const TimeOfDay(hour: 8, minute: 0),
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
                         color: theme.colorScheme.outline.withValues(
                           alpha: 0.4,
                         ),
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
                                   : theme.colorScheme.onSurface.withValues(
                                       alpha: 0.6,
                                     )),
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
                                       : theme.colorScheme.onSurface.withValues(
                                           alpha: 0.4,
                                         )),
                             fontWeight: hasTime
                                 ? FontWeight.w500
                                 : FontWeight.normal,
                           ),
                         ),
                       ),
                       Icon(
                         Icons.arrow_drop_down,
                         color: hasError
                             ? const Color(0xFFDC2626)
                             : theme.colorScheme.onSurface.withValues(
                                 alpha: 0.6,
                               ),
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
/// digit selector with steppers, presets, AM/PM toggles, and direct numeric typing
/// with strict digit-only validation.
Future<TimeOfDay?> showAppTimePickerDialog(
  BuildContext context, {
  TimeOfDay? initialTime,
  TimeOfDay? minTime,
  TimeOfDay? maxTime,
  String title = 'Select Start Time',
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (ctx) => _AppTimePickerDialog(
      initialTime: initialTime,
      minTime: minTime,
      maxTime: maxTime,
      title: title,
    ),
  );
}

class _AppTimePickerDialog extends StatefulWidget {
  final TimeOfDay? initialTime;
  final TimeOfDay? minTime;
  final TimeOfDay? maxTime;
  final String title;

  const _AppTimePickerDialog({
    this.initialTime,
    this.minTime,
    this.maxTime,
    required this.title,
  });

  @override
  State<_AppTimePickerDialog> createState() => _AppTimePickerDialogState();
}

class _AppTimePickerDialogState extends State<_AppTimePickerDialog> {
  late int _hour;
  late int _minute;
  late bool _isPm;

  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  late final FocusNode _hourFocus;
  late final FocusNode _minuteFocus;

  String? _hourError;
  String? _minuteError;

  @override
  void initState() {
    super.initState();
    final start = widget.initialTime ?? const TimeOfDay(hour: 8, minute: 0);
    _hour = start.hourOfPeriod == 0 ? 12 : start.hourOfPeriod;
    _minute = start.minute;
    _isPm = start.period == DayPeriod.pm;

    _hourCtrl = TextEditingController(text: _hour.toString().padLeft(2, '0'));
    _minuteCtrl = TextEditingController(
      text: _minute.toString().padLeft(2, '0'),
    );
    _hourFocus = FocusNode();
    _minuteFocus = FocusNode();

    _hourFocus.addListener(_onHourFocusChange);
    _minuteFocus.addListener(_onMinuteFocusChange);
  }

  void _onHourFocusChange() {
    if (_hourFocus.hasFocus) {
      _hourCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _hourCtrl.text.length,
      );
    } else {
      if (_hourError == null && _hour >= 1 && _hour <= 12) {
        final formatted = _hour.toString().padLeft(2, '0');
        if (_hourCtrl.text != formatted) {
          _hourCtrl.text = formatted;
        }
      }
    }
  }

  void _onMinuteFocusChange() {
    if (_minuteFocus.hasFocus) {
      _minuteCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _minuteCtrl.text.length,
      );
    } else {
      if (_minuteError == null && _minute >= 0 && _minute <= 59) {
        final formatted = _minute.toString().padLeft(2, '0');
        if (_minuteCtrl.text != formatted) {
          _minuteCtrl.text = formatted;
        }
      }
    }
  }

  @override
  void dispose() {
    _hourFocus.removeListener(_onHourFocusChange);
    _minuteFocus.removeListener(_onMinuteFocusChange);
    _hourFocus.dispose();
    _minuteFocus.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onHourChanged(String val) {
    setState(() {
      final trimmed = val.trim();
      if (trimmed.isEmpty) {
        _hourError = 'Hour is required (1-12).';
        return;
      }
      final parsed = int.tryParse(trimmed);
      if (parsed == null || parsed < 1 || parsed > 12) {
        _hourError = 'Hour must be between 1 and 12.';
      } else {
        _hourError = null;
        _hour = parsed;
      }
    });
  }

  void _onMinuteChanged(String val) {
    setState(() {
      final trimmed = val.trim();
      if (trimmed.isEmpty) {
        _minuteError = 'Minute is required (00-59).';
        return;
      }
      final parsed = int.tryParse(trimmed);
      if (parsed == null || parsed < 0 || parsed > 59) {
        _minuteError = 'Minute must be between 00 and 59.';
      } else {
        _minuteError = null;
        _minute = parsed;
      }
    });
  }

  void _incrementHour() {
    setState(() {
      _hour = _hour >= 12 ? 1 : _hour + 1;
      _hourCtrl.text = _hour.toString().padLeft(2, '0');
      _hourError = null;
    });
  }

  void _decrementHour() {
    setState(() {
      _hour = _hour <= 1 ? 12 : _hour - 1;
      _hourCtrl.text = _hour.toString().padLeft(2, '0');
      _hourError = null;
    });
  }

  void _incrementMinute() {
    setState(() {
      _minute = (_minute + 5) % 60;
      _minuteCtrl.text = _minute.toString().padLeft(2, '0');
      _minuteError = null;
    });
  }

  void _decrementMinute() {
    setState(() {
      _minute = (_minute - 5 + 60) % 60;
      _minuteCtrl.text = _minute.toString().padLeft(2, '0');
      _minuteError = null;
    });
  }

  int _to24Hour(int h, bool pm) {
    if (pm) {
      return h == 12 ? 12 : h + 12;
    } else {
      return h == 12 ? 0 : h;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate24 = _to24Hour(_hour, _isPm);
    final candidateMinutes = candidate24 * 60 + _minute;

    bool isOutOfBounds = false;
    String? boundsError;
    if (widget.minTime != null) {
      final minMinutes = widget.minTime!.hour * 60 + widget.minTime!.minute;
      if (candidateMinutes < minMinutes) {
        isOutOfBounds = true;
        boundsError =
            'Time cannot be earlier than ${AppTimePickerField.format(widget.minTime!)}.';
      }
    }
    if (widget.maxTime != null) {
      final maxMinutes = widget.maxTime!.hour * 60 + widget.maxTime!.minute;
      if (candidateMinutes > maxMinutes) {
        isOutOfBounds = true;
        boundsError =
            'Time cannot be later than ${AppTimePickerField.format(widget.maxTime!)}.';
      }
    }

    final hasValidationError = _hourError != null || _minuteError != null;
    final isConfirmDisabled = hasValidationError || isOutOfBounds;

    final presets = const [
      TimeOfDay(hour: 7, minute: 0),
      TimeOfDay(hour: 7, minute: 30),
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 8, minute: 30),
      TimeOfDay(hour: 9, minute: 0),
      TimeOfDay(hour: 10, minute: 0),
      TimeOfDay(hour: 13, minute: 0),
      TimeOfDay(hour: 13, minute: 30),
      TimeOfDay(hour: 14, minute: 0),
      TimeOfDay(hour: 15, minute: 0),
      TimeOfDay(hour: 17, minute: 0),
      TimeOfDay(hour: 18, minute: 0),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
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
                    child: Icon(
                      Icons.schedule,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOutOfBounds
                        ? const Color(0xFFDC2626)
                        : theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hour Column
                    _buildDigitInputSpinBox(
                      theme: theme,
                      controller: _hourCtrl,
                      focusNode: _hourFocus,
                      label: 'Hour',
                      hasError: _hourError != null,
                      onChanged: _onHourChanged,
                      onIncrement: _incrementHour,
                      onDecrement: _decrementHour,
                    ),

                    // Colon separator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),

                    // Minute Column
                    _buildDigitInputSpinBox(
                      theme: theme,
                      controller: _minuteCtrl,
                      focusNode: _minuteFocus,
                      label: 'Minute',
                      hasError: _minuteError != null,
                      onChanged: _onMinuteChanged,
                      onIncrement: _incrementMinute,
                      onDecrement: _decrementMinute,
                    ),

                    const SizedBox(width: 16),

                    // AM / PM Toggle Column
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildPeriodChip(
                            theme: theme,
                            label: 'AM',
                            isSelected: !_isPm,
                            onTap: () => setState(() => _isPm = false),
                          ),
                          Container(
                            width: 48,
                            height: 1,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          _buildPeriodChip(
                            theme: theme,
                            label: 'PM',
                            isSelected: _isPm,
                            onTap: () => setState(() => _isPm = true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (hasValidationError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _hourError ?? _minuteError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isOutOfBounds && boundsError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        boundsError,
                        style: const TextStyle(
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
                  final isDisabled = (widget.minTime != null &&
                          pTot <
                              (widget.minTime!.hour * 60 +
                                  widget.minTime!.minute)) ||
                      (widget.maxTime != null &&
                          pTot >
                              (widget.maxTime!.hour * 60 +
                                  widget.maxTime!.minute));

                  final isCurrent =
                      (p.hourOfPeriod == 0 ? 12 : p.hourOfPeriod) == _hour &&
                      p.minute == _minute &&
                      (p.period == DayPeriod.pm) == _isPm;

                  return ActionChip(
                    label: Text(
                      _formatTimeOfDay(p),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isDisabled
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                            : (isCurrent
                                  ? Colors.white
                                  : theme.colorScheme.onSurface),
                      ),
                    ),
                    backgroundColor: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onPressed: isDisabled
                        ? null
                        : () => setState(() {
                            _hour = p.hourOfPeriod == 0 ? 12 : p.hourOfPeriod;
                            _minute = p.minute;
                            _isPm = p.period == DayPeriod.pm;
                            _hourCtrl.text = _hour.toString().padLeft(2, '0');
                            _minuteCtrl.text = _minute.toString().padLeft(
                              2,
                              '0',
                            );
                            _hourError = null;
                            _minuteError = null;
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
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onPressed: isConfirmDisabled
                        ? null
                        : () {
                            final finalHour24 = _to24Hour(_hour, _isPm);
                            Navigator.pop(
                              context,
                              TimeOfDay(hour: finalHour24, minute: _minute),
                            );
                          },
                    child: const Text(
                      'Confirm Time',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildDigitInputSpinBox({
  required ThemeData theme,
  required TextEditingController controller,
  required FocusNode focusNode,
  required String label,
  required bool hasError,
  required ValueChanged<String> onChanged,
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
          child: Icon(
            Icons.keyboard_arrow_up,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      Container(
        width: 60,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasError
                ? const Color(0xFFDC2626)
                : theme.colorScheme.outline.withValues(alpha: 0.25),
            width: hasError ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: hasError
                ? const Color(0xFFDC2626)
                : theme.colorScheme.onSurface,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
      InkWell(
        onTap: onDecrement,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: theme.colorScheme.primary,
          ),
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
          color: isSelected
              ? Colors.white
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ),
  );
}
