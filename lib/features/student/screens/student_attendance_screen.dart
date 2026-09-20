import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/status_badge.dart';

class StudentAttendanceScreen extends StatelessWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studentId = MockDatabase.instance.currentUser?.studentId ?? 'A01';
    final attendance =
        MockDatabase.instance.attendanceForStudent(studentId).reversed.toList();

    final presentCount =
        attendance.where((r) => r.status == AttendanceStatus.present).length;
    final totalDays = attendance.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance Logs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // Summary Header
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Row(
                children: [
                  _buildStatItem('Present', presentCount.toString(), AppColors.success),
                  const SizedBox(width: 16),
                  _buildStatItem('Total Days', totalDays.toString(), AppColors.primary),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    'Rate',
                    '${totalDays > 0 ? (presentCount / totalDays * 100).toInt() : 0}%',
                    AppColors.info,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Logs List
            Expanded(
              child: attendance.isEmpty
                  ? const Center(child: Text('No attendance records found.'))
                  : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: attendance.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final record = attendance[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(record.date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Time In: ${record.timeIn}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Method: ${record.method}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            _buildStatusBadge(record.status),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const StatusBadge(
          text: 'PRESENT',
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
        );
      case AttendanceStatus.late:
        return const StatusBadge(
          text: 'LATE',
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
        );
      case AttendanceStatus.absent:
        return const StatusBadge(
          text: 'ABSENT',
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
        );
      case AttendanceStatus.excused:
        return const StatusBadge(
          text: 'EXCUSED',
          backgroundColor: AppColors.infoLight,
          textColor: AppColors.info,
        );
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
