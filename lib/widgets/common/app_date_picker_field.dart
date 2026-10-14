import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A modern, intuitive date-picker field designed to avoid cumbersome month-by-month scrolling.
/// Features quick year selection, month dropdown, dynamic day grid,
/// and live Age calculation (when applicable). Fully integrated as a FormField for real-time validation & error borders.
class AppDatePickerField extends FormField<DateTime> {
  final String label;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime>? onDateSelected;
  final bool showAgeHeader;

  AppDatePickerField({
    super.key,
    required this.label,
    this.hint = 'YYYY-MM-DD',
    DateTime? initialDate,
    this.firstDate,
    this.lastDate,
    this.onDateSelected,
    this.showAgeHeader = true,
    super.validator,
    super.autovalidateMode,
  }) : super(
         initialValue: initialDate,
         builder: (FormFieldState<DateTime> field) {
           final theme = Theme.of(field.context);
           final date = field.value;
           final hasDate = date != null;
           final hasError = field.hasError;
           final formattedText = hasDate ? _formatDate(date) : '';
           final age = hasDate ? _calculateAge(date) : 0;

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(
                     label,
                     style: TextStyle(
                       fontSize: 13,
                       fontWeight: FontWeight.w600,
                       color: theme.colorScheme.onSurface,
                     ),
                   ),
                   if (hasDate && showAgeHeader)
                     Text(
                       'Age: $age yrs old',
                       style: TextStyle(
                         fontSize: 12,
                         fontWeight: FontWeight.w600,
                         color: theme.colorScheme.primary,
                       ),
                     ),
                 ],
               ),
               const SizedBox(height: 6),
               InkWell(
                 onTap: () async {
                   final picked = await showAppDatePickerDialog(
                     field.context,
                     initialDate: field.value,
                     firstDate: firstDate,
                     lastDate: lastDate,
                     title: 'Select Birthdate',
                     icon: Icons.cake_outlined,
                     showAge: true,
                   );
                   if (picked != null) {
                     field.didChange(picked);
                     field.validate();
                     onDateSelected?.call(picked);
                   }
                 },
                 borderRadius: BorderRadius.circular(12),
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
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(
                         color: theme.colorScheme.outline.withValues(
                           alpha: 0.4,
                         ),
                       ),
                     ),
                     enabledBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(
                         color: theme.colorScheme.outline.withValues(
                           alpha: 0.4,
                         ),
                       ),
                     ),
                     focusedBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(
                         color: theme.colorScheme.primary,
                         width: 1.5,
                       ),
                     ),
                     errorBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(
                         color: theme.colorScheme.error,
                         width: 1.5,
                       ),
                     ),
                     focusedErrorBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(
                         color: theme.colorScheme.error,
                         width: 1.5,
                       ),
                     ),
                     errorStyle: TextStyle(
                       fontSize: 12,
                       color: theme.colorScheme.error,
                     ),
                   ),
                   child: Row(
                     children: [
                       Icon(
                         Icons.calendar_today_outlined,
                         size: 20,
                         color: hasError
                             ? theme.colorScheme.error
                             : (hasDate
                                   ? theme.colorScheme.primary
                                   : theme.colorScheme.onSurface.withValues(
                                       alpha: 0.6,
                                     )),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           hasDate ? formattedText : hint ?? 'YYYY-MM-DD',
                           style: TextStyle(
                             fontSize: 14,
                             color: hasError && !hasDate
                                 ? theme.colorScheme.error.withValues(
                                     alpha: 0.7,
                                   )
                                 : (hasDate
                                       ? theme.colorScheme.onSurface
                                       : theme.colorScheme.onSurface.withValues(
                                           alpha: 0.4,
                                         )),
                             fontWeight: hasDate
                                 ? FontWeight.w500
                                 : FontWeight.normal,
                           ),
                         ),
                       ),
                       if (hasDate)
                         const Icon(
                           Icons.check_circle,
                           size: 18,
                           color: Colors.green,
                         )
                       else
                         Icon(
                           Icons.arrow_drop_down,
                           color: hasError
                               ? theme.colorScheme.error
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

  static int _calculateAge(DateTime birthDate) => _calculateAgeHelper(birthDate);

  static String _formatDate(DateTime date) => _formatDateHelper(date);
}

int _calculateAgeHelper(DateTime birthDate) {
  final now = DateTime.now();
  int age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

String _formatDateHelper(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Unified date picker dialog featuring Year dropdown, Month dropdown, and Day of Month grid.
Future<DateTime?> showAppDatePickerDialog(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'Select Date',
  IconData icon = Icons.calendar_month_outlined,
  bool showAge = false,
}) async {
  final theme = Theme.of(context);
  final now = DateTime.now();
  final effectiveMin =
      firstDate ?? (showAge ? DateTime(1950, 1, 1) : DateTime(2020, 1, 1));
  final effectiveMax =
      lastDate ??
      (showAge
          ? DateTime(now.year - 18, now.month, now.day)
          : DateTime(now.year + 10, 12, 31));

  DateTime tempDate = initialDate ?? (showAge ? DateTime(1995, 1, 1) : now);
  if (tempDate.isAfter(effectiveMax)) tempDate = effectiveMax;
  if (tempDate.isBefore(effectiveMin)) tempDate = effectiveMin;

  int selectedYear = tempDate.year;
  int selectedMonth = tempDate.month;
  int selectedDay = tempDate.day;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final daysInMonth = DateUtils.getDaysInMonth(
            selectedYear,
            selectedMonth,
          );
          if (selectedDay > daysInMonth) selectedDay = daysInMonth;

          final currentCandidate = DateTime(
            selectedYear,
            selectedMonth,
            selectedDay,
          );
          final age = _calculateAgeHelper(currentCandidate);
          final isUnderage = showAge && currentCandidate.isAfter(effectiveMax);

          final minYear = math.min(effectiveMin.year, effectiveMax.year);
          final maxYear = math.max(effectiveMin.year, effectiveMax.year);
          final yearList = List.generate(
            maxYear - minYear + 1,
            (index) => maxYear - index,
          );

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Optional Age Badge Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                icon,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatDateHelper(currentCandidate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showAge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isUnderage
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isUnderage
                                  ? Colors.redAccent.withValues(alpha: 0.4)
                                  : Colors.green.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isUnderage ? 'Under 18' : 'Age: $age',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUnderage
                                  ? Colors.red
                                  : Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick Selectors Row (Year & Month Dropdowns)
                  Row(
                    children: [
                      // Year Dropdown
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Year',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: selectedYear,
                                  isExpanded: true,
                                  menuMaxHeight: 300,
                                  items: yearList
                                      .map(
                                        (yr) => DropdownMenuItem(
                                          value: yr,
                                          child: Text(
                                            '$yr',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (yr) {
                                    if (yr != null) {
                                      setDialogState(() => selectedYear = yr);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Month Dropdown
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Month',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: selectedMonth,
                                  isExpanded: true,
                                  menuMaxHeight: 300,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text(
                                        '01 - January',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text(
                                        '02 - February',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text(
                                        '03 - March',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text(
                                        '04 - April',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 5,
                                      child: Text(
                                        '05 - May',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 6,
                                      child: Text(
                                        '06 - June',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 7,
                                      child: Text(
                                        '07 - July',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 8,
                                      child: Text(
                                        '08 - August',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 9,
                                      child: Text(
                                        '09 - September',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 10,
                                      child: Text(
                                        '10 - October',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 11,
                                      child: Text(
                                        '11 - November',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 12,
                                      child: Text(
                                        '12 - December',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                  onChanged: (m) {
                                    if (m != null) {
                                      setDialogState(() => selectedMonth = m);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Day Selection Grid
                  Text(
                    'Day of Month',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                            childAspectRatio: 1.1,
                          ),
                      itemCount: daysInMonth,
                      itemBuilder: (ctx, idx) {
                        final dayNum = idx + 1;
                        final isSelected = dayNum == selectedDay;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              setDialogState(() => selectedDay = dayNum),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isUnderage
                              ? Colors.grey
                              : theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Confirm Date'),
                        onPressed: isUnderage
                            ? null
                            : () => Navigator.pop(
                                ctx,
                                DateTime(
                                  selectedYear,
                                  selectedMonth,
                                  selectedDay,
                                ),
                              ),
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
