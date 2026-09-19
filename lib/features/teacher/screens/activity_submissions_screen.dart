import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';

class ActivitySubmissionsScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool embedded;
  final VoidCallback? onBack;

  const ActivitySubmissionsScreen({
    super.key,
    required this.activity,
    this.embedded = false,
    this.onBack,
  });

  static Future<void> show(BuildContext context, ActivityModel activity) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivitySubmissionsScreen(activity: activity),
      ),
    );
  }

  @override
  State<ActivitySubmissionsScreen> createState() =>
      _ActivitySubmissionsScreenState();
}

class _ActivitySubmissionsScreenState extends State<ActivitySubmissionsScreen> {
  String _selectedStatus = 'All';
  String _selectedSection = 'All Sections';

  @override
  Widget build(BuildContext context) {
    final statuses = ['All', 'Graded', 'Pending', 'Unsubmitted'];
    final sections = ['All Sections', 'Section A', 'Section B'];
    final allStudents = MockDatabase.instance.users.where((u) {
      if (u.role != UserRole.student || u.isArchived) return false;
      if (_selectedSection != 'All Sections' &&
          u.departmentOrSection != _selectedSection) {
        return false;
      }
      if (!widget.activity.assignedSections.contains(u.departmentOrSection)) {
        return false;
      }
      return true;
    }).toList();
    final statusCounts = <String, int>{
      'Graded': 0,
      'Pending': 0,
      'Unsubmitted': 0,
    };
    for (final student in allStudents) {
      final submission = _submissionFor(student.id);
      statusCounts[_statusFor(submission)] =
          statusCounts[_statusFor(submission)]! + 1;
    }
    final students = allStudents.where((u) {
      final matching = MockDatabase.instance.activitySubmissions.where(
        (sub) =>
            sub.activityOrExamId == widget.activity.id && sub.studentId == u.id,
      );
      final submission = matching.isEmpty ? null : matching.first;
      final status = _statusFor(submission);
      return _selectedStatus == 'All' || status == _selectedStatus;
    }).toList();

    final content = Container(
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
                  Text(
                    widget.activity.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subject: ${widget.activity.subject} • Sections: ${widget.activity.section}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${allStudents.length - statusCounts['Unsubmitted']!}/${allStudents.length} submitted  •  ${statusCounts['Graded']} graded  •  ${statusCounts['Pending']} pending  •  ${statusCounts['Unsubmitted']} unsubmitted',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Text(
                    'Section: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  DropdownButton<String>(
                    value: _selectedSection,
                    items: sections
                        .map(
                          (section) => DropdownMenuItem(
                            value: section,
                            child: Text(section),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedSection = value);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    items: statuses
                        .map(
                          (sec) =>
                              DropdownMenuItem(value: sec, child: Text(sec)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
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
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final student = students[i];
                  // Find submission if exists
                  final submission = MockDatabase.instance.activitySubmissions
                      .firstWhere(
                        (sub) =>
                            sub.activityOrExamId == widget.activity.id &&
                            sub.studentId == student.id,
                        orElse: () => StudentSubmission(
                          id: 'sub_dummy_${student.id}',
                          activityOrExamId: widget.activity.id,
                          studentId: student.id,
                          studentName: student.fullName,
                          submittedAt: DateTime.now(),
                          maxScore: widget.activity.maxScore,
                          status: ActivityStatus.pending,
                        ),
                      );
                  final name = [
                    student.lastName ?? student.fullName.split(' ').last,
                    student.firstName ?? student.fullName.split(' ').first,
                  ].join(', ');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        student.fullName.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(_submissionStatus(submission)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (submission.score != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  submission.score! >=
                                      widget.activity.maxScore * 0.76
                                  ? AppColors.successLight
                                  : AppColors.errorLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${submission.score!.toInt()} / ${widget.activity.maxScore.toInt()}',
                              style: TextStyle(
                                color:
                                    submission.score! >=
                                        widget.activity.maxScore * 0.76
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          StatusBadge(
                            text: _statusText(submission),
                            backgroundColor: submission.attachedFile == null
                                ? AppColors.background
                                : AppColors.warningLight,
                            textColor: submission.attachedFile == null
                                ? AppColors.textSecondary
                                : AppColors.warning,
                          ),
                        const SizedBox(width: 16),
                        AppPrimaryButton(
                          label: 'View',
                          height: 36,
                          width: 130,
                          onPressed: () => _showScoringModal(
                            context,
                            submission,
                            student.fullName,
                          ),
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
    );
    final header = Container(
      height: 58,
      color: AppColors.primary,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
          ),
          Text(
            'For Performance Task Submissions: ${widget.activity.title}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) {
      return Column(
        children: [
          header,
          Expanded(child: content),
        ],
      );
    }
    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(child: content),
        ],
      ),
    );
  }

  String _formatSubmittedAt(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    return '${date.month}/${date.day}/${date.year} $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  StudentSubmission? _submissionFor(String studentId) {
    final matches = MockDatabase.instance.activitySubmissions.where(
      (sub) =>
          sub.activityOrExamId == widget.activity.id &&
          sub.studentId == studentId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  String _statusFor(StudentSubmission? submission) {
    if (submission?.score != null) return 'Graded';
    if (submission?.attachedFile != null) return 'Pending';
    return 'Unsubmitted';
  }

  String _statusText(StudentSubmission submission) {
    if (submission.attachedFile == null) return 'Unsubmitted';
    return 'Pending Review';
  }

  String _submissionStatus(StudentSubmission submission) {
    if (submission.attachedFile == null) return 'Status: UNSUBMITTED';
    if (submission.score != null) {
      return 'Status: GRADED • Submitted ${_formatSubmittedAt(submission.submittedAt)}';
    }
    return 'Status: PENDING • Submitted ${_formatSubmittedAt(submission.submittedAt)}';
  }

  void _showScoringModal(
    BuildContext context,
    StudentSubmission submission,
    String studentName,
  ) {
    final scoreCtrl = TextEditingController(
      text: submission.score?.toString() ?? '',
    );
    final feedbackCtrl = TextEditingController(text: submission.feedback ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Performance Task Submissions: $studentName'),
        content: SizedBox(
          width: 560,
          child: Column(
            children: [
              Container(
                height: 190,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: AppColors.error,
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Student Work File',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            submission.attachedFile ?? 'No file submitted yet',
                          ),
                          if (submission.attachedFile != null)
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open file'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  labelText: 'Score (Max: ${widget.activity.maxScore.toInt()})',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Feedback (Optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppPrimaryButton(
            label: 'Save Score',
            height: 40,
            onPressed: () {
              final double? enteredScore = double.tryParse(
                scoreCtrl.text.trim(),
              );
              if (enteredScore == null ||
                  enteredScore < 0 ||
                  enteredScore > widget.activity.maxScore) {
                AppModals.showErrorDialog(
                  context: context,
                  title: 'Invalid Score',
                  message:
                      'Please enter a valid numeric score between 0 and ${widget.activity.maxScore.toInt()}.',
                );
                return;
              }

              setState(() {
                MockDatabase.instance.scoreSubmission(
                  submission.id,
                  enteredScore,
                  feedbackCtrl.text.trim(),
                );
              });
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(
                context: context,
                title: 'Score Saved',
                message:
                    'Score of ${enteredScore.toInt()} / ${widget.activity.maxScore.toInt()} saved successfully and released to student portal.',
              );
            },
            width: 170,
          ),
        ],
      ),
    );
  }
}
