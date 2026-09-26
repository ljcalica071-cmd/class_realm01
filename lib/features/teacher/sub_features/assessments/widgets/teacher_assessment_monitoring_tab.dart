import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/status_badge.dart';

class TeacherAssessmentMonitoringTab extends StatefulWidget {
  final List<QuizOrExamModel> quizzes;

  const TeacherAssessmentMonitoringTab({
    super.key,
    required this.quizzes,
  });

  @override
  State<TeacherAssessmentMonitoringTab> createState() =>
      _TeacherAssessmentMonitoringTabState();
}

class _TeacherAssessmentMonitoringTabState
    extends State<TeacherAssessmentMonitoringTab> {
  String? _monitoringAssessmentId;

  @override
  void initState() {
    super.initState();
    if (widget.quizzes.isNotEmpty) {
      _monitoringAssessmentId = widget.quizzes.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_monitoringAssessmentId == null && widget.quizzes.isNotEmpty) {
      _monitoringAssessmentId = widget.quizzes.first.id;
    }

    final results = MockDatabase.instance.assessmentResults
        .where((r) => r.assessmentId == _monitoringAssessmentId)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assessment Monitoring Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Monitor student progress, completion status, and anti-cheating violations in real-time.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // Assessment Selector
          Row(
            children: [
              Text(
                'Select Assessment: ',
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                ),
                child: DropdownButton<String>(
                  value: _monitoringAssessmentId,
                  underline: const SizedBox(),
                  items: widget.quizzes
                      .map(
                        (q) =>
                            DropdownMenuItem(value: q.id, child: Text(q.title)),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _monitoringAssessmentId = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Results Table
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(theme.colorScheme.surface),
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Student',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Submission Time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Duration',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Score',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Violations',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: results.map((res) {
                    final status = res.violationCount == 0
                        ? 'Normal'
                        : res.violationCount == 1
                        ? 'Warning'
                        : res.violationCount == 2
                        ? 'Suspicious'
                        : 'Auto-Submitted';
                    final statusColor = res.violationCount == 0
                        ? AppTheme.catGreen
                        : res.violationCount == 1
                        ? AppTheme.catOrange
                        : AppTheme.catRed;

                    return DataRow(
                      onSelectChanged: (_) => _showViolationDetail(res, theme),
                      cells: [
                        DataCell(Text(res.studentName)),
                        DataCell(
                          Text(res.submittedAt.toString().substring(11, 16)),
                        ),
                        DataCell(Text('${res.durationTakenMinutes}m')),
                        DataCell(
                          StatusBadge(
                            text: status,
                            backgroundColor: statusColor.withValues(alpha: 0.1),
                            textColor: statusColor,
                          ),
                        ),
                        DataCell(
                          Text(
                            '${res.scoreEarned.toInt()} / ${res.totalPoints.toInt()}',
                          ),
                        ),
                        DataCell(
                          Text(
                            res.violationCount.toString(),
                            style: TextStyle(
                              color: res.violationCount > 0
                                  ? AppTheme.catRed
                                  : theme.colorScheme.onSurface,
                              fontWeight: res.violationCount > 0
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showViolationDetail(AssessmentResultModel result, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Violation History: ${result.studentName}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Violations: ${result.violationCount}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (result.violationLog.isEmpty)
                const Text('No violations recorded for this session.')
              else
                ...result.violationLog.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          '[${v['timestamp'] ?? 'N/A'}]',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(v['type'] ?? 'Violation')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
