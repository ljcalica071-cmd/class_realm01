import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../models/user_model.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';

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
    final submission =
        MockDatabase.instance.submissionFor(activity.id, student.id);
    final isPastDeadline = DateTime.now().isAfter(activity.deadline);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (submission != null)
                StatusBadge(
                  text:
                      submission.status == ActivityStatus.graded
                          ? 'Graded'
                          : 'Submitted',
                  backgroundColor:
                      submission.status == ActivityStatus.graded
                          ? AppColors.successLight
                          : AppColors.infoLight,
                  textColor:
                      submission.status == ActivityStatus.graded
                          ? AppColors.success
                          : AppColors.info,
                )
              else if (isPastDeadline)
                const StatusBadge(
                  text: 'Missing',
                  backgroundColor: AppColors.errorLight,
                  textColor: AppColors.error,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            activity.description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (submission == null && !isPastDeadline)
            AppPrimaryButton(
              label:
                  activity.isRequirement
                      ? 'Upload Requirement'
                      : 'Upload & Submit Document',
              height: 40,
              onPressed: () {
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
              },
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
                    color: AppColors.success,
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
            const Text(
              'Awaiting teacher grading...',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
