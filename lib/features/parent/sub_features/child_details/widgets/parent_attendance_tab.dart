import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class ParentAttendanceTab extends StatelessWidget {
  final List<AttendanceRecord> attendance;
  final Future<void> Function()? onRefresh;

  const ParentAttendanceTab({
    super.key,
    required this.attendance,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final presentCount =
        attendance.where((r) => r.status == AttendanceStatus.present).length;
    final lateCount =
        attendance.where((r) => r.status == AttendanceStatus.late).length;
    final absentCount =
        attendance.where((r) => r.status == AttendanceStatus.absent).length;
    final excusedCount =
        attendance.where((r) => r.status == AttendanceStatus.excused).length;

    final totalAccounted = presentCount + lateCount + absentCount;
    final rate = totalAccounted > 0
        ? (((presentCount + lateCount) / totalAccounted) * 100).round()
        : (excusedCount > 0 ? 100 : 0);

    return Column(
      children: [
        // Summary Header Cards & Early Warning Alert
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (absentCount >= 3)
                _buildParentAbsenceTierAlert(theme, isDark, absentCount),
              Row(
                children: [
                  _buildStatCard(
                    theme,
                    'Present',
                    '$presentCount',
                    AppTheme.catGreen,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    theme,
                    'Late',
                    '$lateCount',
                    AppTheme.catOrange,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    theme,
                    'Absent',
                    '$absentCount',
                    AppTheme.catRed,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    theme,
                    'Rate',
                    '$rate%',
                    AppTheme.catBlue,
                  ),
                ],
              ),
              if (excusedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Approved Excused Logs: $excusedCount',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // Strictly View-Only Attendance Logs List
        Expanded(
          child: AppPullToRefresh(
            onRefresh: onRefresh,
            child: attendance.isEmpty
                ? AppPullToRefresh.scrollableState(
                    padding: EdgeInsets.zero,
                    child: const AppEmptyState(
                      icon: Icons.family_restroom_outlined,
                      title: 'No Attendance Logs Yet',
                      message:
                          'Your child\'s daily subject attendance records will appear here.',
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                  itemCount: attendance.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final att = attendance[i];
                    final source = _resolveProvenance(att);
                    final classLabel = _resolveClassLabel(att);
                    final timeInDisplay = att.timeIn.trim().isEmpty
                        ? '—'
                        : att.timeIn.trim();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: isDark ? 0.16 : 0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  classLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      _formatDate(att.date),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.72),
                                      ),
                                    ),
                                    Text(
                                      'Time In: $timeInDisplay',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.68),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildProvenancePill(theme, source),
                                if (att.remarks != null &&
                                    att.remarks!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    att.remarks!.trim(),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          StatusBadge.fromAttendance(att.status),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    final isDark = theme.brightness == Brightness.dark;
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildProvenancePill(ThemeData theme, AttendanceSource source) {
    final isDark = theme.brightness == Brightness.dark;
    late final Color bg;
    late final Color fg;
    late final Color border;
    late final IconData icon;

    switch (source) {
      case AttendanceSource.rfid:
        bg = AppTheme.catTeal.withValues(alpha: isDark ? 0.18 : 0.11);
        fg = isDark ? const Color(0xFF2DD4BF) : AppTheme.catTeal;
        border = AppTheme.catTeal.withValues(alpha: isDark ? 0.4 : 0.28);
        icon = Icons.sensors_rounded;
        break;
      case AttendanceSource.manual:
        bg = AppTheme.catSlate.withValues(alpha: isDark ? 0.22 : 0.1);
        fg = isDark ? const Color(0xFFCBD5E1) : AppTheme.catSlate;
        border = AppTheme.catSlate.withValues(alpha: isDark ? 0.4 : 0.25);
        icon = Icons.edit_note_rounded;
        break;
      case AttendanceSource.system:
        bg = isDark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.16)
            : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        border = isDark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.36)
            : const Color(0xFFF59E0B).withValues(alpha: 0.35);
        icon = Icons.auto_mode_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            source.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  static bool _isMethodKeyword(String value) {
    final v = value.trim().toLowerCase();
    return v.isEmpty ||
        v == 'manual' ||
        v == 'rfid' ||
        v == 'rfid scan' ||
        v == 'rfid (esp32)' ||
        v == 'system' ||
        v == 'auto' ||
        v == 'auto (system)';
  }

  static AttendanceSource _resolveProvenance(AttendanceRecord record) {
    final m = record.method.trim().toLowerCase();
    if (m.contains('rfid') || m.contains('esp32') || m.contains('scan')) {
      return AttendanceSource.rfid;
    }
    if (m.contains('system') || m.contains('auto')) {
      return AttendanceSource.system;
    }
    if (m == 'manual') {
      return AttendanceSource.manual;
    }
    final rem = (record.remarks ?? '').trim().toLowerCase();
    if (rem.contains('rfid') || rem.contains('esp32')) {
      return AttendanceSource.rfid;
    }
    if (rem.contains('system') || rem.contains('auto')) {
      return AttendanceSource.system;
    }
    try {
      return AttendanceSource.parse(record.method);
    } on FormatException {
      return AttendanceSource.manual;
    }
  }

  static String _resolveClassLabel(AttendanceRecord record) {
    final sec = record.section.trim();
    final meth = record.method.trim();
    final sName = record.studentName.trim();

    if (!_isMethodKeyword(meth) &&
        sec.isNotEmpty &&
        meth.toLowerCase() != sec.toLowerCase()) {
      return '$meth • $sec';
    }
    if (!_isMethodKeyword(meth)) return meth;
    if (sec.isNotEmpty) return sec;
    if (sName.isNotEmpty) return sName;
    return 'Class Attendance';
  }

  String _formatDate(DateTime date) {
    const months = [
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

  Widget _buildParentAbsenceTierAlert(ThemeData theme, bool isDark, int absentCount) {
    if (absentCount < 3) return const SizedBox.shrink();

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
      title = 'Critical Notice: $absentCount Recorded Absences (SARDO Risk)';
      subtitle =
          'Your child has accumulated 10 absences and is at imminent risk of dropping out (DepEd SARDO policy). Please attend an urgent conference with the class adviser.';
    } else if (absentCount >= 5) {
      bannerColor = isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFEA580C);
      textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412);
      icon = Icons.warning_amber_rounded;
      title = 'Attendance Alert: $absentCount Recorded Absences';
      subtitle =
          'Attendance intervention required. Please coordinate with your child\'s subject teacher or class adviser regarding missed school days.';
    } else {
      bannerColor = isDark ? const Color(0xFF422006) : const Color(0xFFFEFCE8);
      borderColor = const Color(0xFFCA8A04);
      textColor = isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E);
      icon = Icons.info_outline_rounded;
      title = 'Early Warning: $absentCount Recorded Absences';
      subtitle =
          'Your child has 3 recorded absences. Please ensure regular attendance to maintain academic standing.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(10),
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
