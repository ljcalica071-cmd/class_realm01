import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/status_badge.dart';

class StudentAttendanceScreen extends StatelessWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentId = MockDatabase.instance.currentUser?.studentId ?? 'A01';
    final attendance =
        MockDatabase.instance.attendanceForStudent(studentId).reversed.toList();

    final presentCount =
        attendance.where((r) => r.status == AttendanceStatus.present).length;
    final totalDays = attendance.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance Logs'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // Summary Header
            Container(
              padding: const EdgeInsets.all(24),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  _buildStatItem(theme, 'Present', presentCount.toString(), AppTheme.catGreen),
                  const SizedBox(width: 16),
                  _buildStatItem(theme, 'Total Days', totalDays.toString(), theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    theme,
                    'Rate',
                    '${totalDays > 0 ? (presentCount / totalDays * 100).toInt() : 0}%',
                    AppTheme.catBlue,
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
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final record = attendance[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(record.date),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Time In: ${record.timeIn}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Method: ${record.method}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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

  Widget _buildStatItem(ThemeData theme, String label, String value, Color color) {
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
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return StatusBadge(
          text: 'PRESENT',
          backgroundColor: AppTheme.catGreen.withValues(alpha: 0.1),
          textColor: AppTheme.catGreen,
        );
      case AttendanceStatus.late:
        return StatusBadge(
          text: 'LATE',
          backgroundColor: AppTheme.catOrange.withValues(alpha: 0.1),
          textColor: AppTheme.catOrange,
        );
      case AttendanceStatus.absent:
        return StatusBadge(
          text: 'ABSENT',
          backgroundColor: AppTheme.catRed.withValues(alpha: 0.1),
          textColor: AppTheme.catRed,
        );
      case AttendanceStatus.excused:
        return StatusBadge(
          text: 'EXCUSED',
          backgroundColor: AppTheme.catBlue.withValues(alpha: 0.1),
          textColor: AppTheme.catBlue,
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
