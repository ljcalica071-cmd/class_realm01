import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';
import '../../../widgets/common/app_text_field.dart';

class CreateAssessmentFlowDialog extends StatefulWidget {
  final VoidCallback onAssessmentCreated;

  const CreateAssessmentFlowDialog({
    super.key,
    required this.onAssessmentCreated,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onAssessmentCreated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateAssessmentFlowDialog(onAssessmentCreated: onAssessmentCreated),
    );
  }

  @override
  State<CreateAssessmentFlowDialog> createState() => _CreateAssessmentFlowDialogState();
}

class _CreateAssessmentFlowDialogState extends State<CreateAssessmentFlowDialog> {
  // Steps:
  // 0: Selection of Assessment Type (Quiz vs Periodical Examination)
  // 1: Configure & Add Questions / Details
  int _currentStep = 0;
  bool _isExam = false;
  String _examCategory = 'ST1';

  // Form Fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');
  final _sectionCtrl = TextEditingController(text: 'STEM 11-A');
  final _gradingQuarterCtrl = TextEditingController(text: '1st Quarter');
  DateTime _scheduleDate = DateTime.now().add(const Duration(days: 2));

  // Questions Builder
  final List<QuestionModel> _questions = [];
  final _qTextCtrl = TextEditingController();
  final _qCorrectAnswerCtrl = TextEditingController();
  final _qPointsCtrl = TextEditingController(text: '5.0');
  QuestionType _selectedQType = QuestionType.multipleChoice;

