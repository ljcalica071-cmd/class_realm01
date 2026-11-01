import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/utils/sf2_csv_exporter.dart';

enum AttendanceDatePreset { thisWeek, thisMonth, custom }

class AttendanceHistoryAnalyticsView extends StatefulWidget {
  final String subjectOfferingId;
  final AttendanceRepository? repository;
  final Future<Sf2SaveOutcome> Function({
    required String fileName,
    required String csvContent,
  })?
  onExportCsv;

  final List<AttendanceRosterStudent>? students;
  final bool hideFilterBar;

  const AttendanceHistoryAnalyticsView({
    super.key,
    required this.subjectOfferingId,
    this.repository,
    this.onExportCsv,
    this.students,
    this.hideFilterBar = false,
  });

  @override
  State<AttendanceHistoryAnalyticsView> createState() =>
      AttendanceHistoryAnalyticsViewState();
}

class AttendanceHistoryAnalyticsViewState
    extends State<AttendanceHistoryAnalyticsView> {
  void setPreset(AttendanceDatePreset preset) {
    if (preset == _selectedPreset) return;
    setState(() => _selectedPreset = preset);
    if (preset != AttendanceDatePreset.custom) {
      _loadAll();
    } else {
      if (!_hasInvalidCustomRange) {
        _loadAll();
      }
    }
  }

  DateTime get customStartDate => _customStartDate;
  DateTime get customEndDate => _customEndDate;

  void setCustomRange(DateTime start, DateTime end) {
    setState(() {
      _customStartDate = _dateOnly(start);
      _customEndDate = _dateOnly(end);
      _selectedPreset = AttendanceDatePreset.custom;
    });
    if (!_hasInvalidCustomRange) {
      _loadAll();
    }
  }

  AttendanceDatePreset get selectedPreset => _selectedPreset;
  bool get isExportingCsv => _isExportingCsv;
  bool get hasRangeError => _hasInvalidCustomRange;
  Future<void> exportSf2Csv() => _handleExportSf2Csv();
  static const Color _validationRed = Color(0xFFDC2626);

  late final AttendanceRepository _repository;

  AttendanceDatePreset _selectedPreset = AttendanceDatePreset.thisWeek;
  late DateTime _customStartDate;
  late DateTime _customEndDate;

  bool _isLoadingAnalytics = true;
  AttendanceAnalyticsSummary? _analyticsSummary;

  bool _isLoadingHistory = true;
  List<AttendanceWorkspaceRecord> _historyRows = [];
  int _historyCurrentPage = 1;
  static const int _historyPageSize = 20;
  bool _isExportingCsv = false;

  String _getStudentDisplayName(String studentId) {
    if (widget.students != null) {
      for (final s in widget.students!) {
        if (s.studentId == studentId) {
          final ln = s.lastName.trim();
          final fn = s.firstName.trim();
          final mi = s.middleInitial != null && s.middleInitial!.isNotEmpty
              ? ' ${s.middleInitial}'
              : '';
          if (ln.isNotEmpty || fn.isNotEmpty) {
            return '$ln, $fn$mi';
          }
          return s.displayName;
        }
      }
    }
    return studentId;
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseAttendanceRepository.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min2026 = DateTime(2026, 1, 1);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    _customStartDate = sevenDaysAgo.isBefore(min2026) ? min2026 : sevenDaysAgo;
    _customEndDate = today;
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryAnalyticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectOfferingId != widget.subjectOfferingId) {
      _loadAll();
    }
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool get _hasInvalidCustomRange =>
      _selectedPreset == AttendanceDatePreset.custom &&
      _dateOnly(_customStartDate).isAfter(_dateOnly(_customEndDate));

  AttendanceDateRange _computeCurrentDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min2026 = DateTime(2026, 1, 1);
    switch (_selectedPreset) {
      case AttendanceDatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final weekStart = DateTime(monday.year, monday.month, monday.day);
        return AttendanceDateRange(
          startDate: weekStart.isBefore(min2026) ? min2026 : weekStart,
          endDate: today,
        );
      case AttendanceDatePreset.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return AttendanceDateRange(
          startDate: monthStart.isBefore(min2026) ? min2026 : monthStart,
          endDate: today,
        );
      case AttendanceDatePreset.custom:
        DateTime start = _customStartDate.isAfter(_customEndDate)
            ? _customEndDate
            : _customStartDate;
        DateTime end = _customStartDate.isAfter(_customEndDate)
            ? _customStartDate
            : _customEndDate;
        if (start.isBefore(min2026)) start = min2026;
        if (end.isAfter(today)) end = today;
        return AttendanceDateRange(
          startDate: DateTime(start.year, start.month, start.day),
          endDate: DateTime(end.year, end.month, end.day),
        );
    }
  }

  Future<void> _loadAll() async {
    if (_hasInvalidCustomRange) return;
    await Future.wait([_loadAnalytics(), _loadInitialHistory()]);
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoadingAnalytics = true;
    });

    try {
      final range = _computeCurrentDateRange();
      final summary = await _repository.getAttendanceAnalytics(
        subjectOfferingId: widget.subjectOfferingId,
        dateRange: range,
      );
      if (!mounted) return;
      setState(() {
        _analyticsSummary = summary;
        _isLoadingAnalytics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyticsSummary = const AttendanceAnalyticsSummary(
          presenceRate: null,
          absencesAndExcuses: 0,
          warningCount: 0,
          presentCount: 0,
          lateCount: 0,
          absentCount: 0,
          excusedCount: 0,
          trendPoints: [],
          atRiskStudents: [],
        );
        _isLoadingAnalytics = false;
      });
    }
  }

  Future<void> _loadInitialHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyRows = [];
    });

    try {
      final range = _computeCurrentDateRange();
      final page = await _repository.getAttendanceHistory(
        AttendanceHistoryFilter(
          subjectOfferingId: widget.subjectOfferingId,
          dateRange: range,
          offset: 0,
          pageSize: 500,
        ),
      );
      if (!mounted) return;
      setState(() {
        _historyRows = List<AttendanceWorkspaceRecord>.from(page.rows);
        _historyCurrentPage = 1;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyRows = [];
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _handleExportSf2Csv() async {
    if (_isExportingCsv || _hasInvalidCustomRange) return;

    setState(() => _isExportingCsv = true);
    try {
      final range = _computeCurrentDateRange();
      final summary =
          _analyticsSummary ??
          const AttendanceAnalyticsSummary(
            presenceRate: null,
            absencesAndExcuses: 0,
            warningCount: 0,
            presentCount: 0,
            lateCount: 0,
            absentCount: 0,
            excusedCount: 0,
            trendPoints: [],
            atRiskStudents: [],
          );

      final csvContent = Sf2CsvExporter.buildSf2SummaryCsv(
        subjectOfferingId: widget.subjectOfferingId,
        dateRange: range,
        summary: summary,
        historyRows: _historyRows,
      );

      final startStr = _formatDate(range.startDate);
      final endStr = _formatDate(range.endDate);
      final sanitizedOffering = widget.subjectOfferingId.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final fileName =
          'DepEd_SF2_${sanitizedOffering}_${startStr}_to_$endStr.csv';

      final exporter = widget.onExportCsv ?? Sf2CsvExporter.exportSf2Csv;
      final outcome = await exporter(
        fileName: fileName,
        csvContent: csvContent,
      );

      if (!mounted) return;
      setState(() => _isExportingCsv = false);

      if (outcome.cancelled) return;

      if (outcome.saved) {
        final detail = outcome.copiedToClipboard
            ? 'The DepEd SF2 attendance summary CSV has been copied to your clipboard.'
            : 'DepEd SF2 attendance summary exported as "$fileName".';
        await AppModals.showSuccessDialog(
          context: context,
          title: 'SF2 Summary Exported',
          message: detail,
        );
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _isExportingCsv = false);
      await AppModals.showErrorDialog(
        context: context,
        title: 'Export Failed',
        message: err.toString(),
      );
    }
  }

  Future<void> _showCorrectionDialog(
    BuildContext context,
    AttendanceWorkspaceRecord record,
  ) async {
    final corrected = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _AttendanceCorrectionDialog(
        record: record,
        subjectOfferingId: widget.subjectOfferingId,
        repository: _repository,
        studentName: _getStudentDisplayName(record.studentId),
      ),
    );

    if (corrected == true && mounted) {
      await _loadAll();
      if (!mounted || !context.mounted) return;
      await AppModals.showSuccessDialog(
        context: context,
        title: 'Attendance Corrected',
        message:
            'The historical attendance record for ${record.studentId} on ${_formatDate(record.attendanceDate)} has been updated with an audit reason.',
      );
    }
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary =
        _analyticsSummary ??
        const AttendanceAnalyticsSummary(
          presenceRate: null,
          absencesAndExcuses: 0,
          warningCount: 0,
          presentCount: 0,
          lateCount: 0,
          absentCount: 0,
          excusedCount: 0,
          trendPoints: [],
          atRiskStudents: [],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.hideFilterBar) ...[
          _buildDateFilterBar(theme),
          const SizedBox(height: 20),
        ],
        if (_isLoadingAnalytics)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _buildKpiCards(theme, summary),
          const SizedBox(height: 20),
          _buildAtRiskSection(theme, summary),
          const SizedBox(height: 20),
          _buildChartsSection(theme, summary),
        ],
        const SizedBox(height: 24),
        _buildHistorySection(theme),
      ],
    );
  }

  Widget _buildDateFilterBar(ThemeData theme) {
    final hasRangeError = _hasInvalidCustomRange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetButton(
                    'This week',
                    AttendanceDatePreset.thisWeek,
                  ),
                  _buildPresetButton(
                    'This month',
                    AttendanceDatePreset.thisMonth,
                  ),
                  _buildPresetButton('Custom', AttendanceDatePreset.custom),
                ],
              ),
              AppButton.outline(
                label: 'Export SF2 CSV',
                icon: Icons.download_rounded,
                isSmall: true,
                isLoading: _isExportingCsv,
                onPressed: hasRangeError ? null : _handleExportSf2Csv,
              ),
            ],
          ),
          if (_selectedPreset == AttendanceDatePreset.custom) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDatePickerField(
                      key: const ValueKey('custom_start_date_picker'),
                      label: 'Start Date',
                      date: _customStartDate,
                      hasError: hasRangeError,
                      onPicked: (d) {
                        setState(() => _customStartDate = _dateOnly(d));
                        if (!_hasInvalidCustomRange) {
                          _loadAll();
                        }
                      },
                    ),
                    _buildDatePickerField(
                      key: const ValueKey('custom_end_date_picker'),
                      label: 'End Date',
                      date: _customEndDate,
                      hasError: hasRangeError,
                      onPicked: (d) {
                        setState(() => _customEndDate = _dateOnly(d));
                        if (!_hasInvalidCustomRange) {
                          _loadAll();
                        }
                      },
                    ),
                  ],
                ),
                if (hasRangeError) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 14,
                        color: _validationRed,
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Start date cannot be after end date. Please select a valid date range.',
                          style: TextStyle(
                            color: _validationRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, AttendanceDatePreset preset) {
    final isSelected = _selectedPreset == preset;
    return isSelected
        ? AppButton.primary(label: label, isSmall: true, onPressed: () {})
        : AppButton.outline(
            label: label,
            isSmall: true,
            onPressed: () {
              setState(() => _selectedPreset = preset);
              if (!_hasInvalidCustomRange) {
                _loadAll();
              }
            },
          );
  }

  Widget _buildDatePickerField({
    Key? key,
    required String label,
    required DateTime date,
    required bool hasError,
    required ValueChanged<DateTime> onPicked,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final min2026 = DateTime(2026, 1, 1);
        final initial = date.isAfter(today)
            ? today
            : (date.isBefore(min2026) ? min2026 : date);
        final picked = await showAppDatePickerDialog(
          context,
          initialDate: initial,
          firstDate: min2026,
          lastDate: today,
          title: 'Select $label',
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasError
                ? _validationRed
                : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            width: hasError ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${_formatDate(date)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.calendar,
              size: 16,
              color: hasError ? _validationRed : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(ThemeData theme, AttendanceAnalyticsSummary summary) {
    final rateVal = summary.presenceRate?.clamp(0.0, 100.0);
    final rateStr = rateVal != null ? '${rateVal.toStringAsFixed(1)}%' : '0.0%';
    final total =
        summary.presentCount +
        summary.lateCount +
        summary.absentCount +
        summary.excusedCount;
    final earlyWarningCount = max(
      summary.warningCount,
      summary.atRiskStudents.length,
    );

    final cards = <_KpiItemData>[
      _KpiItemData(
        title: 'Presence Rate',
        value: rateStr,
        subtitle: total > 0
            ? '(Present + Late) / Accounted'
            : 'No records in period',
        icon: LucideIcons.percent,
        color: AppTheme.catBlue,
      ),
      _KpiItemData(
        title: 'Present',
        value: '${summary.presentCount}',
        subtitle: 'On-time attendance logs',
        icon: LucideIcons.checkCircle2,
        color: AppTheme.catGreen,
      ),
      _KpiItemData(
        title: 'Late',
        value: '${summary.lateCount}',
        subtitle: 'Tardy arrivals recorded',
        icon: Icons.schedule_rounded,
        color: AppTheme.catOrange,
      ),
      _KpiItemData(
        title: 'Absent',
        value: '${summary.absentCount}',
        subtitle: 'Unexcused class absences',
        icon: LucideIcons.userX,
        color: AppTheme.catRed,
      ),
      _KpiItemData(
        title: 'Excused',
        value: '${summary.excusedCount}',
        subtitle: 'Approved excused logs',
        icon: Icons.assignment_turned_in_outlined,
        color: AppTheme.catSlate,
      ),
      _KpiItemData(
        title: 'Early Warnings',
        value: '$earlyWarningCount',
        subtitle: 'Learners with ≥ 3 Absences',
        icon: LucideIcons.alertTriangle,
        color: earlyWarningCount > 0 ? AppTheme.catRed : AppTheme.catOrange,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 6
            : width >= 720
            ? 3
            : width >= 440
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _buildKpiCard(item: item, theme: theme),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({required _KpiItemData item, required ThemeData theme}) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.16 : 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(
    ThemeData theme,
    AttendanceAnalyticsSummary summary,
  ) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        final trendCard = _buildTrendChartCard(theme, summary.trendPoints);
        final breakdownCard = _buildBreakdownChartCard(theme, summary);

        if (isNarrow) {
          return Column(
            children: [trendCard, const SizedBox(height: 16), breakdownCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: trendCard),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: breakdownCard),
          ],
        );
      },
    );
  }

  Widget _buildTrendChartCard(
    ThemeData theme,
    List<AttendanceTrendPoint> points,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.trendingUp,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Attendance Trend',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.lineChart,
                      size: 28,
                      color: theme.colorScheme.primary.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No Trend Data Recorded',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trends plot automatically once daily attendance is logged.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 160,
              child: CustomPaint(
                size: const Size(double.infinity, 160),
                painter: TrendChartPainter(
                  points: points,
                  presentColor: AppTheme.catGreen,
                  absentColor: AppTheme.catRed,
                  textColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Trend Summary',
              child: Text(
                'Trend summary: ${points.length} periods recorded. Latest period had ${points.last.presentCount} present and ${points.last.absentOrExcusedCount} absent/excused.',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownChartCard(
    ThemeData theme,
    AttendanceAnalyticsSummary summary,
  ) {
    final total =
        summary.presentCount +
        summary.lateCount +
        summary.absentCount +
        summary.excusedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.pieChart,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status Breakdown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
            theme,
            'Present',
            summary.presentCount,
            total,
            AppTheme.catGreen,
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            theme,
            'Late',
            summary.lateCount,
            total,
            AppTheme.catOrange,
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            theme,
            'Absent',
            summary.absentCount,
            total,
            AppTheme.catRed,
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            theme,
            'Excused',
            summary.excusedCount,
            total,
            AppTheme.catSlate,
          ),
          if (total == 0) ...[
            const SizedBox(height: 12),
            Text(
              'No attendance status breakdown recorded for this period yet.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    ThemeData theme,
    String label,
    int count,
    int total,
    Color color,
  ) {
    final pct = total > 0 ? (count / total) * 100 : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '$count (${pct.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildAtRiskSection(
    ThemeData theme,
    AttendanceAnalyticsSummary summary,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final hasAtRisk = summary.atRiskStudents.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAtRisk
              ? AppTheme.catRed.withValues(alpha: isDark ? 0.45 : 0.28)
              : theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.alertOctagon,
                size: 18,
                color: hasAtRisk ? AppTheme.catRed : AppTheme.catOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Early Warning At-Risk Students (≥ 3 Absences)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: hasAtRisk
                      ? AppTheme.catRed.withValues(alpha: isDark ? 0.2 : 0.1)
                      : AppTheme.catGreen.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${summary.atRiskStudents.length} at risk',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasAtRisk
                        ? (isDark ? const Color(0xFFF87171) : AppTheme.catRed)
                        : (isDark
                              ? const Color(0xFF4ADE80)
                              : AppTheme.catGreen),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Academic early-warning indicator only — flags learners with 3 or more absences so teachers and advisers can intervene early.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 14),
          if (!hasAtRisk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.catGreen.withValues(
                  alpha: isDark ? 0.12 : 0.06,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.catGreen.withValues(
                    alpha: isDark ? 0.3 : 0.18,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.checkCircle2,
                    color: isDark ? const Color(0xFF4ADE80) : AppTheme.catGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Learners in Good Attendance Standing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '0 students have reached 3 or more absences during the selected reporting window.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.68,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summary.atRiskStudents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final student = summary.atRiskStudents[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.catRed.withValues(
                      alpha: isDark ? 0.12 : 0.05,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.catRed.withValues(
                        alpha: isDark ? 0.35 : 0.22,
                      ),
                    ),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.catRed.withValues(
                                alpha: isDark ? 0.25 : 0.14,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.alertTriangle,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFFF87171)
                                  : AppTheme.catRed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.studentName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Section: ${student.section} • ID: ${student.studentId}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.68,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFFBBF24)
                                        .withValues(alpha: 0.18)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFFBBF24)
                                          .withValues(alpha: 0.4)
                                    : const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '${student.absenceCount} Absences',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFFDE047)
                                    : const Color(0xFFB45309),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.catRed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '3+ Absences — Intervention Needed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Icon(
                  LucideIcons.history,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attendance Audit & History Logs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (!_isLoadingHistory)
                  Text(
                    '${_historyRows.length} records shown',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyRows.isEmpty)
            AppEmptyState(
              icon: Icons.history_edu_outlined,
              title: 'No Attendance History Yet',
              message: 'Recorded class attendance logs for the selected date range will appear here.',
              actionLabel: 'Refresh',
              onAction: _loadAll,
            )
          else ...[
            Builder(
              builder: (context) {
                final totalRecords = _historyRows.length;
                final totalPages = (totalRecords / _historyPageSize)
                    .ceil()
                    .clamp(1, 9999);
                final safePage = _historyCurrentPage.clamp(1, totalPages);
                final startIdx = (safePage - 1) * _historyPageSize;
                final endIdx = (startIdx + _historyPageSize).clamp(
                  0,
                  totalRecords,
                );
                final pageRows = _historyRows.sublist(startIdx, endIdx);

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: isDark ? 0.14 : 0.09,
                            ),
                          ),
                          bottom: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: isDark ? 0.14 : 0.09,
                            ),
                          ),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: max(840.0, constraints.maxWidth),
                              ),
                              child: DataTable(
                              headingRowHeight: 44,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 52,
                              headingRowColor: WidgetStateProperty.all(
                                theme.colorScheme.primary.withValues(
                                  alpha: isDark ? 0.12 : 0.06,
                                ),
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'DATE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'STUDENT NAME',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'TIME IN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'METHOD',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'STATUS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'REMARKS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ACTIONS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              rows: pageRows.map((row) {
                                final studentName = _getStudentDisplayName(
                                  row.studentId,
                                );
                                final timeInDisplay =
                                    (row.timeIn != null &&
                                        row.timeIn!.trim().isNotEmpty)
                                    ? row.timeIn!.trim()
                                    : '—';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        _formatDate(row.attendanceDate),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        timeInDisplay,
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                    DataCell(
                                      _buildProvenancePill(theme, row.source),
                                    ),
                                    DataCell(
                                      StatusBadge.fromAttendance(row.status),
                                    ),
                                    DataCell(
                                      Text(
                                        row.remarks != null &&
                                                row.remarks!.trim().isNotEmpty
                                            ? row.remarks!.trim()
                                            : '—',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: row.remarks != null
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      AppButton.outline(
                                        label: 'Correct',
                                        icon: LucideIcons.fileEdit,
                                        isSmall: true,
                                        onPressed: () =>
                                            _showCorrectionDialog(context, row),
                                      ),
                                    ),
                                  ],
                                  );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                      ),
                    ),
                    // Pagination Footer (20 per page, matching student management)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${totalRecords == 0 ? 0 : startIdx + 1} to $endIdx of $totalRecords entries',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.chevronLeft,
                                  size: 18,
                                ),
                                onPressed: safePage > 1
                                    ? () => setState(
                                        () => _historyCurrentPage = safePage - 1,
                                      )
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Page $safePage of $totalPages',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.chevronRight,
                                  size: 18,
                                ),
                                onPressed: safePage < totalPages
                                    ? () => setState(
                                        () => _historyCurrentPage = safePage + 1,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
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
}

class _KpiItemData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiItemData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _AttendanceCorrectionDialog extends StatefulWidget {
  final AttendanceWorkspaceRecord record;
  final String subjectOfferingId;
  final AttendanceRepository repository;
  final String studentName;

  const _AttendanceCorrectionDialog({
    required this.record,
    required this.subjectOfferingId,
    required this.repository,
    required this.studentName,
  });

  @override
  State<_AttendanceCorrectionDialog> createState() =>
      _AttendanceCorrectionDialogState();
}

class _AttendanceCorrectionDialogState
    extends State<_AttendanceCorrectionDialog> {
  static const Color _validationRed = Color(0xFFDC2626);

  late AttendanceStatus _selectedStatus;
  final TextEditingController _reasonController = TextEditingController();
  String? _reasonError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.record.status;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _handleSaveCorrection() async {
    final trimmedReason = _reasonController.text.trim();
    if (trimmedReason.isEmpty) {
      setState(() {
        _reasonError =
            'Please provide a reason for this attendance correction.';
      });
      return;
    }

    setState(() {
      _reasonError = null;
      _isSubmitting = true;
    });

    try {
      await widget.repository.correctAttendanceRecord(
        subjectOfferingId: widget.subjectOfferingId,
        recordId: widget.record.id ?? '',
        newStatus: _selectedStatus,
        reason: trimmedReason,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await AppModals.showErrorDialog(
        context: context,
        title: 'Correction Failed',
        message: err.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasError = _reasonError != null;
    final timeInDisplay =
        (widget.record.timeIn != null &&
            widget.record.timeIn!.trim().isNotEmpty)
        ? widget.record.timeIn!.trim()
        : '—';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.fileEdit,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Correct Attendance Record',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.06 : 0.04,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student: ${widget.studentName.isNotEmpty ? widget.studentName : widget.record.studentId}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${_formatDate(widget.record.attendanceDate)} • Time In: $timeInDisplay • Source: ${widget.record.source.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Recorded Status: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        StatusBadge.fromAttendance(widget.record.status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Updated Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AttendanceStatus.values.map((status) {
                  final isSelected = _selectedStatus == status;
                  return ChoiceChip(
                    label: Text(
                      status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    onSelected: _isSubmitting
                        ? null
                        : (val) {
                            if (val) {
                              setState(() => _selectedStatus = status);
                            }
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Audit Reason for Correction *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('correction_reason_input'),
                controller: _reasonController,
                enabled: !_isSubmitting,
                maxLines: 3,
                onChanged: (_) {
                  if (_reasonError != null) {
                    setState(() => _reasonError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'e.g., Validated medical certificate submitted to adviser',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError
                          ? _validationRed
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: hasError ? 1.5 : 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError
                          ? _validationRed
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: hasError ? 1.5 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError
                          ? _validationRed
                          : theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _validationRed,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _validationRed,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.error_outline,
                        size: 14,
                        color: _validationRed,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _reasonError!,
                        style: const TextStyle(
                          color: _validationRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Cancel',
                      height: 42,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Save Correction',
                      height: 42,
                      isLoading: _isSubmitting,
                      onPressed: _handleSaveCorrection,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrendChartPainter extends CustomPainter {
  final List<AttendanceTrendPoint> points;
  final Color presentColor;
  final Color absentColor;
  final Color textColor;

  TrendChartPainter({
    required this.points,
    required this.presentColor,
    required this.absentColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.fold<int>(
      1,
      (prev, elem) =>
          max(prev, max(elem.presentCount, elem.absentOrExcusedCount)),
    );

    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = size.height - (size.height * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final presentPaint = Paint()
      ..color = presentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final absentPaint = Paint()
      ..color = absentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPresentPaint = Paint()
      ..color = presentColor
      ..style = PaintingStyle.fill;

    final dotAbsentPaint = Paint()
      ..color = absentColor
      ..style = PaintingStyle.fill;

    final n = points.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width / 2;

    final presentPath = Path();
    final absentPath = Path();

    for (int i = 0; i < n; i++) {
      final x = n > 1 ? i * stepX : size.width / 2;
      final yPres =
          size.height -
          (points[i].presentCount / maxVal * (size.height - 20)) -
          10;
      final yAbs =
          size.height -
          (points[i].absentOrExcusedCount / maxVal * (size.height - 20)) -
          10;

      if (i == 0) {
        presentPath.moveTo(x, yPres);
        absentPath.moveTo(x, yAbs);
      } else {
        presentPath.lineTo(x, yPres);
        absentPath.lineTo(x, yAbs);
      }

      canvas.drawCircle(Offset(x, yPres), 3.5, dotPresentPaint);
      canvas.drawCircle(Offset(x, yAbs), 3.5, dotAbsentPaint);
    }

    canvas.drawPath(presentPath, presentPaint);
    canvas.drawPath(absentPath, absentPaint);
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.textColor != textColor;
  }
}
