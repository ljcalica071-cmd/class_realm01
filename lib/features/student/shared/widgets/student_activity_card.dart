import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_assessment_screen.dart';

class StudentActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final UserModel student;
  final VoidCallback onSubmitted;

  const StudentActivityCard({
    super.key,
    required this.activity,
    required this.student,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submission =
        MockDatabase.instance.submissionFor(activity.id, student.id);
    final isPastDeadline = DateTime.now().isAfter(activity.deadline);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final status = submission != null
                  ? StatusBadge(
                      text: submission.status == ActivityStatus.graded
                          ? 'Graded'
                          : 'Submitted',
                      backgroundColor:
                          submission.status == ActivityStatus.graded
                              ? AppTheme.catGreen.withValues(alpha: 0.1)
                              : AppTheme.catBlue.withValues(alpha: 0.1),
                      textColor: submission.status == ActivityStatus.graded
                          ? AppTheme.catGreen
                          : AppTheme.catBlue,
                    )
                  : isPastDeadline
                  ? StatusBadge(
                      text: 'Missing',
                      backgroundColor: AppTheme.catRed.withValues(alpha: 0.1),
                      textColor: AppTheme.catRed,
                    )
                  : null;
              if (constraints.maxWidth < 300 && status != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    status,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      activity.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    status,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            activity.description,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppTheme.catRed),
              const SizedBox(width: 4),
              Text(
                'Due: ${_formatDeadline(activity.deadline)}',
                style: const TextStyle(
                  color: AppTheme.catRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (submission == null && !isPastDeadline)
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label:
                    activity.id == 'WW3'
                        ? 'Start Quiz'
                        : activity.isRequirement
                        ? 'Upload Performance Task'
                        : 'Upload & Submit Document',
                onPressed: () {
                  if (activity.id == 'WW3') {
                    final quiz = MockDatabase.instance.quizzesAndExams.firstWhere(
                      (q) => q.id == 'WW3',
                    );
                    StudentAssessmentScreen.start(context, quiz).then((_) => onSubmitted());
                  } else {
                    MockDatabase.instance.submitActivity(
                      activity.id,
                      student.id,
                      student.fullName,
                      '${student.id}_Solution.pdf',
                    );
                    AppModals.showSuccessDialog(
                      context: context,
                      title: 'Submission Successful',
                      message: 'File uploaded and status updated to Submitted.',
                    );
                    onSubmitted();
                  }
                },
              ),
            )
          else if (submission?.status == ActivityStatus.graded)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Score: ${submission!.score?.toInt() ?? 0} / ${activity.maxScore.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.catGreen,
                  ),
                ),
                if (submission.feedback != null)
                  TextButton(
                    onPressed: () {
                      AppModals.showSuccessDialog(
                        context: context,
                        title: 'Teacher Feedback',
                        message: submission.feedback!,
                      );
                    },
                    child: const Text('View Feedback'),
                  ),
              ],
            )
          else if (submission != null)
            Text(
              'Awaiting teacher grading...',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDeadline(DateTime date) {
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
    final hour = date.hour > 12 ? date.hour - 12 : date.hour == 0 ? 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $period';
  }
}
