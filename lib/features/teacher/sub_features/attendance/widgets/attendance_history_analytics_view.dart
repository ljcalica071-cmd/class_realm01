import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
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
    extends State<AttendanceHistoryAnalyticsView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chartAnimController;
  late final Animation<double> _chartAnim;

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
  int? _hoveredBreakdownIndex;

  bool _isLoadingHistory = true;
  List<AttendanceWorkspaceRecord> _historyRows = [];
  int _historyCurrentPage = 1;
  static const int _historyPageSize = 20;
  int _atRiskCurrentPage = 1;
  static const int _atRiskPageSize = 10;
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
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartAnim = CurvedAnimation(
      parent: _chartAnimController,
      curve: Curves.easeOutCubic,
    );
    _repository = widget.repository ?? SupabaseAttendanceRepository.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min2026 = DateTime(2026, 1, 1);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    _customStartDate = sevenDaysAgo.isBefore(min2026) ? min2026 : sevenDaysAgo;
    _customEndDate = today;

    // Instant SWR Hydration: Render Frame 1 immediately if cache is available
    final initialRange = _computeCurrentDateRange();
    final startStr = _formatDate(initialRange.startDate);
    final endStr = _formatDate(initialRange.endDate);
    final analyticsKey =
        'attendance_analytics_${widget.subjectOfferingId}_${startStr}_$endStr';
    final historyKey =
        'attendance_history_${widget.subjectOfferingId}_${startStr}_${endStr}_0_500';

    final cachedSummary =
        AppDataCache.instance.get<AttendanceAnalyticsSummary>(analyticsKey);
    if (cachedSummary != null) {
      _analyticsSummary = cachedSummary;
      _isLoadingAnalytics = false;
      _chartAnimController.value = 1.0;
    }

    final cachedHistory =
        AppDataCache.instance.get<AttendancePage<AttendanceWorkspaceRecord>>(
      historyKey,
    );
    if (cachedHistory != null) {
      _historyRows = List<AttendanceWorkspaceRecord>.from(cachedHistory.rows);
      _isLoadingHistory = false;
    }

    _loadAll();
  }

  @override
  void dispose() {
    _chartAnimController.dispose();
    super.dispose();
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
    if (widget.subjectOfferingId == 'none' ||
        widget.subjectOfferingId.isEmpty) {
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
      return;
    }

    final range = _computeCurrentDateRange();
    final startStr = _formatDate(range.startDate);
    final endStr = _formatDate(range.endDate);
    final cacheKey =
        'attendance_analytics_${widget.subjectOfferingId}_${startStr}_$endStr';

    final cachedSummary =
        AppDataCache.instance.get<AttendanceAnalyticsSummary>(cacheKey);
    if (cachedSummary != null) {
      _analyticsSummary = cachedSummary;
      _isLoadingAnalytics = false;
      if (AppDataCache.instance.isFresh(cacheKey)) {
        if (mounted) setState(() {});
        _chartAnimController.forward(from: 0.0);
        return;
      }
    } else if (_analyticsSummary == null) {
      setState(() {
        _isLoadingAnalytics = true;
      });
    }

    try {
      final summary = await _repository.getAttendanceAnalytics(
        subjectOfferingId: widget.subjectOfferingId,
        dateRange: range,
      );
      if (!mounted) return;
      setState(() {
        _analyticsSummary = summary;
        _isLoadingAnalytics = false;
      });
      _chartAnimController.forward(from: 0.0);
    } catch (_) {
      if (!mounted) return;
      if (_analyticsSummary == null) {
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
  }

  Future<void> _loadInitialHistory() async {
    if (widget.subjectOfferingId == 'none' ||
        widget.subjectOfferingId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _historyRows = [];
        _historyCurrentPage = 1;
        _isLoadingHistory = false;
      });
      return;
    }

    final range = _computeCurrentDateRange();
    final startStr = _formatDate(range.startDate);
    final endStr = _formatDate(range.endDate);
    final historyKey =
        'attendance_history_${widget.subjectOfferingId}_${startStr}_${endStr}_0_500';

    final cachedHistory =
        AppDataCache.instance.get<AttendancePage<AttendanceWorkspaceRecord>>(
      historyKey,
    );
    if (cachedHistory != null) {
      _historyRows = List<AttendanceWorkspaceRecord>.from(cachedHistory.rows);
      _isLoadingHistory = false;
      if (AppDataCache.instance.isFresh(historyKey)) {
        if (mounted) setState(() {});
        return;
      }
    } else if (_historyRows.isEmpty) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
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
      if (_historyRows.isEmpty) {
        setState(() {
          _historyRows = [];
          _isLoadingHistory = false;
        });
      }
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
          const ShimmerAttendanceAnalyticsSkeleton()
        else ...[
          _buildKpiCards(theme, summary),
          const SizedBox(height: 20),
          _buildChartsSection(theme, summary),
          const SizedBox(height: 20),
          _buildAtRiskSection(theme, summary),
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
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: item.color.withValues(alpha: isDark ? 0.35 : 0.25),
                  ),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
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

  Widget _buildAttendanceCategoryPill(
    String label,
    Color color,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartCard(
    ThemeData theme,
    List<AttendanceTrendPoint> points,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    const cPresent = Color(0xFF10B981);
    const cAbsent = Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cPresent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.trendingUp,
                      size: 16,
                      color: cPresent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Attendance Trajectory & Trends',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '${points.length} Sessions Logged',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Historical class presence vs absences across recording periods.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),

          // Category Legend Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildAttendanceCategoryPill('Present (On-Time)', cPresent, isDark, theme),
              _buildAttendanceCategoryPill('Absent / Excused', cAbsent, isDark, theme),
            ],
          ),
          const SizedBox(height: 16),

          if (points.isEmpty)
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
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
                      size: 32,
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
            AnimatedBuilder(
              animation: _chartAnim,
              builder: (context, _) {
                return SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: CustomPaint(
                    size: const Size(double.infinity, 190),
                    painter: TrendChartPainter(
                      points: points,
                      presentColor: cPresent,
                      absentColor: cAbsent,
                      textColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      progress: _chartAnim.value,
                      isDark: isDark,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.sparkles, size: 14, color: cPresent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      label: 'Trend Summary',
                      child: Text(
                        'Trend summary: ${points.length} periods recorded. Latest period had ${points.last.presentCount} present and ${points.last.absentOrExcusedCount} absent/excused.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                ],
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
    final isDark = theme.brightness == Brightness.dark;
    final total =
        summary.presentCount +
        summary.lateCount +
        summary.absentCount +
        summary.excusedCount;

    final rateVal = summary.presenceRate?.clamp(0.0, 100.0);
    final rateStr = rateVal != null ? '${rateVal.toStringAsFixed(1)}%' : '0.0%';

    final pPres = total > 0 ? (summary.presentCount / total) * 100 : 0.0;
    final pLate = total > 0 ? (summary.lateCount / total) * 100 : 0.0;
    final pAbs = total > 0 ? (summary.absentCount / total) * 100 : 0.0;
    final pExc = total > 0 ? (summary.excusedCount / total) * 100 : 0.0;

    const cPresent = Color(0xFF10B981);
    const cLate = Color(0xFFF59E0B);
    const cAbsent = Color(0xFFEF4444);
    const cExcused = Color(0xFF6366F1);

    final slices = <_AttendanceDonutSlice>[
      _AttendanceDonutSlice(
        label: 'Present (${summary.presentCount})',
        sub: 'Present',
        count: summary.presentCount,
        pct: pPres,
        color: cPresent,
        dotLabel: 'Present: ${summary.presentCount} (${pPres.toStringAsFixed(1)}%)',
      ),
      _AttendanceDonutSlice(
        label: 'Late (${summary.lateCount})',
        sub: 'Late',
        count: summary.lateCount,
        pct: pLate,
        color: cLate,
        dotLabel: 'Late: ${summary.lateCount} (${pLate.toStringAsFixed(1)}%)',
      ),
      _AttendanceDonutSlice(
        label: 'Absent (${summary.absentCount})',
        sub: 'Absent',
        count: summary.absentCount,
        pct: pAbs,
        color: cAbsent,
        dotLabel: 'Absent: ${summary.absentCount} (${pAbs.toStringAsFixed(1)}%)',
      ),
      _AttendanceDonutSlice(
        label: 'Excused (${summary.excusedCount})',
        sub: 'Excused',
        count: summary.excusedCount,
        pct: pExc,
        color: cExcused,
        dotLabel: 'Excused: ${summary.excusedCount} (${pExc.toStringAsFixed(1)}%)',
      ),
    ];

    final statusItems = [
      (
        title: 'Present',
        subtitle: 'On-Time',
        count: summary.presentCount,
        pct: pPres,
        color: cPresent,
        icon: LucideIcons.checkCircle2,
      ),
      (
        title: 'Late',
        subtitle: 'Tardy',
        count: summary.lateCount,
        pct: pLate,
        color: cLate,
        icon: LucideIcons.clock,
      ),
      (
        title: 'Absent',
        subtitle: 'Unexcused',
        count: summary.absentCount,
        pct: pAbs,
        color: cAbsent,
        icon: LucideIcons.xCircle,
      ),
      (
        title: 'Excused',
        subtitle: 'Approved',
        count: summary.excusedCount,
        pct: pExc,
        color: cExcused,
        icon: LucideIcons.shieldCheck,
      ),
    ];

    final donutWidget = SizedBox(
      width: 180,
      height: 180,
      child: MouseRegion(
        onHover: (event) {
          const center = Offset(90, 90);
          final dx = event.localPosition.dx - center.dx;
          final dy = event.localPosition.dy - center.dy;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist >= 35 && dist <= 95) {
            var angle = atan2(dy, dx) - (-pi / 2);
            if (angle < 0) angle += 2 * pi;
            var cur = 0.0;
            int? match;
            for (int i = 0; i < slices.length; i++) {
              if (slices[i].pct <= 0) continue;
              final sweep = (slices[i].pct / 100) * 2 * pi;
              if (angle >= cur && angle < cur + sweep) {
                match = i;
                break;
              }
              cur += sweep;
            }
            if (_hoveredBreakdownIndex != match) {
              setState(() => _hoveredBreakdownIndex = match);
            }
          } else {
            if (_hoveredBreakdownIndex != null) {
              setState(() => _hoveredBreakdownIndex = null);
            }
          }
        },
        onExit: (_) {
          if (_hoveredBreakdownIndex != null) {
            setState(() => _hoveredBreakdownIndex = null);
          }
        },
        child: AnimatedBuilder(
          animation: _chartAnim,
          builder: (context, _) {
            final hovered = _hoveredBreakdownIndex != null &&
                    _hoveredBreakdownIndex! < slices.length
                ? slices[_hoveredBreakdownIndex!]
                : null;

            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(170, 170),
                  painter: _AttendanceDonutChartPainter(
                    slices: slices,
                    progress: _chartAnim.value,
                    strokeWidth: 22,
                    isDark: isDark,
                    hoveredIndex: _hoveredBreakdownIndex,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hovered != null) ...[
                      Text(
                        hovered.sub,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: hovered.color,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        '${hovered.pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${hovered.count} ${hovered.count == 1 ? 'log' : 'logs'}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: hovered.color,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Total Logs',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        total > 0 ? '$rateStr Pres.' : 'No Records',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: total > 0
                              ? cPresent
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );

    final statusListWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(statusItems.length, (i) {
        final item = statusItems[i];
        final isHovered = _hoveredBreakdownIndex == i;
        return Padding(
          padding: EdgeInsets.only(bottom: i < statusItems.length - 1 ? 4 : 0),
          child: _buildAttendanceStatusRow(
            title: item.title,
            subtitle: item.subtitle,
            count: item.count,
            pct: item.pct,
            color: item.color,
            icon: item.icon,
            isDark: isDark,
            theme: theme,
            isHovered: isHovered,
            onEnter: () => setState(() => _hoveredBreakdownIndex = i),
            onExit: () => setState(() => _hoveredBreakdownIndex = null),
          ),
        );
      }),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.pieChart,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$total Total Logs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Proportion of verified attendance logs for this period.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 440) {
                return Column(
                  children: [
                    Center(child: donutWidget),
                    const SizedBox(height: 14),
                    statusListWidget,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  donutWidget,
                  const SizedBox(width: 16),
                  Expanded(child: statusListWidget),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatusRow({
    required String title,
    required String subtitle,
    required int count,
    required double pct,
    required Color color,
    required IconData icon,
    required bool isDark,
    required ThemeData theme,
    required bool isHovered,
    required VoidCallback onEnter,
    required VoidCallback onExit,
  }) {
    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isHovered
              ? color.withValues(alpha: isDark ? 0.16 : 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHovered
                ? color.withValues(alpha: isDark ? 0.6 : 0.45)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
            width: isHovered ? 1.5 : 1.0,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$count ${count == 1 ? 'log' : 'logs'}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: color.withValues(
                                  alpha: isDark ? 0.4 : 0.25,
                                ),
                              ),
                            ),
                            child: Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      minHeight: 3.5,
                      backgroundColor: isDark
                          ? Colors.white10
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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
          else ...[
            Builder(
              builder: (context) {
                final totalAtRisk = summary.atRiskStudents.length;
                final totalPages = (totalAtRisk / _atRiskPageSize).ceil().clamp(1, 99999);
                final safePage = _atRiskCurrentPage.clamp(1, totalPages);
                final startIdx = (safePage - 1) * _atRiskPageSize;
                final endIdx = (startIdx + _atRiskPageSize).clamp(0, totalAtRisk);
                final pagedStudents = summary.atRiskStudents.sublist(startIdx, endIdx);

                return Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pagedStudents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final student = pagedStudents[i];
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
                    if (totalAtRisk > _atRiskPageSize) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${totalAtRisk == 0 ? 0 : startIdx + 1} to $endIdx of $totalAtRisk at-risk learners',
                              style: TextStyle(
                                fontSize: 12,
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
                                          () => _atRiskCurrentPage = safePage - 1,
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
                                          () => _atRiskCurrentPage = safePage + 1,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
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
                  )
                else
                  const ShimmerLoading(
                    child: ShimmerBox(width: 80, height: 12, borderRadius: 4),
                  ),
              ],
            ),
          ),
          if (_isLoadingHistory)
            const ShimmerAttendanceHistorySkeleton()
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
                                rows: pageRows.isEmpty
                                    ? const [
                                        DataRow(
                                          cells: [
                                            DataCell(Text('—')),
                                            DataCell(
                                              Text(
                                                'No attendance records logged for this period yet.',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text('—')),
                                            DataCell(Text('—')),
                                            DataCell(Text('—')),
                                            DataCell(Text('—')),
                                            DataCell(Text('—')),
                                          ],
                                        ),
                                      ]
                                    : pageRows.map((row) {
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
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                          ),
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
                                              _showCorrectionDialog(
                                                context,
                                                row,
                                              ),
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
                                        () =>
                                            _historyCurrentPage = safePage - 1,
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
                                        () =>
                                            _historyCurrentPage = safePage + 1,
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

class _AttendanceDonutSlice {
  final String label;
  final String sub;
  final int count;
  final double pct;
  final Color color;
  final String dotLabel;

  const _AttendanceDonutSlice({
    required this.label,
    required this.sub,
    required this.count,
    required this.pct,
    required this.color,
    required this.dotLabel,
  });
}

class _AttendanceDonutChartPainter extends CustomPainter {
  final List<_AttendanceDonutSlice> slices;
  final double progress;
  final double strokeWidth;
  final bool isDark;
  final int? hoveredIndex;

  _AttendanceDonutChartPainter({
    required this.slices,
    required this.progress,
    required this.strokeWidth,
    this.isDark = false,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track Ring
    final trackPaint = Paint()
      ..color = isDark ? Colors.white10 : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (slices.isEmpty) return;

    var startAngle = -pi / 2;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      if (slice.pct <= 0) continue;
      final sweepAngle = (slice.pct / 100) * 2 * pi * progress;

      final isHovered = hoveredIndex == i;
      final effectiveStroke = isHovered ? strokeWidth + 4 : strokeWidth;

      if (isHovered) {
        final glowPaint = Paint()
          ..color = slice.color.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveStroke + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      final slicePaint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        slicePaint,
      );

      startAngle += (slice.pct / 100) * 2 * pi;
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceDonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.slices != slices ||
        oldDelegate.isDark != isDark ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

class TrendChartPainter extends CustomPainter {
  final List<AttendanceTrendPoint> points;
  final Color presentColor;
  final Color absentColor;
  final Color textColor;
  final double progress;
  final bool isDark;

  TrendChartPainter({
    required this.points,
    required this.presentColor,
    required this.absentColor,
    required this.textColor,
    this.progress = 1.0,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const bottomPadding = 22.0;
    const topPadding = 14.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final baseline = size.height - bottomPadding;

    final maxVal = points.fold<int>(
      1,
      (prev, elem) =>
          max(prev, max(elem.presentCount, elem.absentOrExcusedCount)),
    );

    // Subtle horizontal grid lines with glassmorphism style
    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: isDark ? 0.12 : 0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = baseline - (chartHeight * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final n = points.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width / 2;
    final clampedProgress = progress.clamp(0.0, 1.0);

    final presentOffsets = <Offset>[];
    final absentOffsets = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = n > 1 ? i * stepX : size.width / 2;
      final yPres = baseline -
          ((points[i].presentCount / maxVal) * chartHeight * clampedProgress);
      final yAbs = baseline -
          ((points[i].absentOrExcusedCount / maxVal) *
              chartHeight *
              clampedProgress);

      presentOffsets.add(Offset(x, yPres));
      absentOffsets.add(Offset(x, yAbs));
    }

    // 1. Draw glowing gradient areas under lines (Glassmorphism fill)
    if (presentOffsets.length > 1) {
      final presentAreaPath = Path()..moveTo(presentOffsets.first.dx, baseline);
      for (final pt in presentOffsets) {
        presentAreaPath.lineTo(pt.dx, pt.dy);
      }
      presentAreaPath.lineTo(presentOffsets.last.dx, baseline);
      presentAreaPath.close();

      final presentAreaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            presentColor.withValues(alpha: isDark ? 0.30 : 0.18),
            presentColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(presentAreaPath, presentAreaPaint);

      final absentAreaPath = Path()..moveTo(absentOffsets.first.dx, baseline);
      for (final pt in absentOffsets) {
        absentAreaPath.lineTo(pt.dx, pt.dy);
      }
      absentAreaPath.lineTo(absentOffsets.last.dx, baseline);
      absentAreaPath.close();

      final absentAreaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            absentColor.withValues(alpha: isDark ? 0.25 : 0.14),
            absentColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(absentAreaPath, absentAreaPaint);
    }

    // 2. Stroke lines
    final presentLinePaint = Paint()
      ..color = presentColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final absentLinePaint = Paint()
      ..color = absentColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final presentPath = Path();
    final absentPath = Path();

    for (int i = 0; i < n; i++) {
      if (i == 0) {
        presentPath.moveTo(presentOffsets[i].dx, presentOffsets[i].dy);
        absentPath.moveTo(absentOffsets[i].dx, absentOffsets[i].dy);
      } else {
        presentPath.lineTo(presentOffsets[i].dx, presentOffsets[i].dy);
        absentPath.lineTo(absentOffsets[i].dx, absentOffsets[i].dy);
      }
    }

    canvas.drawPath(presentPath, presentLinePaint);
    canvas.drawPath(absentPath, absentLinePaint);

    // 3. Glowing halo dots & X-axis date labels
    for (int i = 0; i < n; i++) {
      final ptPres = presentOffsets[i];
      final ptAbs = absentOffsets[i];

      // Present Point
      canvas.drawCircle(
        ptPres,
        5.5,
        Paint()..color = presentColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        ptPres,
        3.5,
        Paint()..color = presentColor,
      );
      canvas.drawCircle(
        ptPres,
        1.5,
        Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white,
      );

      // Absent Point
      canvas.drawCircle(
        ptAbs,
        5.5,
        Paint()..color = absentColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        ptAbs,
        3.5,
        Paint()..color = absentColor,
      );
      canvas.drawCircle(
        ptAbs,
        1.5,
        Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white,
      );

      // Date / Period label on X-axis
      final rawLabel = points[i].periodLabel ??
          (points[i].bucketStart != null
              ? '${points[i].bucketStart!.month}/${points[i].bucketStart!.day}'
              : 'P${i + 1}');

      final label = rawLabel.length > 8 ? rawLabel.substring(0, 8) : rawLabel;

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.70),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX =
          (ptPres.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(labelX, baseline + 5));
    }
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.textColor != textColor ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark;
  }
}
