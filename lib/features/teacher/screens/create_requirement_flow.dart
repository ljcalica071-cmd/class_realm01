import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';
import '../../../widgets/common/app_text_field.dart';

class CreateRequirementFlowDialog extends StatefulWidget {
  final VoidCallback onRequirementCreated;

  const CreateRequirementFlowDialog({
    super.key,
    required this.onRequirementCreated,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onRequirementCreated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateRequirementFlowDialog(onRequirementCreated: onRequirementCreated),
    );
  }

  @override
  State<CreateRequirementFlowDialog> createState() => _CreateRequirementFlowDialogState();
}

class _CreateRequirementFlowDialogState extends State<CreateRequirementFlowDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _maxScoreCtrl = TextEditingController(text: '100');
  final _sectionCtrl = TextEditingController(text: '11-STEM A');
  SubmissionType _submissionType = SubmissionType.fileAndText;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _instructionsCtrl.dispose();
    _maxScoreCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _saveRequirement() {
    if (_titleCtrl.text.trim().isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Requirement Title Required',
        message: 'Please enter a valid title for this performance task or requirement.',
      );
      return;
    }

    final maxScore = double.tryParse(_maxScoreCtrl.text.trim()) ?? 100.0;

    final newReq = ActivityModel(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim(),
      subject: 'General Mathematics',
      gradeLevel: 'Grade 11',
      section: _sectionCtrl.text.trim(),
      deadline: _deadline,
      maxScore: maxScore,
      isPublished: true,
      isRequirement: true, // Marked as Requirement / Performance Task
      submissionType: _submissionType,
      attachmentName: 'Performance_Task_Rubric.pdf',
    );

    MockDatabase.instance.addActivity(newReq);
    widget.onRequirementCreated();
    Navigator.of(context).pop();

    AppModals.showSuccessDialog(
      context: context,
      title: 'Requirement Published',
      message: 'Performance task "${newReq.title}" has been successfully published to ${_sectionReqText(newReq.section)}.',
    );
  }

  String _sectionReqText(String section) => section;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Requirement / Performance Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('Assign graded performance tasks or requirements to Senior High School sections', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'Requirement / Performance Task Title',
                      hint: 'e.g. Mathematical Modeling Portfolio',
                      controller: _titleCtrl,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            label: 'Assigned Section',
                            hint: '11-STEM A',
                            controller: _sectionCtrl,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: AppTextField(
                            label: 'Total Points',
                            hint: '100',
                            controller: _maxScoreCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Short Description',
                      hint: 'Brief overview of the requirement',
                      controller: _descCtrl,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Detailed Instructions & Rubrics',
                      hint: 'Provide step-by-step instructions for students...',
                      controller: _instructionsCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    const Text('Submission Type:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<SubmissionType>(
                      value: _submissionType,
                      items: const [
                        DropdownMenuItem(value: SubmissionType.fileAndText, child: Text('File Attachment & Text Submission')),
                        DropdownMenuItem(value: SubmissionType.fileOnly, child: Text('File Attachment Only (.pdf, .docx)')),
                        DropdownMenuItem(value: SubmissionType.textOnly, child: Text('Text Submission Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _submissionType = val);
                      },
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.border)),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  AppPrimaryButton(
                    label: 'Publish Requirement',
                    icon: Icons.publish,
                    height: 40,
                    onPressed: _saveRequirement,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
