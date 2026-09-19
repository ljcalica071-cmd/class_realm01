import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../widgets/common/status_badge.dart';

class ViewStudentDialog extends StatelessWidget {
  final UserModel student;

  const ViewStudentDialog({super.key, required this.student});

  static Future<void> show(BuildContext context, {required UserModel student}) {
    return showDialog(
      context: context,
      builder: (_) => ViewStudentDialog(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = student;
    final birthdayText = s.birthday == null
        ? 'N/A'
        : '${s.birthday!.month.toString().padLeft(2, '0')}/${s.birthday!.day.toString().padLeft(2, '0')}/${s.birthday!.year}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(28),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    s.fullName.isNotEmpty ? s.fullName[0] : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      StatusBadge.fromAccountStatus(s.status),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.badge_outlined, label: 'LRN', value: s.lrn ?? s.studentId ?? 'N/A'),
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: s.email),
            _InfoRow(icon: Icons.school_outlined, label: 'Grade Level', value: s.gradeLevel ?? 'N/A'),
            _InfoRow(icon: Icons.groups_outlined, label: 'Section', value: s.departmentOrSection ?? 'N/A'),
            _InfoRow(icon: Icons.cake_outlined, label: 'Birthday', value: birthdayText),
            _InfoRow(icon: Icons.person_outlined, label: 'Username', value: s.username),
            if (s.parentGuardianName != null && s.parentGuardianName!.isNotEmpty)
              _InfoRow(icon: Icons.family_restroom_outlined, label: 'Guardian', value: s.parentGuardianName!),
            if (s.parentGuardianContact != null && s.parentGuardianContact!.isNotEmpty)
              _InfoRow(icon: Icons.phone_outlined, label: 'Guardian Contact', value: s.parentGuardianContact!),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
