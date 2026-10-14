import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';

enum AttendanceDatePreset {
  thisWeek,
  thisMonth,
  custom,
}

class AttendanceHistoryAnalyticsView extends StatefulWidget {
  final String subjectOfferingId;
  final AttendanceRepository? repository;

  const AttendanceHistoryAnalyticsView({
    super.key,
    required this.subjectOfferingId,
    this.repository,
  });

  @override
  State<AttendanceHistoryAnalyticsView> createState() =>
      _AttendanceHistoryAnalyticsViewState();
}

class _AttendanceHistoryAnalyticsViewState
    extends State<AttendanceHistoryAnalyticsView> {
  late final AttendanceRepository _repository;

  AttendanceDatePreset _selectedPreset = AttendanceDatePreset.thisWeek;
  late DateTime _customStartDate;
  late DateTime _customEndDate;

  bool _isLoadingAnalytics = true;
  String? _analyticsError;
  AttendanceAnalyticsSummary? _analyticsSummary;

  bool _isLoadingHistory = true;
  String? _historyError;
  List<AttendanceWorkspaceRecord> _historyRows = [];
  int _historyOffset = 0;
  bool _historyHasMore = false;
  bool _isLoadingMoreHistory = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseAttendanceRepository.instance;
    final now = DateTime.now();
    _customStartDate = now.subtract(const Duration(days: 7));
    _customEndDate = now;
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryAnalyticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectOfferingId != widget.subjectOfferingId) {
      _loadAll();
    }
  }

  AttendanceDateRange _computeCurrentDateRange() {
    final now = DateTime.now();
    switch (_selectedPreset) {
      case AttendanceDatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return AttendanceDateRange(
          startDate: DateTime(monday.year, monday.month, monday.day),
          endDate: DateTime(now.year, now.month, now.day),
        );
      case AttendanceDatePreset.thisMonth:
        return AttendanceDateRange(
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month, now.day),
        );
      case AttendanceDatePreset.custom:
        final start = _customStartDate.isAfter(_customEndDate)
            ? _customEndDate
            : _customStartDate;
        final end = _customStartDate.isAfter(_customEndDate)
            ? _customStartDate
            : _customEndDate;
        return AttendanceDateRange(
          startDate: DateTime(start.year, start.month, start.day),
          endDate: DateTime(end.year, end.month, end.day),
        );
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadAnalytics(),
      _loadInitialHistory(),
    ]);
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoadingAnalytics = true;
      _analyticsError = null;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyticsError = null;
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
      _historyError = null;
      _historyRows = [];
      _historyOffset = 0;
      _historyHasMore = false;
    });

    try {
      final range = _computeCurrentDateRange();
      final page = await _repository.getAttendanceHistory(
        AttendanceHistoryFilter(
          subjectOfferingId: widget.subjectOfferingId,
          dateRange: range,
          offset: 0,
          pageSize: 20,
        ),
      );
      if (!mounted) return;
      setState(() {
        _historyRows = page.rows;
        _historyOffset = page.nextOffset;
        _historyHasMore = page.hasMore;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = null;
        _historyRows = [];
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMoreHistory || !_historyHasMore) return;
    setState(() => _isLoadingMoreHistory = true);

    try {
      final range = _computeCurrentDateRange();
      final page = await _repository.getAttendanceHistory(
        AttendanceHistoryFilter(
          subjectOfferingId: widget.subjectOfferingId,
          dateRange: range,
          offset: _historyOffset,
          pageSize: 20,
        ),
      );
      if (!mounted) return;
      setState(() {
        _historyRows.addAll(page.rows);
        _historyOffset = page.nextOffset;
        _historyHasMore = page.hasMore;
        _isLoadingMoreHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMoreHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more records: $e')),
      );
    }
  }

  Future<void> _showCorrectionDialog(
    BuildContext context,
    AttendanceWorkspaceRecord record,
  ) async {
    AttendanceStatus selectedStatus = record.status;
    final reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isValid = reasonController.text.trim().isNotEmpty;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    LucideIcons.fileEdit,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('Correct Attendance Record'),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student: ${record.studentId} • Date: ${_formatDate(record.attendanceDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Current Status: ',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        _buildStatusBadge(record.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'New Status:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: AttendanceStatus.values.map((status) {
                        final isSelected = selectedStatus == status;
                        return ChoiceChip(
                          label: Text(status.name.toUpperCase()),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => selectedStatus = status);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reason for correction (required):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Medical certificate presented',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          Navigator.of(dialogCtx).pop();
                          try {
                            await _repository.correctAttendanceRecord(
                              subjectOfferingId: widget.subjectOfferingId,
                              recordId: record.id ?? '',
                              newStatus: selectedStatus,
                              reason: reasonController.text.trim(),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Attendance record corrected.'),
                              ),
                            );
                            _loadAll();
                          } catch (err) {
                            if (!mounted) return;
                            AppModals.showErrorDialog(
                              context: context,
                              title: 'Correction Failed',
                              message: err.toString(),
                            );
                          }
                        }
                      : null,
                  child: const Text('Submit Correction'),
                ),
              ],
            );
          },
        );
      },
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Presets Bar
        _buildDateFilterBar(theme),
        const SizedBox(height: 20),

        // Analytics Section
        if (_isLoadingAnalytics)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _buildKpiCards(
            theme,
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
                ),
          ),
          const SizedBox(height: 20),
          _buildChartsSection(
            theme,
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
                ),
          ),
          const SizedBox(height: 20),
          _buildAtRiskSection(
            theme,
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
                ),
          ),
        ],

        const SizedBox(height: 24),
        // History Activity Log
        _buildHistorySection(theme),
      ],
    );
  }

  Widget _buildDateFilterBar(ThemeData theme) {
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
              _buildPresetButton('This week', AttendanceDatePreset.thisWeek),
              const SizedBox(width: 8),
              _buildPresetButton('This month', AttendanceDatePreset.thisMonth),
              const SizedBox(width: 8),
              _buildPresetButton('Custom', AttendanceDatePreset.custom),
            ],
          ),
          if (_selectedPreset == AttendanceDatePreset.custom) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDatePickerField(
                  label: 'Start Date',
                  date: _customStartDate,
                  onPicked: (d) {
                    setState(() => _customStartDate = d);
                    _loadAll();
                  },
                ),
                _buildDatePickerField(
                  label: 'End Date',
                  date: _customEndDate,
                  onPicked: (d) {
                    setState(() => _customEndDate = d);
                    _loadAll();
                  },
                ),
                if (_customStartDate.isAfter(_customEndDate))
                  Text(
                    'Start date cannot be after end date.',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
        ? AppButton.primary(
            label: label,
            isSmall: true,
            onPressed: () {},
          )
        : AppButton.outline(
            label: label,
            isSmall: true,
            onPressed: () {
              setState(() => _selectedPreset = preset);
              _loadAll();
            },
          );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showAppDatePickerDialog(
          context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          title: 'Select $label',
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${_formatDate(date)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.calendar, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(ThemeData theme, AttendanceAnalyticsSummary summary) {
    final rateStr = summary.presenceRate != null
        ? '${summary.presenceRate!.toStringAsFixed(1)}%'
        : '0.0%';
    final total = summary.presentCount +
        summary.lateCount +
        summary.absentCount +
        summary.excusedCount;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final children = [
          _buildKpiCard(
            title: 'Total Presence Rate',
            value: rateStr,
            subtitle: total > 0
                ? '(Present + Late) / Total Recorded'
                : 'No attendance records in period',
            icon: LucideIcons.percent,
            color: AppTheme.catGreen,
            theme: theme,
          ),
          _buildKpiCard(
            title: 'Absences & Excuses',
            value: '${summary.absencesAndExcuses}',
            subtitle: 'Absences: ${summary.absentCount} • Excused: ${summary.excusedCount}',
            icon: LucideIcons.userX,
            color: AppTheme.catRed,
            theme: theme,
          ),
          _buildKpiCard(
            title: 'Attendance Warnings',
            value: '${summary.warningCount}',
            subtitle: 'Students with ≥ 3 Absences',
            icon: LucideIcons.alertTriangle,
            color: AppTheme.catOrange,
            theme: theme,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: children
                .map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: w,
                    ))
                .toList(),
          );
        }

        return Row(
          children: children
              .map((w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: w,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
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
            children: [
              trendCard,
              const SizedBox(height: 16),
              breakdownCard,
            ],
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
              Icon(LucideIcons.trendingUp, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Attendance Trend',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.lineChart,
                      size: 28,
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No Trend Data Recorded',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trends will plot automatically once daily attendance is logged.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
    final total = summary.presentCount +
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
              Icon(LucideIcons.pieChart, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Status Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow('Present', summary.presentCount, total, AppTheme.catGreen),
          const SizedBox(height: 8),
          _buildBreakdownRow('Late', summary.lateCount, total, AppTheme.catOrange),
          const SizedBox(height: 8),
          _buildBreakdownRow('Absent', summary.absentCount, total, AppTheme.catRed),
          const SizedBox(height: 8),
          _buildBreakdownRow('Excused', summary.excusedCount, total, AppTheme.catSlate),
          if (total == 0) ...[
            const SizedBox(height: 12),
            Text(
              'No attendance status breakdown recorded for this period yet.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total) * 100 : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('$count (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
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
    final totalRecorded = summary.presentCount +
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
              Icon(LucideIcons.alertOctagon, size: 18, color: AppTheme.catOrange),
              const SizedBox(width: 8),
              const Text(
                'At-Risk Students (≥ 3 Absences)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${summary.atRiskStudents.length} identified',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Notice: This tracker serves as an academic early warning only and does not drop enrollments or deactivate student accounts.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          if (totalRecorded == 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Attendance Records in Period',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Early warning and at-risk monitoring will activate once daily attendance records are logged for enrolled students.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (summary.atRiskStudents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.catGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.catGreen.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.checkCircle2,
                    color: AppTheme.catGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All Students in Good Standing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No students currently have 3 or more absences in this period.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summary.atRiskStudents.length,
              itemBuilder: (ctx, i) {
                final student = summary.atRiskStudents[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.catOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.catOrange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.catOrange.withValues(alpha: 0.2),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: AppTheme.catOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'ID: ${student.studentId} • Section: ${student.section}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.catRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${student.absenceCount} Absences',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
              Icon(LucideIcons.history, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Activity History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.history,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Activity Records',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No attendance records found for this period.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton.outline(
                      label: 'Refresh',
                      icon: LucideIcons.refreshCw,
                      isSmall: true,
                      onPressed: _loadInitialHistory,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _historyRows.length,
              itemBuilder: (ctx, i) {
                final row = _historyRows[i];
                final timeStr = row.createdAt != null
                    ? '${row.createdAt!.hour.toString().padLeft(2, '0')}:${row.createdAt!.minute.toString().padLeft(2, '0')}'
                    : '—';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          _formatDate(row.attendanceDate),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student: ${row.studentId}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Source: ${row.source.name} • Time: $timeStr',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(row.status),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _showCorrectionDialog(context, row),
                        child: const Text('Correct', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_historyHasMore) ...[
              const SizedBox(height: 12),
              Center(
                child: _isLoadingMoreHistory
                    ? const CircularProgressIndicator()
                    : AppButton.outline(
                        label: 'Load More Records',
                        isSmall: true,
                        icon: LucideIcons.chevronDown,
                        onPressed: _loadMoreHistory,
                      ),
              ),
            ] else if (_historyRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.checkCheck, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'All ${_historyRows.length} attendance records loaded',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceStatus status) {
    Color bg;
    Color fg = Colors.white;
    switch (status) {
      case AttendanceStatus.present:
        bg = AppTheme.catGreen;
        break;
      case AttendanceStatus.late:
        bg = AppTheme.catOrange;
        break;
      case AttendanceStatus.absent:
        bg = AppTheme.catRed;
        break;
      case AttendanceStatus.excused:
        bg = AppTheme.catSlate;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, color: theme.colorScheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            AppButton.outline(
              label: 'Retry',
              isSmall: true,
              onPressed: onRetry,
            ),
        ],
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
      (prev, elem) => max(prev, max(elem.presentCount, elem.absentOrExcusedCount)),
    );

    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    // Draw horizontal guidelines
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
      final yPres = size.height - (points[i].presentCount / maxVal * (size.height - 20)) - 10;
      final yAbs = size.height - (points[i].absentOrExcusedCount / maxVal * (size.height - 20)) - 10;

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
    return oldDelegate.points != points;
  }
}
