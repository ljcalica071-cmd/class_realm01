import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';

class StudentAssessmentScreen extends StatefulWidget {
  final QuizOrExamModel assessment;

  const StudentAssessmentScreen({super.key, required this.assessment});

  static Future<void> start(BuildContext context, QuizOrExamModel assessment) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentAssessmentScreen(assessment: assessment)),
    );
  }

  @override
  State<StudentAssessmentScreen> createState() => _StudentAssessmentScreenState();
}

class _StudentAssessmentScreenState extends State<StudentAssessmentScreen> {
  int _currentStep = 0; // 0: Rules Acknowledgment, 1: Answering Questions, 2: Result Summary
  bool _rulesAccepted = false;
  int _currentQuestionIndex = 0;
  final Map<String, String> _studentAnswers = {};
  int _violations = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var q in widget.assessment.questions) {
      _studentAnswers[q.id] = '';
    }
  }

  void _submitAssessment() {
    // Check if unanswered
    final unansweredCount = _studentAnswers.values.where((a) => a.trim().isEmpty).length;
    if (unansweredCount > 0) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Unanswered Questions',
        message: 'You still have $unansweredCount unanswered question(s). Please review before submitting.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Auto-check against answer key
    double scoreEarned = 0;
    for (var q in widget.assessment.questions) {
      final studentAns = (_studentAnswers[q.id] ?? '').trim().toLowerCase();
      final correctAns = q.correctAnswer.trim().toLowerCase();
      if (studentAns == correctAns) {
        scoreEarned += q.points;
      }
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _currentStep = 2;
      });

      // Store result in MockDatabase
      MockDatabase.instance.assessmentResults.removeWhere((r) => r.assessmentId == widget.assessment.id && r.studentId == 'usr_student_1');
      MockDatabase.instance.assessmentResults.add(
        AssessmentResultModel(
          id: 'res_${DateTime.now().millisecondsSinceEpoch}',
          assessmentId: widget.assessment.id,
          studentId: 'usr_student_1',
          studentName: 'Juan Dela Cruz',
          submittedAt: DateTime.now(),
          durationTakenMinutes: 12,
          violationCount: _violations,
          answers: Map.from(_studentAnswers),
          scoreEarned: scoreEarned,
          totalPoints: widget.assessment.totalPoints,
          isReleased: widget.assessment.resultsReleased,
          needsTeacherReview: widget.assessment.isExam,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment.title),
        backgroundColor: widget.assessment.isExam ? AppColors.error : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                if (_currentStep == 0) _buildRulesView(),
                if (_currentStep == 1) _buildAnsweringView(),
                if (_currentStep == 2) _buildResultView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRulesView() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.assessment.isExam ? Icons.description : Icons.quiz, color: widget.assessment.isExam ? AppColors.error : AppColors.primary, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.assessment.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Subject: ${widget.assessment.subject} • Section: ${widget.assessment.section}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Assessment Rules & Guidelines:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildRuleBullet('Time Limit: ${widget.assessment.durationMinutes} minutes timer.'),
            _buildRuleBullet('Total Questions: ${widget.assessment.questions.length} items (${widget.assessment.totalPoints.toInt()} total points).'),
            _buildRuleBullet('Internet Requirement: Stable connection recommended. Answers are saved locally in real-time.'),
            _buildRuleBullet('Anti-Cheating Policy: Switching tabs or minimizing the browser will be recorded as a violation.'),
            const Spacer(),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I have read and understood the assessment rules and guidelines.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              value: _rulesAccepted,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _rulesAccepted = val ?? false),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.assessment.isExam ? AppColors.error : AppColors.primary,
                ),
                onPressed: _rulesAccepted
                    ? () => setState(() => _currentStep = 1)
                    : null,
                child: const Text('START ASSESSMENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildAnsweringView() {
    final q = widget.assessment.questions[_currentQuestionIndex];
    final totalQ = widget.assessment.questions.length;

    return Expanded(
      child: Column(
        children: [
          // Top Navigation Bar inside assessment
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Question ${_currentQuestionIndex + 1} of $totalQ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text('${widget.assessment.durationMinutes}:00 remaining', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
                    const SizedBox(width: 16),
                    Text('Violations: $_violations', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                  ],
                ),
              ],
            ),
          ),

          // Question Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text('${q.points} Points', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 10),
                      Text(q.type.name.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(q.questionText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 24),

                  // Choices or text input
                  if (q.type == QuestionType.multipleChoice || q.type == QuestionType.trueFalse) ...[
                    ...q.choices.map((choice) {
                      final isSelected = _studentAnswers[q.id] == choice;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                        ),
                        child: RadioListTile<String>(
                          title: Text(choice, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          value: choice,
                          groupValue: _studentAnswers[q.id],
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() => _studentAnswers[q.id] = val ?? '');
                          },
                        ),
                      );
                    }),
                  ] else ...[
                    TextField(
                      controller: TextEditingController(text: _studentAnswers[q.id]),
                      onChanged: (val) => _studentAnswers[q.id] = val,
                      decoration: const InputDecoration(
                        labelText: 'Type your answer here',
                        hintText: 'Enter final solution or answer',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Question Pagination Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous'),
                  onPressed: _currentQuestionIndex > 0 ? () => setState(() => _currentQuestionIndex--) : null,
                ),
                // Number bubbles
                Row(
                  children: List.generate(totalQ, (idx) {
                    final isAnswered = (_studentAnswers[widget.assessment.questions[idx].id] ?? '').trim().isNotEmpty;
                    final isCurrent = idx == _currentQuestionIndex;
                    return InkWell(
                      onTap: () => setState(() => _currentQuestionIndex = idx),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.primary
                              : isAnswered
                                  ? AppColors.successLight
                                  : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : isAnswered ? AppColors.success : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (_currentQuestionIndex < totalQ - 1)
                  AppPrimaryButton(
                    label: 'Next',
                    icon: Icons.arrow_forward,
                    height: 40,
                    width: 110,
                    onPressed: () => setState(() => _currentQuestionIndex++),
                  )
                else
                  AppPrimaryButton(
                    label: _isSubmitting ? 'Submitting...' : 'Submit Assessment',
                    backgroundColor: AppColors.success,
                    height: 40,
                    width: 150,
                    onPressed: _isSubmitting ? null : _submitAssessment,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = MockDatabase.instance.assessmentResults.firstWhere(
      (r) => r.assessmentId == widget.assessment.id && r.studentId == 'usr_student_1',
      orElse: () => AssessmentResultModel(
        id: 'res_empty',
        assessmentId: widget.assessment.id,
        studentId: 'usr_student_1',
        studentName: 'Juan Dela Cruz',
        submittedAt: DateTime.now(),
        durationTakenMinutes: 10,
        answers: {},
        scoreEarned: 18,
        totalPoints: 20,
        isReleased: widget.assessment.resultsReleased,
      ),
    );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 56, color: AppColors.success),
            ),
            const SizedBox(height: 20),
            const Text('Assessment Submitted Successfully!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.assessment.title, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            if (widget.assessment.resultsReleased || result.isReleased) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    Text('Score Obtained: ${result.scoreEarned.toInt()} / ${result.totalPoints.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Text('Percentage: ${result.percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                child: const Text(
                  'Your assessment has been submitted and recorded. Official results and answer breakdowns will be available once the teacher releases the results.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 32),
            AppPrimaryButton(
              label: 'Return to Student Portal',
              onPressed: () => Navigator.of(context).pop(),
              width: 220,
            ),
          ],
        ),
      ),
    );
  }
}
