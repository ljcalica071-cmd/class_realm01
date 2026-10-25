import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class KickStudentAlertDialog extends StatefulWidget {
  final String studentName;
  final ValueChanged<String> onConfirm;

  const KickStudentAlertDialog({
    super.key,
    required this.studentName,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String studentName,
    required ValueChanged<String> onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => KickStudentAlertDialog(
        studentName: studentName,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<KickStudentAlertDialog> createState() => _KickStudentAlertDialogState();
}

class _KickStudentAlertDialogState extends State<KickStudentAlertDialog> {
  final TextEditingController _reasonController = TextEditingController(
    text: 'Repeated tab-switch / anti-cheating violation',
  );

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
              color: AppTheme.catRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.gavel, color: AppTheme.catRed, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Disqualify Student',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to kick and disqualify ${widget.studentName}?',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.catRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.catRed.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.catRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This will immediately lock the examination session and record a score of 0 for academic dishonesty.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reason for Disqualification',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surface,
                hintText: 'Enter specific infraction notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
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
        AppButton.danger(
          label: 'Kick & Disqualify',
          icon: Icons.gavel,
          isSmall: true,
          onPressed: () {
            final reason = _reasonController.text.trim();
            Navigator.of(context).pop();
            widget.onConfirm(reason.isEmpty ? 'Academic dishonesty violation' : reason);
          },
        ),
      ],
    );
  }
}
