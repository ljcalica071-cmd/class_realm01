import 'package:flutter/material.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class GenerateLessonPlanModal extends StatefulWidget {
  final Function(String subject, String topic, String gradeLevel, String duration) onGenerate;

  const GenerateLessonPlanModal({super.key, required this.onGenerate});

  @override
  State<GenerateLessonPlanModal> createState() => _GenerateLessonPlanModalState();
}

class _GenerateLessonPlanModalState extends State<GenerateLessonPlanModal> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate iLAW Lesson Plan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Let Gemini AI assist you in structuring your lesson plan.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject (e.g., General Math)'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _topicCtrl,
              decoration: const InputDecoration(labelText: 'Topic (e.g., Functions)'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gradeCtrl,
                    decoration: const InputDecoration(labelText: 'Grade Level (e.g., Grade 11)'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _durationCtrl,
                    decoration: const InputDecoration(labelText: 'Duration (e.g., 60 mins)'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: _isGenerating ? 'Generating...' : 'Generate with Gemini AI',
                icon: Icons.auto_awesome,
                isLoading: _isGenerating,
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _isGenerating = true);
                    await widget.onGenerate(
                      _subjectCtrl.text,
                      _topicCtrl.text,
                      _gradeCtrl.text,
                      _durationCtrl.text,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
