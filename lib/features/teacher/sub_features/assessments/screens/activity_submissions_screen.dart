import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/status_badge.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';

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
    final sections = [
      'All Sections',
      ...widget.activity.assignedSections.where((s) => s.isNotEmpty).toSet(),
    ];
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
      color: Theme.of(context).scaffoldBackgroundColor,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subject: ${widget.activity.subject} • Sections: ${widget.activity.section}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${allStudents.length - statusCounts['Unsubmitted']!}/${allStudents.length} submitted  •  ${statusCounts['Graded']} graded  •  ${statusCounts['Pending']} pending  •  ${statusCounts['Unsubmitted']} unsubmitted',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
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
                  Text(
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
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
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
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        student.fullName.substring(0, 1),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
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
                                  ? AppTheme.catGreen.withValues(alpha: 0.1)
                                  : AppTheme.catRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${submission.score!.toInt()} / ${widget.activity.maxScore.toInt()}',
                              style: TextStyle(
                                color:
                                    submission.score! >=
                                        widget.activity.maxScore * 0.76
                                    ? AppTheme.catGreen
                                    : AppTheme.catRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          StatusBadge(
                            text: _statusText(submission),
                            backgroundColor: submission.attachedFile == null
                                ? Theme.of(context).scaffoldBackgroundColor
                                : AppTheme.catOrange.withValues(alpha: 0.1),
                            textColor: submission.attachedFile == null
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                : AppTheme.catOrange,
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.schedule, size: 15),
                          label: const Text('Reschedule'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _showRescheduleDialog(context, student.fullName),
                        ),
                        const SizedBox(width: 8),
                        AppPrimaryButton(
                          label: 'View',
                          height: 36,
                          width: 100,
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
      color: Theme.of(context).colorScheme.primary,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
          ),
          Text(
            'For Performance Task Submissions: ${widget.activity.title}',
            style: TextStyle(
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
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: AppTheme.catRed,
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student Work File',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            submission.attachedFile ?? 'No file submitted yet',
                          ),
                          if (submission.attachedFile != null)
                            TextButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.open_in_new),
                              label: Text('Open file'),
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
            child: Text('Cancel'),
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

              // Synchronize score directly to Gradebook sheet
              if (widget.activity.subjectOfferingId != null &&
                  widget.activity.subjectOfferingId!.isNotEmpty) {
                final offeringId = widget.activity.subjectOfferingId!;
                final catKey = widget.activity.isRequirement ? 'pt' : 'ww';
                SubjectRepository.instance.getGradebookTermSheet(offeringId, 1).then((termSheet) {
                  final sheet = Map<String, dynamic>.from(termSheet ?? {});
                  final scores = Map<String, dynamic>.from(sheet['scores'] as Map? ?? {});
                  final studentScores = Map<String, dynamic>.from(scores[submission.studentId] as Map? ?? {});
                  final catScores = Map<String, dynamic>.from(studentScores[catKey] as Map? ?? {});
                  
                  // Use first column if not yet assigned
                  catScores['1'] = enteredScore;
                  studentScores[catKey] = catScores;
                  scores[submission.studentId] = studentScores;
                  sheet['scores'] = scores;

                  SubjectRepository.instance.saveGradebookTermSheet(offeringId, 1, sheet);
                }).catchError((e) {
                  debugPrint('Gradebook score sync notice: $e');
                });
              }

              Navigator.pop(ctx);
              AppModals.showSuccessDialog(
                context: context,
                title: 'Score Saved',
                message:
                    'Score of ${enteredScore.toInt()} / ${widget.activity.maxScore.toInt()} saved successfully and synchronized with Gradebook.',
              );
            },
            width: 170,
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(BuildContext context, String studentName) {
    DateTime newDeadline = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Reschedule Deadline', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a special make-up deadline for $studentName:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: newDeadline,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(newDeadline),
                    );
                    if (pickedTime != null) {
                      setModalState(() {
                        newDeadline = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${newDeadline.month}/${newDeadline.day}/${newDeadline.year} ${newDeadline.hour > 12 ? newDeadline.hour - 12 : newDeadline.hour}:${newDeadline.minute.toString().padLeft(2, '0')} ${newDeadline.hour >= 12 ? 'PM' : 'AM'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Icon(Icons.calendar_month, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This will open the submission window exclusively for this student without reopening for the whole class.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Special deadline granted to $studentName until ${_formatSubmittedAt(newDeadline)}.'),
                    backgroundColor: const Color(0xFF0F8A48),
                  ),
                );
              },
              child: const Text('Apply Reschedule'),
            ),
          ],
        ),
      ),
    );
  }
}
