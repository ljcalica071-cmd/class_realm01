import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class RetakeConfirmationDialog extends StatelessWidget {
  final String studentName;
  final VoidCallback onConfirm;

  const RetakeConfirmationDialog({
    super.key,
    required this.studentName,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String studentName,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (_) => RetakeConfirmationDialog(
        studentName: studentName,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.catBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.replay_rounded, color: AppTheme.catBlue, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Authorize Retake',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset assessment attempt for $studentName?',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.catBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.catBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                'This will clear their previous attempt, reset infraction warnings, and allow the student to reopen and complete the assessment afresh.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton.primary(
          label: 'Authorize Retake',
          icon: Icons.replay_rounded,
          isSmall: true,
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
        ),
      ],
    );
  }
}
