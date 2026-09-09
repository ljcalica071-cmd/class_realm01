import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/app_buttons.dart';

class PendingAccountScreen extends StatelessWidget {
  const PendingAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.warningLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, size: 48, color: AppColors.warning),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Account Pending Approval',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your teacher registration has been submitted successfully. An administrator is currently reviewing your credentials and institutional affiliation. You will be able to access your teaching dashboard once approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                AppPrimaryButton(
                  label: 'Back to Sign In',
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
