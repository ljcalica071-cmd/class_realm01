import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A modern, interactive Duration Picker Field for ClassRealm assessments.
/// Replaces plain numeric textfields with a dedicated picker modal
/// featuring steppers, direct input, live hour/min breakdown, quick presets
/// (30m, 45m, 60m, 90m, 120m, 150m, 180m), and strict validation (1 to 180 mins).
class AppDurationPickerField extends FormField<int> {
  final String label;
  final String? hint;
  final ValueChanged<int>? onDurationSelected;

  AppDurationPickerField({
    super.key,
    required this.label,
    this.hint = 'Select Duration',
    int? initialDurationMinutes,
    this.onDurationSelected,
    super.validator,
    super.autovalidateMode,
  }) : super(
         initialValue: initialDurationMinutes ?? 60,
         builder: (FormFieldState<int> field) {
           final theme = Theme.of(field.context);
           final minutes = field.value;
           final hasValue = minutes != null && minutes > 0;
           final hasError = field.hasError;
           final formattedText = hasValue ? format(minutes) : '';

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
                   final picked = await showAppDurationPickerDialog(
                     field.context,
                     initialMinutes: field.value ?? 60,
                     title: label.replaceAll('*', '').trim(),
                   );
                   if (picked != null) {
                     field.didChange(picked);
                     field.validate();
                     onDurationSelected?.call(picked);
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
                         Icons.timelapse_outlined,
                         size: 20,
                         color: hasError
                             ? const Color(0xFFDC2626)
                             : (hasValue
                                   ? theme.colorScheme.primary
                                   : theme.colorScheme.onSurface.withValues(
                                       alpha: 0.6,
                                     )),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           hasValue ? formattedText : hint ?? 'Select Duration',
                           style: TextStyle(
                             fontSize: 14,
                             color: hasError && !hasValue
                                 ? const Color(0xFFDC2626)
                                 : (hasValue
                                       ? theme.colorScheme.onSurface
                                       : theme.colorScheme.onSurface.withValues(
                                           alpha: 0.4,
                                         )),
                             fontWeight: hasValue
                                 ? FontWeight.w600
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

  static String format(int minutes) {
    if (minutes <= 0) return '0 mins';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (hours > 0 && remainingMins > 0) {
      return '$minutes mins (${hours}h ${remainingMins}m)';
    } else if (hours > 0) {
      return '$minutes mins ($hours ${hours == 1 ? "hr" : "hrs"})';
    }
    return '$minutes mins';
  }
}

/// Interactive Duration Picker Dialog
Future<int?> showAppDurationPickerDialog(
  BuildContext context, {
  required int initialMinutes,
  String title = 'Select Duration',
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _DurationPickerDialog(
      initialMinutes: initialMinutes,
      title: title,
    ),
  );
}

class _DurationPickerDialog extends StatefulWidget {
  final int initialMinutes;
  final String title;

  const _DurationPickerDialog({
    required this.initialMinutes,
    required this.title,
  });

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _minutes;
  late TextEditingController _textCtrl;
  String? _inlineError;

  static const List<int> _presets = [30, 45, 60, 90, 120, 150, 180];

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes.clamp(1, 180);
    _textCtrl = TextEditingController(text: _minutes.toString());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _updateMinutes(int val) {
    final clamped = val.clamp(1, 180);
    setState(() {
      _minutes = clamped;
      _textCtrl.text = clamped.toString();
      _textCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _textCtrl.text.length),
      );
      _validate();
    });
  }

  void _validate() {
    if (_minutes < 1) {
      _inlineError = 'Duration must be at least 1 minute.';
    } else if (_minutes > 180) {
      _inlineError = 'Maximum duration allowed is 180 minutes (3 hours).';
    } else {
      _inlineError = null;
    }
  }

  String _formatBreakdown(int totalMins) {
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    if (h > 0 && m > 0) {
      return '$h hour${h > 1 ? "s" : ""} $m minute${m > 1 ? "s" : ""}';
    } else if (h > 0) {
      return '$h hour${h > 1 ? "s" : ""}';
    }
    return '$m minute${m > 1 ? "s" : ""}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                      Icons.timelapse,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Upfront Golden Rule Note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Allowed test cooldown: 1 to 180 minutes (max 3 hours).',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Digital Stepper Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _inlineError != null
                        ? const Color(0xFFDC2626)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE2E8F0)),
                    width: _inlineError != null ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // -15m
                        IconButton.filledTonal(
                          tooltip: '-15 mins',
                          icon: const Text(
                            '-15',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _minutes > 15
                              ? () => _updateMinutes(_minutes - 15)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        // -5m
                        IconButton.filledTonal(
                          tooltip: '-5 mins',
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _minutes > 5
                              ? () => _updateMinutes(_minutes - 5)
                              : null,
                        ),
                        const SizedBox(width: 14),

                        // Center Input Box
                        Container(
                          width: 84,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _textCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null) {
                                setState(() {
                                  _minutes = parsed;
                                  _validate();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 14),

                        // +5m
                        IconButton.filledTonal(
                          tooltip: '+5 mins',
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: _minutes < 180
                              ? () => _updateMinutes(_minutes + 5)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        // +15m
                        IconButton.filledTonal(
                          tooltip: '+15 mins',
                          icon: const Text(
                            '+15',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _minutes <= 165
                              ? () => _updateMinutes(_minutes + 15)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Minutes (${_formatBreakdown(_minutes)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _inlineError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Quick Presets
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
                runSpacing: 8,
                children: _presets.map((preset) {
                  final isSelected = _minutes == preset;
                  return InkWell(
                    onTap: () => _updateMinutes(preset),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Text(
                        '$preset m',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _inlineError == null && _minutes >= 1 && _minutes <= 180
                        ? () => Navigator.pop(context, _minutes)
                        : null,
                    child: const Text(
                      'Confirm Duration',
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
