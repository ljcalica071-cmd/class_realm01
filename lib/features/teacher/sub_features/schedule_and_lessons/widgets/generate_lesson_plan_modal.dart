import 'package:flutter/material.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/ilaw_lesson_plan_validator.dart';

class GenerateLessonPlanModal extends StatefulWidget {
  final Future<void> Function(
    String subject,
    String topic,
    String gradeLevel,
    String duration,
  ) onGenerate;

  const GenerateLessonPlanModal({super.key, required this.onGenerate});

  @override
  State<GenerateLessonPlanModal> createState() =>
      _GenerateLessonPlanModalState();
}

class _GenerateLessonPlanModalState extends State<GenerateLessonPlanModal> {
  static const Color _errorRed = Color(0xFFDC2626);

  final _subjectCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController(text: 'Grade 11');
  final _durationCtrl = TextEditingController(text: '60');

  String? _subjectError;
  String? _topicError;
  String? _gradeError;
  String? _durationError;
  bool _isGenerating = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _topicCtrl.dispose();
    _gradeCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final sErr = IlawLessonPlanValidator.validateSubject(_subjectCtrl.text);
    final tErr = IlawLessonPlanValidator.validateTopic(_topicCtrl.text);
    final gErr = IlawLessonPlanValidator.validateGradeLevel(_gradeCtrl.text);
    final dErr = IlawLessonPlanValidator.validateDuration(_durationCtrl.text);

    setState(() {
      _subjectError = sErr;
      _topicError = tErr;
      _gradeError = gErr;
      _durationError = dErr;
    });

    return sErr == null && tErr == null && gErr == null && dErr == null;
  }

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
            'Let Gemini AI assist you in structuring your SHS lesson plan.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _buildField(
            theme: theme,
            label: 'Subject',
            hint: 'e.g., General Mathematics',
            controller: _subjectCtrl,
            errorText: _subjectError,
            onChanged: () {
              if (_subjectError != null) setState(() => _subjectError = null);
            },
          ),
          const SizedBox(height: 14),
          _buildField(
            theme: theme,
            label: 'Topic',
            hint: 'e.g., Rational Functions',
            controller: _topicCtrl,
            errorText: _topicError,
            onChanged: () {
              if (_topicError != null) setState(() => _topicError = null);
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(
                  theme: theme,
                  label: 'SHS Grade Level',
                  hint: 'Grade 11 or Grade 12',
                  controller: _gradeCtrl,
                  errorText: _gradeError,
                  onChanged: () {
                    if (_gradeError != null) setState(() => _gradeError = null);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildField(
                  theme: theme,
                  label: 'Duration (Minutes)',
                  hint: '60',
                  controller: _durationCtrl,
                  errorText: _durationError,
                  onChanged: () {
                    if (_durationError != null) {
                      setState(() => _durationError = null);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              label: _isGenerating ? 'Generating...' : 'Generate with Gemini AI',
              icon: Icons.auto_awesome,
              isLoading: _isGenerating,
              onPressed: _isGenerating
                  ? null
                  : () async {
                      if (!_validate()) return;
                      setState(() => _isGenerating = true);
                      await widget.onGenerate(
                        _subjectCtrl.text.trim(),
                        _topicCtrl.text.trim(),
                        _gradeCtrl.text.trim(),
                        _durationCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildField({
    required ThemeData theme,
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? errorText,
    required VoidCallback onChanged,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: hint,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError
                    ? _errorRed
                    : theme.colorScheme.onSurface.withValues(alpha: 0.16),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? _errorRed : theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 14, color: _errorRed),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText,
                  style: const TextStyle(
                    color: _errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
