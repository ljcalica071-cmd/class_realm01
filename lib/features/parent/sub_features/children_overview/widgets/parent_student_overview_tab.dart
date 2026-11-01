import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_schedule_view.dart';
import 'package:class_realm/features/parent/sub_features/communications/widgets/parent_teacher_contact_view.dart';

class ParentStudentOverviewTab extends StatelessWidget {
  final UserModel? linkedStudent;
  final UserModel? teacher;
  final List<UserModel>? allChildren;
  final Function(UserModel)? onSelectChild;
  final List<AttendanceRecord> attendance;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenGrades;

  const ParentStudentOverviewTab({
    super.key,
    required this.linkedStudent,
    this.teacher,
    this.allChildren,
    this.onSelectChild,
    this.attendance = const [],
    this.onOpenAttendance,
    this.onOpenGrades,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (linkedStudent == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No linked student found. Please contact the school administrator.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final presentCount = attendance
        .where((r) => r.status == AttendanceStatus.present)
        .length;
    final lateCount = attendance
        .where((r) => r.status == AttendanceStatus.late)
        .length;
    final absentCount = attendance
        .where((r) => r.status == AttendanceStatus.absent)
        .length;
    final excusedCount = attendance
        .where((r) => r.status == AttendanceStatus.excused)
        .length;

    final totalAccounted = presentCount + lateCount + absentCount;
    final rate = totalAccounted > 0
        ? (((presentCount + lateCount) / totalAccounted) * 100).round()
        : (excusedCount > 0 ? 100 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Linked Student Profile Banner Card ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.16 : 0.12,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  radius: 26,
                  child: Text(
                    (linkedStudent?.firstName != null &&
                            linkedStudent!.firstName!.isNotEmpty)
                        ? linkedStudent!.firstName![0].toUpperCase()
                        : 'S',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              linkedStudent!.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              linkedStudent!.parentGuardianRelationship ??
                                  'Child',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${linkedStudent!.departmentOrSection?.isNotEmpty == true ? linkedStudent!.departmentOrSection : "Enrolled"} • LRN: ${linkedStudent!.lrn ?? linkedStudent!.studentId ?? "N/A"}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3/5/10 Absence Early Warning Tier Alert (If Applicable) ──
          if (absentCount >= 3) _buildAbsenceAlert(theme, isDark, absentCount),

          // ── Attendance Snapshot (Present, Late, Absent, Rate) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attendance Snapshot',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (onOpenAttendance != null)
                TextButton.icon(
                  onPressed: onOpenAttendance,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View Logs'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard(
                theme,
                isDark,
                'Present',
                '$presentCount',
                AppTheme.catGreen,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                theme,
                isDark,
                'Late',
                '$lateCount',
                AppTheme.catOrange,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                theme,
                isDark,
                'Absent',
                '$absentCount',
                AppTheme.catRed,
              ),
              const SizedBox(width: 8),
              _buildStatCard(theme, isDark, 'Rate', '$rate%', AppTheme.catBlue),
            ],
          ),
          const SizedBox(height: 20),

          // ── Quick Access Features Grid ──
          const Text(
            'Quick Actions & Monitoring',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.catBlue,
                  title: "Class Schedule",
                  subtitle: "Weekly timetable",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ParentScheduleView(linkedStudent: linkedStudent),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionCard(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.assignment_turned_in_rounded,
                  color: AppTheme.catTeal,
                  title: "Report Card",
                  subtitle: "Subject grades",
                  onTap: onOpenGrades ?? () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.contact_phone_rounded,
                  color: AppTheme.catOrange,
                  title: "Adviser Contact",
                  subtitle: "Reach out to teacher",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ParentTeacherContactView(teacher: teacher),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionCard(
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.fact_check_rounded,
                  color: AppTheme.catGreen,
                  title: "Attendance Logs",
                  subtitle: "Detailed timestamps",
                  onTap: onOpenAttendance ?? () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    bool isDark,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.32 : 0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(
              alpha: isDark ? 0.16 : 0.12,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenceAlert(ThemeData theme, bool isDark, int absentCount) {
    final Color bannerColor;
    final Color borderColor;
    final Color textColor;
    final String title;
    final String subtitle;
    final IconData icon;

    if (absentCount >= 10) {
      bannerColor = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFDC2626);
      textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      icon = Icons.error_rounded;
      title = 'Critical Notice: $absentCount Absences (SARDO Policy)';
      subtitle = 'Urgent conference with class adviser required.';
    } else if (absentCount >= 5) {
      bannerColor = isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFEA580C);
      textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412);
      icon = Icons.warning_amber_rounded;
      title = 'Attendance Alert: $absentCount Recorded Absences';
      subtitle = 'Intervention required. Coordinate with class adviser.';
    } else {
      bannerColor = isDark ? const Color(0xFF422006) : const Color(0xFFFEFCE8);
      borderColor = const Color(0xFFCA8A04);
      textColor = isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E);
      icon = Icons.info_outline_rounded;
      title = 'Early Warning: $absentCount Recorded Absences';
      subtitle =
          'Please ensure regular attendance to maintain academic standing.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
