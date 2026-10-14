import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/widgets/common/status_badge.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final AttendanceRepository? repository;

  const StudentAttendanceScreen({super.key, this.repository});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  late final AttendanceRepository _repo;

  bool _isLoading = true;
  String? _errorMessage;

  AttendanceStudentSummary? _summary;
  final List<AttendanceRecord> _records = [];
  int _offset = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;

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
        _records.clear();
        _records.addAll(page.rows);
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more records: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: theme.colorScheme.primary,
          size: 40,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Error loading attendance: $_errorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadInitialData,
              ),
            ],
          ),
        ),
      );
    }

    final presentCount = _summary?.presentCount ?? 0;
    final totalDays = _summary?.totalDays ?? 0;
    final ratePercent = ((_summary?.presenceRate ?? 0.0) * 100).toInt();

    return Column(
      children: [
        // Preserved Summary Header Layout
        Container(
          padding: const EdgeInsets.all(24),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              _buildStatItem(
                theme,
                'Present',
                presentCount.toString(),
                AppTheme.catGreen,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                theme,
                'Total Days',
                totalDays.toString(),
                theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                theme,
                'Rate',
                '$ratePercent%',
                AppTheme.catBlue,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Logs List with Server Pagination
        Expanded(
          child: _records.isEmpty
              ? const Center(
                  child: Text('No attendance records found.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    if (i == _records.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: _isLoadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton.icon(
                                  icon: const Icon(Icons.arrow_downward, size: 16),
                                  label: const Text('Load More Records'),
                                  onPressed: _loadMoreRecords,
                                ),
                        ),
                      );
                    }

                    final record = _records[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
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
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Class: ${record.method}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                                if (record.remarks?.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      record.remarks!,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
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
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
