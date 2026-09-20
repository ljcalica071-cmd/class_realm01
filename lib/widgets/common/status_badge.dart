import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/academic_models.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.fromAccountStatus(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return const StatusBadge(
          text: 'Active',
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
          icon: Icons.check_circle_outline,
        );
      case AccountStatus.pending:
        return const StatusBadge(
          text: 'Pending Approval',
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
          icon: Icons.access_time,
        );
      case AccountStatus.rejected:
        return const StatusBadge(
          text: 'Rejected',
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
          icon: Icons.cancel_outlined,
        );
      case AccountStatus.archived:
        return const StatusBadge(
          text: 'Inactive',
          backgroundColor: Color(0xFFF1F5F9),
          textColor: AppColors.textSecondary,
          icon: Icons.archive_outlined,
        );
      case AccountStatus.pendingFirstLogin:
        return const StatusBadge(
          text: 'Pending',
          backgroundColor: Color(0xFFEDE9FE),
          textColor: Color(0xFF7C3AED),
          icon: Icons.lock_clock_outlined,
        );
      case AccountStatus.deactivated:
        return const StatusBadge(
          text: 'Deactivated',
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
          icon: Icons.block_outlined,
        );
    }
  }

  factory StatusBadge.fromAttendance(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const StatusBadge(
          text: 'Present',
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
        );
      case AttendanceStatus.late:
        return const StatusBadge(
          text: 'Late',
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
        );
      case AttendanceStatus.absent:
        return const StatusBadge(
          text: 'Absent',
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
        );
      case AttendanceStatus.excused:
        return const StatusBadge(
          text: 'Excused',
          backgroundColor: AppColors.infoLight,
          textColor: AppColors.info,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
