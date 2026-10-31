import 'dart:math';

import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final AttendanceRepository? repository;

  const StudentAttendanceScreen({super.key, this.repository});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  static const Color _errorRed = Color(0xFFDC2626);

  late final AttendanceRepository _repo;

  bool _isLoading = true;
  String? _errorMessage;

  AttendanceStudentSummary? _summary;
  final List<AttendanceRecord> _records = [];
  int _offset = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SupabaseAttendanceRepository.instance;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadMoreError = null;
    });

    try {
      final results = await Future.wait([
        _repo.getMyAttendanceSummary(),
        _repo.getMyAttendancePage(offset: 0, pageSize: 20),
      ]);

      final summary = results[0] as AttendanceStudentSummary;
      final page = results[1] as AttendancePage<AttendanceRecord>;

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _records
          ..clear()
          ..addAll(page.rows);
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppModals.sanitizeErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await _repo.getMyAttendancePage(
        offset: _offset,
        pageSize: 20,
      );

      if (!mounted) return;
      setState(() {
        _records.addAll(page.rows);
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError =
            'Unable to load more attendance records. Please retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance Logs'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: theme.colorScheme.primary,
          size: 40,
        ),
      );
    }

    if (_errorMessage != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Unable to Load Attendance',
        message: _errorMessage!,
        actionLabel: 'Retry',
        onAction: _loadInitialData,
      );
    }

    final countedLate = _records
        .where((r) => r.status == AttendanceStatus.late)
        .length;
    final countedAbsent = _records
        .where((r) => r.status == AttendanceStatus.absent)
        .length;

    final presentCount = _summary?.presentCount ?? 0;
    final lateCount = max(_summary?.lateCount ?? 0, countedLate);
    final absentCount = max(_summary?.absentCount ?? 0, countedAbsent);
    final rawRate = _summary?.presenceRate ?? 0.0;
    final normalizedRate =
        (rawRate > 0.0 && rawRate <= 1.0 && (presentCount + lateCount) > 1)
        ? rawRate * 100.0
        : rawRate;
    final ratePercent = normalizedRate.clamp(0.0, 100.0).round();
    final showEarlyWarning = absentCount >= 3;

    return Column(
      children: [
        // 4 Summary Stat Cards (Present, Late, Absent, Rate %)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          color: theme.colorScheme.surface,
          child: Column(
            children: [
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
                    '$ratePercent%',
                    AppTheme.catBlue,
                  ),
                ],
              ),
              if (showEarlyWarning)
                _buildAbsenceTierAlert(theme, isDark, absentCount),
            ],
          ),
        ),
        const Divider(height: 1),

        // Read-Only Attendance Logs List with Pagination
        Expanded(
          child: _records.isEmpty
              ? const AppEmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No Attendance Records Yet',
                  message: 'Your class attendance logs will appear here once recorded.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      _records.length +
                      ((_hasMore || _loadMoreError != null) ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    if (i == _records.length) {
                      return _buildPaginationFooter(theme);
                    }

                    final record = _records[i];
                    final source = _resolveProvenance(record);
                    final classLabel = _resolveClassLabel(record);
                    final timeInDisplay = record.timeIn.trim().isEmpty
                        ? '—'
                        : record.timeIn.trim();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: isDark ? 0.16 : 0.12,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                      _formatDate(record.date),
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
                                if (record.remarks != null &&
                                    record.remarks!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    record.remarks!.trim(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          StatusBadge.fromAttendance(record.status),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (_loadMoreError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _errorRed.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: _errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadMoreError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _errorRed,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadMoreRecords,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
          if (_hasMore)
            Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : AppSecondaryButton(
                      label: 'Load More Records',
                      icon: Icons.arrow_downward_rounded,
                      height: 40,
                      onPressed: _loadMoreRecords,
                    ),
            ),
        ],
      ),
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

  Widget _buildAbsenceTierAlert(ThemeData theme, bool isDark, int absentCount) {
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
      subtitle = 'You have reached 10 absences, placing you at critical risk of drop-out status under DepEd policy. Please schedule an urgent conference with your adviser.';
    } else if (absentCount >= 5) {
      bannerColor = isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFEA580C);
      textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412);
      icon = Icons.warning_amber_rounded;
      title = 'Attendance Alert: $absentCount Recorded Absences';
      subtitle = 'Attendance intervention required. Please coordinate with your subject teacher or class adviser to submit excuse letters or make-up work.';
    } else {
      bannerColor = isDark ? const Color(0xFF422006) : const Color(0xFFFEFCE8);
      borderColor = const Color(0xFFCA8A04);
      textColor = isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E);
      icon = Icons.info_outline_rounded;
      title = 'Early Warning: $absentCount Recorded Absences';
      subtitle = 'You have accumulated 3 absences. Please coordinate with your subject teacher regarding missed sessions.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
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
