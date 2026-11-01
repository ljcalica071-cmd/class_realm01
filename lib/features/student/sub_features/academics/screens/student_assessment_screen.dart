import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class StudentAssessmentScreen extends StatefulWidget {
  final QuizOrExamModel assessment;

  const StudentAssessmentScreen({super.key, required this.assessment});

  static Future<void> start(BuildContext context, QuizOrExamModel assessment) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAssessmentScreen(assessment: assessment),
      ),
    );
  }

  @override
  State<StudentAssessmentScreen> createState() =>
      _StudentAssessmentScreenState();
}

class _StudentAssessmentScreenState extends State<StudentAssessmentScreen>
    with WidgetsBindingObserver {
  int _currentStep =
      0; // 0: Rules Acknowledgment, 1: Answering Questions, 2: Result Summary
  bool _rulesAccepted = false;
  int _currentQuestionIndex = 0;
  List<QuestionModel> _orderedQuestions = [];
  final Map<String, String> _studentAnswers = {};
  final Map<String, TextEditingController> _textControllers = {};
  int _violations = 0;
  final List<Map<String, dynamic>> _violationLog = [];
  bool _isSubmitting = false;

  Timer? _timer;
  int _secondsRemaining = 0;
  DateTime? _startTime;
  AssessmentResultModel? _submittedResult;

  TextEditingController _getTextController(String questionId) {
    return _textControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _studentAnswers[questionId] ?? ''),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Deterministically shuffle questions per student strictly within each category
    final studentId = AuthRepository.instance.currentUser?.id ?? 'student';
    final seed = studentId.hashCode ^ widget.assessment.id.hashCode;

    final mcQuestions = widget.assessment.questions
        .where((q) => q.type == QuestionType.multipleChoice)
        .toList()
      ..shuffle(Random(seed));

    final tfQuestions = widget.assessment.questions
        .where((q) => q.type == QuestionType.trueFalse)
        .toList()
      ..shuffle(Random(seed + 1));

    final idQuestions = widget.assessment.questions
        .where((q) => q.type == QuestionType.identification)
        .toList()
      ..shuffle(Random(seed + 2));

    final otherQuestions = widget.assessment.questions
        .where((q) => q.type != QuestionType.multipleChoice &&
                      q.type != QuestionType.trueFalse &&
                      q.type != QuestionType.identification)
        .toList();

    _orderedQuestions = [...mcQuestions, ...tfQuestions, ...idQuestions, ...otherQuestions];

    for (var q in _orderedQuestions) {
      _studentAnswers[q.id] = '';
    }
    _secondsRemaining = widget.assessment.durationMinutes * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentStep == 1 && !_isSubmitting) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        _recordViolation('Tab/window focus lost (Backgrounded)');
      } else if (state == AppLifecycleState.resumed) {
        _recordViolation('Returned to assessment');
      }
    }
  }

  void _startTimer() {
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _submitAssessment(autoSubmit: true);
        }
      });
    });
  }

  void _recordViolation(String event) {
    if (!mounted) return;
    setState(() {
      _violations++;
      _violationLog.add({'time': DateTime.now(), 'event': event});
    });

    // Background audit logging into anti_cheating_logs
    try {
      final user = AuthRepository.instance.currentUser;
      SupabaseService().client.from('anti_cheating_logs').insert({
        'event_type': 'window_focus_lost',
        'details': '$event (Infraction #$_violations)',
        'student_id': user?.id,
        'assessment_id': widget.assessment.id,
        'logged_at': DateTime.now().toIso8601String(),
      }).catchError((_) {});
    } catch (_) {}

    // Strictly informational warning notice - NEVER auto-submit or lock student on violations
    AppModals.showWarningDialog(
      context: context,
      title: 'Proctor Advisory Notice',
      message:
          'Warning: $event.\nLoss of window focus has been recorded (#$_violations) for instructor review. Please remain on the assessment screen.',
    );
  }

  void _submitAssessment({bool autoSubmit = false}) {
    if (_isSubmitting) return;

    if (!autoSubmit) {
      // Find all unanswered questions
      final List<int> unansweredNumbers = [];
      int? firstUnansweredIndex;

      for (int i = 0; i < _orderedQuestions.length; i++) {
        final q = _orderedQuestions[i];
        final ans = (_studentAnswers[q.id] ?? '').trim();
        if (ans.isEmpty) {
          unansweredNumbers.add(i + 1);
          firstUnansweredIndex ??= i;
        }
      }

      if (unansweredNumbers.isNotEmpty) {
        // Automatically jump to the first unanswered question
        if (firstUnansweredIndex != null) {
          setState(() {
            _currentQuestionIndex = firstUnansweredIndex!;
          });
        }

        final itemSummary = unansweredNumbers.length <= 8
            ? 'Item(s): #${unansweredNumbers.join(', #')}'
            : 'Item(s): #${unansweredNumbers.take(8).join(', #')} and ${unansweredNumbers.length - 8} more';

        AppModals.showWarningDialog(
          context: context,
          title: 'Unanswered Questions Remaining',
          message:
              'You cannot submit the examination yet because you have ${unansweredNumbers.length} unanswered question(s).\n\n$itemSummary\n\nPlease answer all questions before submitting. For identification questions where you do not know the answer, you may enter "N/A".',
        );
        return;
      }
    }

    _timer?.cancel();
    setState(() => _isSubmitting = true);

    // Auto-check against answer key (unanswered or N/A answers yield 0 points)
    double scoreEarned = 0;
    for (var q in _orderedQuestions) {
      final studentAns = (_studentAnswers[q.id] ?? '').trim().toLowerCase();
      final correctAns = q.correctAnswer.trim().toLowerCase();
      final isMatching =
          q.type == QuestionType.matching &&
          q.matchingPairs.entries.every(
            (pair) => studentAns.contains(
              '${pair.key.toLowerCase()}=${pair.value.toLowerCase()}',
            ),
          );
      if (studentAns == correctAns || isMatching) {
        scoreEarned += q.points;
      }
    }

    final durationTaken =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMinutes
            : 0;

    final student =
        AuthRepository.instance.currentUser ??
        UserModel(
          id: 'temp_student',
          username: 'student',
          fullName: 'Student',
          email: '',
          role: UserRole.student,
        );

    // Persist attempt record to Supabase (asynchronous)
    try {
      final user = AuthRepository.instance.currentUser;
      final attemptStatus = autoSubmit ? 'auto_submitted' : 'submitted';
      SupabaseService().client.from('assessment_attempts').upsert({
        'assessment_id': widget.assessment.id,
        'student_id': user?.id ?? student.id,
        'attempt_number': 1,
        'status': attemptStatus,
        'started_at': _startTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'submitted_at': DateTime.now().toIso8601String(),
      }).catchError((_) {});
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _currentStep = 2;
    });

    _submittedResult = AssessmentResultModel(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      assessmentId: widget.assessment.id,
      studentId: student.id,
      studentName: student.fullName,
      submittedAt: DateTime.now(),
      durationTakenMinutes: durationTaken,
      violationCount: _violations,
      violationLog: List.from(_violationLog),
      answers: Map.from(_studentAnswers),
      scoreEarned: scoreEarned,
      totalPoints: widget.assessment.totalPoints,
      isReleased: widget.assessment.resultsReleased,
      needsTeacherReview: widget.assessment.isExam,
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment.title),
        backgroundColor:
            widget.assessment.isExam ? AppTheme.catRed : Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: PopScope(
        canPop: _currentStep != 1,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          AppModals.showWarningDialog(
            context: context,
            title: 'Exam In Progress',
            message:
                'You cannot leave the assessment while the exam timer is actively running. Please complete or submit your examination.',
          );
        },
        child: Stack(
          children: [
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
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
          ],
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
                Icon(
                  widget.assessment.isExam ? Icons.description : Icons.quiz,
                  color:
                      widget.assessment.isExam
                          ? AppTheme.catRed
                          : Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assessment.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Subject: ${widget.assessment.subject} • Section: ${widget.assessment.section}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Assessment Rules & Guidelines:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRuleBullet(
              'Time Limit: ${widget.assessment.durationMinutes} minutes timer.',
            ),
            _buildRuleBullet(
              'Total Questions: ${_orderedQuestions.length} items (${widget.assessment.totalPoints.toInt()} total points).',
            ),
            _buildRuleBullet(
              'Mandatory Answers: Blank questions cannot be submitted manually. For identification questions where you do not know the answer, please enter "N/A".',
            ),
            _buildRuleBullet(
              'Internet Requirement: Active internet connection required throughout the assessment.',
            ),
            _buildRuleBullet(
              'Anti-Cheating Policy: Switching tabs or minimizing the browser will be recorded as a violation for teacher review.',
            ),
            const Spacer(),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I have read and understood the assessment rules and guidelines.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              value: _rulesAccepted,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) => setState(() => _rulesAccepted = val ?? false),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.assessment.isExam
                          ? AppTheme.catRed
                          : Theme.of(context).colorScheme.primary,
                ),
                onPressed:
                    _rulesAccepted
                        ? () {
                          setState(() => _currentStep = 1);
                          _startTimer();
                        }
                        : null,
                child: const Text(
                  'START ASSESSMENT',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
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
          Icon(Icons.arrow_right, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnsweringView() {
    final q = _orderedQuestions[_currentQuestionIndex];
    final totalQ = _orderedQuestions.length;
    final answeredCount = _orderedQuestions
        .where((item) => (_studentAnswers[item.id] ?? '').trim().isNotEmpty)
        .length;

    return Expanded(
      child: Column(
        children: [
          // Top Navigation Bar inside assessment
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of $totalQ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            answeredCount == totalQ
                                ? AppTheme.catGreen.withValues(alpha: 0.12)
                                : AppTheme.catOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$answeredCount / $totalQ answered',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              answeredCount == totalQ
                                  ? AppTheme.catGreen
                                  : AppTheme.catOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: AppTheme.catOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatTime(_secondsRemaining)} remaining',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.catOrange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Violations: $_violations',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.catRed,
                      ),
                    ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${q.points} Points',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        q.type.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text(
                          'Simulate: Copy attempt detected',
                          style: TextStyle(fontSize: 10),
                        ),
                        onPressed: () => _recordViolation('Copy attempt detected'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q.questionText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Choices or text input
                  if (q.type == QuestionType.multipleChoice ||
                      q.type == QuestionType.trueFalse) ...[
                    ...q.choices.map((choice) {
                      final isSelected = _studentAnswers[q.id] == choice;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                                  : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          title: Text(
                            choice,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          value: choice,
                          groupValue: _studentAnswers[q.id],
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setState(() => _studentAnswers[q.id] = val ?? '');
                          },
                        ),
                      );
                    }),
                  ] else if (q.type == QuestionType.matching) ...[
                    Column(
                      children:
                          q.matchingPairs.keys.map((left) {
                            final options = q.matchingPairs.values.toList();
                            final current = _studentAnswers[q.id]
                                ?.split('|')
                                .firstWhere(
                                  (entry) => entry.startsWith('$left='),
                                  orElse: () => '',
                                )
                                .split('=')
                                .skip(1)
                                .join('=');
                            return DropdownButtonFormField<String>(
                              initialValue:
                                  options.contains(current) ? current : null,
                              decoration: InputDecoration(labelText: left),
                              items:
                                  options
                                      .map(
                                        (option) => DropdownMenuItem(
                                          value: option,
                                          child: Text(option),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                final answers = (_studentAnswers[q.id] ?? '')
                                    .split('|')
                                    .where(
                                      (entry) =>
                                          entry.isNotEmpty &&
                                          !entry.startsWith('$left='),
                                    )
                                    .toList();
                                answers.add('$left=$value');
                                setState(
                                  () => _studentAnswers[q.id] = answers.join('|'),
                                );
                              },
                            );
                          }).toList(),
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Answer:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                final ctrl = _getTextController(q.id);
                                ctrl.text = 'N/A';
                                ctrl.selection = TextSelection.fromPosition(
                                  const TextPosition(offset: 3),
                                );
                                setState(() => _studentAnswers[q.id] = 'N/A');
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.not_interested,
                                      size: 13,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Insert 'N/A' (I don't know)",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context)
                                                .colorScheme
                                                .primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _getTextController(q.id),
                          onChanged: (val) {
                            setState(() => _studentAnswers[q.id] = val);
                          },
                          decoration: InputDecoration(
                            labelText: 'Type your answer here',
                            hintText: "Enter answer (or type 'N/A' if unknown)",
                            helperText:
                                "Required: Blank answers are prohibited on submission. If you do not know the answer, enter 'N/A'.",
                            helperMaxLines: 2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Question Pagination Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous'),
                  onPressed:
                      _currentQuestionIndex > 0
                          ? () => setState(() => _currentQuestionIndex--)
                          : null,
                ),
                // Number bubbles
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalQ, (idx) {
                        final isAnswered =
                            (_studentAnswers[_orderedQuestions[idx].id] ?? '')
                                .trim()
                                .isNotEmpty;
                        final isCurrent = idx == _currentQuestionIndex;
                        return InkWell(
                          onTap: () => setState(() => _currentQuestionIndex = idx),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  isCurrent
                                      ? Theme.of(context).colorScheme.primary
                                      : isAnswered
                                      ? AppTheme.catGreen.withValues(alpha: 0.12)
                                      : Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isCurrent
                                        ? Theme.of(context).colorScheme.primary
                                        : isAnswered
                                        ? AppTheme.catGreen
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.2),
                                width: isCurrent || isAnswered ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color:
                                    isCurrent
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : isAnswered
                                        ? AppTheme.catGreen
                                        : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                    backgroundColor:
                        answeredCount == totalQ
                            ? AppTheme.catGreen
                            : AppTheme.catOrange,
                    icon:
                        answeredCount == totalQ
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                    height: 40,
                    width: 180,
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => _submitAssessment(autoSubmit: false),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final student =
        AuthRepository.instance.currentUser ??
        UserModel(
          id: 'temp_student',
          username: 'student',
          fullName: 'Student',
          email: '',
          role: UserRole.student,
        );
    final result =
        _submittedResult ??
        AssessmentResultModel(
          id: 'res_empty',
          assessmentId: widget.assessment.id,
          studentId: student.id,
          studentName: student.fullName,
          submittedAt: DateTime.now(),
          durationTakenMinutes: 10,
          answers: {},
          scoreEarned: 0,
          totalPoints: widget.assessment.totalPoints,
          isReleased: widget.assessment.resultsReleased,
        );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.catGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 56,
                color: AppTheme.catGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Assessment Submitted Successfully!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.assessment.title,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            if (widget.assessment.resultsReleased || result.isReleased) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Score Obtained: ${result.scoreEarned.toInt()} / ${result.totalPoints.toInt()}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Percentage: ${result.percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.catGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.catOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.catOrange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Your assessment has been submitted and recorded. Official results and answer breakdowns will be available once the teacher releases the results.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, height: 1.4),
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
