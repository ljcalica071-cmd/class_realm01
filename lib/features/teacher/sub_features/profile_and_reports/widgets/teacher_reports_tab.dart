import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherReportsTab extends StatelessWidget {
  const TeacherReportsTab({super.key});

  void _showExportConfirm(BuildContext context, String reportName) {
    AppModals.showSuccessDialog(
      context: context,
      title: 'Report Generated',
      message:
          '$reportName has been compiled and saved locally. Ready for printing or official school archiving.',
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onDownload,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              minimumSize: const Size(double.infinity, 36),
            ),
            icon: const Icon(Icons.download, size: 16),
            label: const Text(
              'Generate / Download',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic & DepEd Reports Generator',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate, view, and export official attendance summaries and quarterly grading sheets.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              AppButton.primary(
                label: 'Export All DepEd Forms',
                icon: Icons.download_outlined,
                onPressed: () {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Reports Export Simulated',
                    message:
                        'Official SF2 (Attendance) and SF9 (Progress Report) generated successfully in PDF/Excel format.',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Report Options Cards
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.5,
            children: [
              _buildReportCard(
                context: context,
                title: 'School Form 2 (SF2)',
                subtitle: 'Daily Attendance Report of Learners',
                icon: Icons.fact_check_outlined,
                color: theme.colorScheme.primary,
                onDownload: () =>
                    _showExportConfirm(context, 'School Form 2 (SF2)'),
              ),
              _buildReportCard(
                context: context,
                title: 'Quarterly Grading Sheet',
                subtitle: 'Grade 11 Mathematics Component Summaries',
                icon: Icons.grade_outlined,
                color: AppTheme.catGreen,
                onDownload: () =>
                    _showExportConfirm(context, 'Quarterly Grading Sheet'),
              ),
              _buildReportCard(
                context: context,
                title: 'School Form 9 (SF9)',
                subtitle: 'Learner Progress Report Card',
                icon: Icons.badge_outlined,
                color: AppTheme.catBlue,
                onDownload: () =>
                    _showExportConfirm(context, 'School Form 9 (SF9)'),
              ),
              _buildReportCard(
                context: context,
                title: 'At-Risk Remediation Log',
                subtitle: 'Early warning list of students below 75%',
                icon: Icons.warning_amber_outlined,
                color: AppTheme.catRed,
                onDownload: () =>
                    _showExportConfirm(context, 'At-Risk Remediation Log'),
              ),
              _buildReportCard(
                context: context,
                title: 'Activity Completion Masterlist',
                subtitle: 'Overall task submissions across 5 sections',
                icon: Icons.assignment_turned_in_outlined,
                color: AppTheme.catPurple,
                onDownload: () => _showExportConfirm(
                    context, 'Activity Completion Masterlist'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