  // Options for multiple choice
  final _choiceACtrl = TextEditingController();
  final _choiceBCtrl = TextEditingController();
  final _choiceCCtrl = TextEditingController();
  final _choiceDCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _sectionCtrl.dispose();
    _gradingQuarterCtrl.dispose();
    _qTextCtrl.dispose();
    _qCorrectAnswerCtrl.dispose();
    _qPointsCtrl.dispose();
    _choiceACtrl.dispose();
    _choiceBCtrl.dispose();
    _choiceCCtrl.dispose();
    _choiceDCtrl.dispose();
    super.dispose();
  }

  void _selectAssessmentType(bool isExam) {
    setState(() {
      _isExam = isExam;
      _currentStep = 1;
      _durationCtrl.text = isExam ? '60' : '30';
      if (_isExam) {
        _titleCtrl.text = 'Summative Test 1';
        _descCtrl.text = 'Comprehensive examination covering General Mathematics core competencies.';
      } else {
        _titleCtrl.text = 'Quiz: Rational Functions & Domain/Range';
        _descCtrl.text = 'Formative quiz on composite functions and asymptote evaluations.';
      }
    });
  }

  void _addQuestionToList() {
    if (_qTextCtrl.text.trim().isEmpty || _qCorrectAnswerCtrl.text.trim().isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Incomplete Question',
        message: 'Please provide question text and the correct answer before adding.',
      );
      return;
    }

    final double points = double.tryParse(_qPointsCtrl.text.trim()) ?? 5.0;
    List<String> choices = [];

    if (_selectedQType == QuestionType.multipleChoice) {
      choices = [
        _choiceACtrl.text.trim().isEmpty ? 'Option A' : _choiceACtrl.text.trim(),
        _choiceBCtrl.text.trim().isEmpty ? 'Option B' : _choiceBCtrl.text.trim(),
        _choiceCCtrl.text.trim().isEmpty ? 'Option C' : _choiceCCtrl.text.trim(),
        _choiceDCtrl.text.trim().isEmpty ? 'Option D' : _choiceDCtrl.text.trim(),
      ];
    } else if (_selectedQType == QuestionType.trueFalse) {
      choices = ['True', 'False'];
    }

    setState(() {
      _questions.add(
        QuestionModel(
          id: 'q_${DateTime.now().millisecondsSinceEpoch}',
          questionText: _qTextCtrl.text.trim(),
          type: _selectedQType,
          choices: choices,
          correctAnswer: _qCorrectAnswerCtrl.text.trim(),
          points: points,
        ),
      );

      // Clear question builder fields
      _qTextCtrl.clear();
      _qCorrectAnswerCtrl.clear();
      _choiceACtrl.clear();
      _choiceBCtrl.clear();
      _choiceCCtrl.clear();
      _choiceDCtrl.clear();
    });
  }

  void _saveAssessment() {
    if (_titleCtrl.text.trim().isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Title Required',
        message: 'Please provide a valid title for this assessment.',
      );
      return;
    }

    // If no questions added manually, generate a default sample question
    if (_questions.isEmpty) {
      _questions.add(
        QuestionModel(
          id: 'q_default_1',
          questionText: 'Which function represents exponential growth?',
          type: QuestionType.multipleChoice,
          choices: ['f(x) = 2(3)^x', 'f(x) = 2(0.5)^x', 'f(x) = 2x - 5', 'f(x) = 1/x'],
          correctAnswer: 'f(x) = 2(3)^x',
          points: _isExam ? 10.0 : 5.0,
        ),
      );
    }

    final int duration = int.tryParse(_durationCtrl.text.trim()) ?? (_isExam ? 60 : 30);

    final newAssessment = QuizOrExamModel(
      id: '${_isExam ? "exam" : "quiz"}_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      subject: 'General Mathematics',
      section: _sectionCtrl.text.trim(),
      isExam: _isExam,
      durationMinutes: duration,
      scheduleDate: _scheduleDate,
      isPublished: true,
      questions: List.from(_questions),
    );

    MockDatabase.instance.addQuizOrExam(newAssessment);
    widget.onAssessmentCreated();
    Navigator.of(context).pop();

    AppModals.showSuccessDialog(
      context: context,
      title: _isExam ? 'Periodical Examination Published' : 'Quiz Assessment Published',
      message: '${newAssessment.title} has been configured and published for ${newAssessment.section}. Duration: $duration mins, Total Points: ${newAssessment.totalPoints.toInt()} pts.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          children: [
            // Header bar
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
                      color: _isExam ? AppColors.errorLight : AppColors.infoLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isExam ? Icons.description_outlined : Icons.quiz_outlined,
                      color: _isExam ? AppColors.error : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStep == 0
                              ? 'Create New Assessment'
                              : _isExam
                                  ? 'Configure Periodical Examination'
                                  : 'Configure Unit Quiz',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          _currentStep == 0
                              ? 'Choose the assessment category for Senior High School'
                              : 'Step 2: Define examination schedule, duration, and question items',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
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

            // Content Body
            Expanded(
              child: _currentStep == 0 ? _buildTypeSelectionView() : _buildConfigurationFormView(),
            ),

            // Footer / Bottom Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.border)),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep == 1)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Type Selection'),
                      onPressed: () => setState(() => _currentStep = 0),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep == 1)
                        AppPrimaryButton(
                          label: _isExam ? 'Publish Periodical Exam' : 'Publish Unit Quiz',
                          icon: Icons.check_circle_outline,
                          height: 42,
                          backgroundColor: _isExam ? AppColors.error : AppColors.primary,
                          onPressed: _saveAssessment,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 0: TYPE SELECTION (QUIZ VS EXAM)
  // ==========================================
  Widget _buildTypeSelectionView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Assessment Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quizzes and Examinations follow distinct academic grading weights and timing rules.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          Expanded(
            child: Row(
              children: [
                // Option 1: UNIT QUIZ
                Expanded(
                  child: _buildTypeCard(
                    title: 'Unit / Formative Quiz',
                    badge: 'FORMATIVE (15-20% WEIGHT)',
                    badgeColor: AppColors.infoLight,
                    badgeTextColor: AppColors.info,
                    description:
                        'Short assessment to evaluate student mastery of specific mathematical competencies, piecewise functions, or subtopics.',
                    icon: Icons.quiz_outlined,
                    iconColor: AppColors.primary,
                    iconBgColor: const Color(0xFFEFF6FF),
                    features: [
                      'Typical duration: 15 - 45 mins',
                      'Rapid formative feedback',
                      'Multiple choice & short identification',
                      'Immediate or scheduled score release',
                    ],
                    onTap: () => _selectAssessmentType(false),
                  ),
                ),
                const SizedBox(width: 24),

                // Option 2: PERIODICAL EXAMINATION
                Expanded(
                  child: _buildTypeCard(
                    title: 'Quarterly Periodical Examination',
                    badge: 'SUMMATIVE (30-40% WEIGHT)',
                    badgeColor: AppColors.errorLight,
                    badgeTextColor: AppColors.error,
                    description:
                        'Official institutional quarterly or midterm examination. Integrated with answer keys, auto-checking, and item analysis.',
                    icon: Icons.description_outlined,
                    iconColor: AppColors.error,
                    iconBgColor: const Color(0xFFFEF2F2),
                    features: [
                      'Typical duration: 60 - 120 mins',
                      'Requires official schedule date',
                      'Automated answer key matching',
                      'Item Analysis difficulty index generation',
                    ],
                    onTap: () => _selectAssessmentType(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    badge,
                    style: TextStyle(color: badgeTextColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: iconColor,
                  side: BorderSide(color: iconColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: onTap,
                child: Text('Create ${title.split(" ")[0]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1: CONFIGURE ASSESSMENT & QUESTIONS
  // ==========================================
  Widget _buildConfigurationFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isExam) ...[
            DropdownButtonFormField<String>(
              initialValue: _examCategory,
              decoration: const InputDecoration(
                labelText: 'Exam Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'ST1', child: Text('Summative Test 1 (ST1)')),
                DropdownMenuItem(value: 'ST2', child: Text('Summative Test 2 (ST2)')),
                DropdownMenuItem(value: 'TE', child: Text('Term Examination (TE)')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _examCategory = value;
                  _titleCtrl.text = switch (value) {
                    'ST2' => 'Summative Test 2',
                    'TE' => 'Term Examination',
                    _ => 'Summative Test 1',
                  };
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          // Basic Info
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: _isExam ? 'Periodical Examination Title' : 'Quiz Title',
                  controller: _titleCtrl,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: AppTextField(
                  label: 'Duration (Minutes)',
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: AppTextField(
                  label: 'Target Section',
                  controller: _sectionCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Instructions & Guidelines',
            controller: _descCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Examination Answer Key & Question Builder Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isExam ? 'Answer Key & Question Items Setup' : 'Quiz Questions Builder',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Added: ${_questions.length} question(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question Type Selector
                Row(
                  children: [
                    const Text('Question Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    DropdownButton<QuestionType>(
                      value: _selectedQType,
                      items: QuestionType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedQType = val);
                      },
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _qPointsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Points', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question Text
                TextField(
                  controller: _qTextCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Enter Question Statement',
                    hintText: 'e.g. Find the horizontal asymptote of f(x) = (3x + 1) / (2x - 5)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Multiple choice options if type is multiple choice
                if (_selectedQType == QuestionType.multipleChoice) ...[
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _choiceACtrl, decoration: const InputDecoration(labelText: 'Choice A', isDense: true))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _choiceBCtrl, decoration: const InputDecoration(labelText: 'Choice B', isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _choiceCCtrl, decoration: const InputDecoration(labelText: 'Choice C', isDense: true))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _choiceDCtrl, decoration: const InputDecoration(labelText: 'Choice D', isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Answer Key / Correct Answer field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qCorrectAnswerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Official Correct Answer (Auto-Checker Key)',
                          hintText: 'e.g. y = 3/2 or Option A or True',
                          isDense: true,
                          prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    AppPrimaryButton(
                      label: 'Add to List',
                      icon: Icons.add,
                      height: 42,
                      width: 130,
                      onPressed: _addQuestionToList,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Render List of Questions Added
          if (_questions.isNotEmpty) ...[
            const Text('Configured Questions & Answer Keys:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ..._questions.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final q = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary,
                      child: Text('$idx', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Type: ${q.type.name.toUpperCase()} • Key: "${q.correctAnswer}" • Points: ${q.points}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () {
                        setState(() => _questions.removeAt(entry.key));
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
