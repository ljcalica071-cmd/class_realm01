import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';

class ActivitySubmissionsScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivitySubmissionsScreen({super.key, required this.activity});

  static Future<void> show(BuildContext context, ActivityModel activity) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActivitySubmissionsScreen(activity: activity)),
    );
  }

  @override
  State<ActivitySubmissionsScreen> createState() => _ActivitySubmissionsScreenState();
}

class _ActivitySubmissionsScreenState extends State<ActivitySubmissionsScreen> {
  String _selectedSection = 'All';

  @override
  Widget build(BuildContext context) {
    final sections = ['All', ...MockDatabase.instance.sections];
    final students = MockDatabase.instance.users.where((u) => u.role == UserRole.student && !u.isArchived).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Submissions: ${widget.activity.title}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info & Section Dropdown Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.activity.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Subject: ${widget.activity.subject} • Max Score: ${widget.activity.maxScore.toInt()} pts', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Filter Section: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedSection,
                      items: sections.map((sec) => DropdownMenuItem(value: sec, child: Text(sec))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSection = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Students List Table / Cards for checking
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final student = students[i];
                    // Find submission if exists
                    final submission = MockDatabase.instance.activitySubmissions.firstWhere(
                      (sub) => sub.activityOrExamId == widget.activity.id && sub.studentId == student.id,
                      orElse: () => StudentSubmission(
                        id: 'sub_dummy_${student.id}',
                        activityOrExamId: widget.activity.id,
                        studentId: student.id,
                        studentName: student.fullName,
                        submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
                        attachedFile: '${student.fullName.replaceAll(" ", "")}_Output.pdf',
                        textSubmission: 'Here is my complete problem solution and derived graph for Rational Functions.',
                        maxScore: widget.activity.maxScore,
                        status: ActivityStatus.submitted,
                      ),
                    );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Text(student.fullName.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text('ID: ${student.studentId} • Section: ${student.departmentOrSection ?? "STEM 11-A"} • Status: ${submission.status.name.toUpperCase()}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (submission.score != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(20)),
                              child: Text('${submission.score!.toInt()} / ${widget.activity.maxScore.toInt()}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                            )
                          else
                            const StatusBadge(text: 'Pending Review', backgroundColor: AppColors.warningLight, textColor: AppColors.warning),
                          const SizedBox(width: 16),
                          AppPrimaryButton(
                            label: submission.score != null ? 'Edit Score' : 'Review & Score',
                            height: 36,
                            width: 130,
                            onPressed: () => _showScoringModal(context, submission, student.fullName),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScoringModal(BuildContext context, StudentSubmission submission, String studentName) {
    final scoreCtrl = TextEditingController(text: submission.score?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: submission.feedback ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review Submission: $studentName'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attached Student Work:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(submission.attachedFile ?? 'Student_Output_Work.pdf', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (submission.textSubmission != null) ...[
                const Text('Student Text Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: Text(submission.textSubmission!, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Score (Max: ${widget.activity.maxScore.toInt()})'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remarks / Feedback (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AppPrimaryButton(
            label: 'Save Score & Remarks',
            height: 40,
            onPressed: () {
              final double? enteredScore = double.tryParse(scoreCtrl.text.trim());
              if (enteredScore == null || enteredScore < 0 || enteredScore > widget.activity.maxScore) {
                AppModals.showErrorDialog(context: context, title: 'Invalid Score', message: 'Please enter a valid numeric score between 0 and ${widget.activity.maxScore.toInt()}.');
                return;
              }

              setState(() {
                MockDatabase.instance.scoreSubmission(submission.id, enteredScore, feedbackCtrl.text.trim());
              });
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(
                context: context,
                title: 'Score Saved',
                message: 'Score of ${enteredScore.toInt()} / ${widget.activity.maxScore.toInt()} saved successfully and released to student portal.',
              );
            },
            width: 170,
          ),
        ],
      ),
    );
  }
}
