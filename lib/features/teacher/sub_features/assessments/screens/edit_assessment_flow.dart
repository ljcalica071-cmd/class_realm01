import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';

class EditAssessmentFlowDialog extends StatefulWidget {
  final QuizOrExamModel assessment;
  final VoidCallback onAssessmentUpdated;

  const EditAssessmentFlowDialog({
    super.key,
    required this.assessment,
    required this.onAssessmentUpdated,
  });

  static Future<void> show(BuildContext context, {required QuizOrExamModel assessment, required VoidCallback onAssessmentUpdated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditAssessmentFlowDialog(assessment: assessment, onAssessmentUpdated: onAssessmentUpdated),
    );
  }

  @override
  State<EditAssessmentFlowDialog> createState() => _EditAssessmentFlowDialogState();
}

class _EditAssessmentFlowDialogState extends State<EditAssessmentFlowDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _sectionCtrl;
  late List<QuestionModel> _questions;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.assessment.title);
    _descCtrl = TextEditingController(text: widget.assessment.description);
    _durationCtrl = TextEditingController(text: widget.assessment.durationMinutes.toString());
    _sectionCtrl = TextEditingController(text: widget.assessment.section);
    _questions = List.from(widget.assessment.questions);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (_titleCtrl.text.trim().isEmpty) {
      AppModals.showErrorDialog(context: context, title: 'Title Required', message: 'Please provide a valid assessment title.');
      return;
    }

    final duration = int.tryParse(_durationCtrl.text.trim()) ?? widget.assessment.durationMinutes;

    final updated = widget.assessment.copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      durationMinutes: duration,
      section: _sectionCtrl.text.trim(),
      questions: _questions,
    );

    // Update in MockDatabase list
    final idx = MockDatabase.instance.quizzesAndExams.indexWhere((q) => q.id == updated.id);
    if (idx != -1) {
      MockDatabase.instance.quizzesAndExams[idx] = updated;
    }

    widget.onAssessmentUpdated();
    Navigator.of(context).pop();

    AppModals.showSuccessDialog(
      context: context,
      title: 'Assessment Updated',
      message: 'Changes to "${updated.title}" have been successfully saved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 750,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)))),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit ${widget.assessment.isExam ? "Periodical Examination" : "Unit Quiz"}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Modify details, instructions, or question items', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 3, child: AppTextField(label: 'Assessment Title', controller: _titleCtrl)),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: AppTextField(label: 'Duration (Mins)', controller: _durationCtrl, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: AppTextField(label: 'Section', controller: _sectionCtrl)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(label: 'Description / Instructions', controller: _descCtrl, maxLines: 2),
                    const SizedBox(height: 24),
                    Text('Questions & Answer Keys (${_questions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    ..._questions.asMap().entries.map((entry) {
                      final i = entry.key + 1;
                      final q = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 12, backgroundColor: Theme.of(context).colorScheme.primary, child: Text('$i', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(q.questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Text('Key: ${q.correctAnswer} (${q.points} pts)', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  AppPrimaryButton(label: 'Save Changes', height: 40, onPressed: _saveChanges),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
