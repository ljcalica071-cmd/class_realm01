import 'package:flutter/material.dart';

/// A modern, intuitive date-picker field designed to avoid cumbersome month-by-month scrolling.
/// Features quick year selection (1950 to 18 years ago), month buttons, dynamic day grid,
/// and live Age calculation.
class AppDatePickerField extends StatefulWidget {
  final String label;
  final String? hint;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime>? onDateSelected;
  final String? Function(DateTime?)? validator;

  const AppDatePickerField({
    super.key,
    required this.label,
    this.hint = 'YYYY-MM-DD',
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.onDateSelected,
    this.validator,
  });

  @override
  State<AppDatePickerField> createState() => _AppDatePickerFieldState();
}

class _AppDatePickerFieldState extends State<AppDatePickerField> {
  DateTime? _selectedDate;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _showModernDatePickerDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final maxAllowedDate = widget.lastDate ?? DateTime(now.year - 18, now.month, now.day);
    final minAllowedDate = widget.firstDate ?? DateTime(1950, 1, 1);

    DateTime tempDate = _selectedDate ?? DateTime(1995, 1, 1);
    if (tempDate.isAfter(maxAllowedDate)) tempDate = maxAllowedDate;
    if (tempDate.isBefore(minAllowedDate)) tempDate = minAllowedDate;

    int selectedYear = tempDate.year;
    int selectedMonth = tempDate.month;
    int selectedDay = tempDate.day;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final daysInMonth = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
            if (selectedDay > daysInMonth) selectedDay = daysInMonth;

            final currentCandidate = DateTime(selectedYear, selectedMonth, selectedDay);
            final age = _calculateAge(currentCandidate);
            final isUnderage = currentCandidate.isAfter(maxAllowedDate);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title & Age Badge Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.cake_outlined, color: theme.colorScheme.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Birthdate',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                                ),
                                Text(
                                  _formatDate(currentCandidate),
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isUnderage ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isUnderage ? Colors.redAccent.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isUnderage ? 'Under 18' : 'Age: $age',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUnderage ? Colors.red : Colors.green[800],
                            ),
                          ),
                        ),
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
                              Text('Year', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedYear,
                                    isExpanded: true,
                                    menuMaxHeight: 300,
                                    items: List.generate(
                                      maxAllowedDate.year - minAllowedDate.year + 1,
                                      (index) => maxAllowedDate.year - index,
                                    ).map((yr) => DropdownMenuItem(value: yr, child: Text('$yr', style: const TextStyle(fontSize: 14)))).toList(),
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
                              Text('Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedMonth,
                                    isExpanded: true,
                                    menuMaxHeight: 300,
                                    items: const [
                                      DropdownMenuItem(value: 1, child: Text('01 - January', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 2, child: Text('02 - February', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 3, child: Text('03 - March', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 4, child: Text('04 - April', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 5, child: Text('05 - May', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 6, child: Text('06 - June', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 7, child: Text('07 - July', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 8, child: Text('08 - August', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 9, child: Text('09 - September', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 10, child: Text('10 - October', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 11, child: Text('11 - November', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 12, child: Text('12 - December', style: TextStyle(fontSize: 13))),
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
                    Text('Day of Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                            onTap: () => setDialogState(() => selectedDay = dayNum),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
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
                            backgroundColor: isUnderage ? Colors.grey : theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Confirm Date'),
                          onPressed: isUnderage
                              ? null
                              : () => Navigator.pop(ctx, DateTime(selectedYear, selectedMonth, selectedDay)),
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

    if (result != null) {
      setState(() {
        _selectedDate = result;
        _errorText = widget.validator != null ? widget.validator!(result) : null;
      });
      widget.onDateSelected?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDate = _selectedDate != null;
    final formattedText = hasDate ? _formatDate(_selectedDate!) : '';
    final age = hasDate ? _calculateAge(_selectedDate!) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (hasDate)
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
          onTap: () => _showModernDatePickerDialog(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _errorText != null
                    ? theme.colorScheme.error
                    : (hasDate ? theme.colorScheme.primary.withValues(alpha: 0.6) : theme.colorScheme.outline.withValues(alpha: 0.4)),
                width: hasDate ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: hasDate ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasDate ? formattedText : widget.hint ?? 'YYYY-MM-DD',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasDate ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: hasDate ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                if (hasDate)
                  const Icon(Icons.check_circle, size: 18, color: Colors.green)
                else
                  Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
              const SizedBox(width: 4),
              Text(
                _errorText!,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
