import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'app_buttons.dart';

class AppModals {
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          AppPrimaryButton(
            label: 'OK',
            backgroundColor: AppColors.error,
            onPressed: () => Navigator.of(ctx).pop(),
            width: 100,
            height: 40,
          ),
        ],
      ),
    );
  }

  static Future<void> showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          AppPrimaryButton(
            label: 'Continue',
            backgroundColor: AppColors.success,
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onConfirm != null) onConfirm();
            },
            width: 120,
            height: 40,
          ),
        ],
      ),
    );
  }

  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color confirmColor = AppColors.primary,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          AppPrimaryButton(
            label: confirmLabel,
            backgroundColor: confirmColor,
            onPressed: () => Navigator.of(ctx).pop(true),
            width: 110,
            height: 40,
          ),
        ],
      ),
    );
  }
}
