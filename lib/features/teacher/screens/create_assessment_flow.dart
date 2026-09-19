import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';
import '../../../widgets/common/app_text_field.dart';

class CreateAssessmentFlowDialog extends StatefulWidget {
  final VoidCallback onAssessmentCreated;
  final String initialSection;
  final bool initialIsExam;
  final bool skipTypeSelection;

  const CreateAssessmentFlowDialog({
    super.key,
    required this.onAssessmentCreated,
    this.initialSection = 'Section A',
    this.initialIsExam = false,
    this.skipTypeSelection = false,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAssessmentCreated,
    String initialSection = 'Section A',
    bool initialIsExam = false,
    bool skipTypeSelection = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateAssessmentFlowDialog(
        onAssessmentCreated: onAssessmentCreated,
        initialSection: initialSection,
        initialIsExam: initialIsExam,
        skipTypeSelection: skipTypeSelection,
      ),
    );
  }

  @override
  State<CreateAssessmentFlowDialog> createState() =>
      _CreateAssessmentFlowDialogState();
}

class _CreateAssessmentFlowDialogState
    extends State<CreateAssessmentFlowDialog> {
  // Steps:
  // 0: Selection of Assessment Type (Quiz vs Periodical Examination)
  // 1: Configure & Add Questions / Details
  int _currentStep = 0;
  bool _isExam = false;
  String _examCategory = 'ST1';
  final Map<QuestionType, int> _questionCounts = {
    QuestionType.multipleChoice: 0,
    QuestionType.trueFalse: 0,
    QuestionType.matching: 0,
    QuestionType.identification: 0,
  };
  final _matchingLeftCtrl = TextEditingController();
  final _matchingRightCtrl = TextEditingController();
  final Map<QuestionType, TextEditingController> _questionCountCtrls = {
    QuestionType.multipleChoice: TextEditingController(),
    QuestionType.trueFalse: TextEditingController(),
    QuestionType.matching: TextEditingController(),
    QuestionType.identification: TextEditingController(),
  };
  final Map<String, String> _matchingPairs = {};

  // Form Fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');
  final _gradingQuarterCtrl = TextEditingController(text: '1st Quarter');
  DateTime _scheduleDate = DateTime.now().add(const Duration(days: 2));
  final Set<String> _selectedSections = {'Section A'};
  final Map<String, DateTime> _sectionDeadlines = {};

  // Questions Builder
  final List<QuestionModel> _questions = [];
  final _qTextCtrl = TextEditingController();
  final _qCorrectAnswerCtrl = TextEditingController();
  final _qPointsCtrl = TextEditingController(text: '1');
  QuestionType _selectedQType = QuestionType.multipleChoice;

  // Options for multiple choice
  final _choiceACtrl = TextEditingController();
  final _choiceBCtrl = TextEditingController();
  final _choiceCCtrl = TextEditingController();
  final _choiceDCtrl = TextEditingController();
  String? _selectedChoiceAnswer;

  @override
  void initState() {
    super.initState();
    _sectionDeadlines['Section A'] = _scheduleDate;
    _sectionDeadlines['Section B'] = _scheduleDate;
    if (widget.skipTypeSelection) {
      _selectAssessmentType(widget.initialIsExam);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _gradingQuarterCtrl.dispose();
    _qTextCtrl.dispose();
    _qCorrectAnswerCtrl.dispose();
    _qPointsCtrl.dispose();
    _choiceACtrl.dispose();
    _choiceBCtrl.dispose();
    _choiceCCtrl.dispose();
    _choiceDCtrl.dispose();
    _matchingLeftCtrl.dispose();
    _matchingRightCtrl.dispose();
    for (final controller in _questionCountCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectAssessmentType(bool isExam) {
    setState(() {
      _isExam = isExam;
      _currentStep = 1;
      _durationCtrl.text = isExam ? '60' : '30';
      if (_isExam) {
        _setExamTitle('ST1');
        _descCtrl.text = 'Comprehensive examination covering General Mathematics core competencies.';
      } else {
        _titleCtrl.text = 'Quiz: Rational Functions & Domain/Range';
        _descCtrl.text =
            'Formative quiz on composite functions and asymptote evaluations.';
      }
    });
  }

  Future<void> _selectAssessmentDeadline(String section) async {
    final current = _sectionDeadlines[section] ?? _scheduleDate;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted || time == null) return;
    setState(() {
      _sectionDeadlines[section] = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _scheduleDate = _sectionDeadlines[section]!;
    });
  }

  String _formatAssessmentDeadline(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  void _addQuestionToList() {
    if (_qTextCtrl.text.trim().isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Incomplete Question',
        message: 'Please provide question text and the correct answer before adding.',
      );
      return;
    }

    final points = int.tryParse(_qPointsCtrl.text.trim());
    if (points == null || points < 1 || points > 10) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid Points',
        message: 'Points must be a whole number from 1 to 10.',
      );
      return;
    }
    final planned = _questionCounts[_selectedQType] ?? 0;
    final alreadyAdded = _questions
        .where((q) => q.type == _selectedQType)
        .length;
    if (planned == 0 || alreadyAdded >= planned) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Question Limit Reached',
        message: 'This question type is not included or has already reached its planned count.',
      );
      return;
    }
    List<String> choices = [];

    if (_selectedQType == QuestionType.multipleChoice) {
      choices = [
        _choiceACtrl.text.trim().isEmpty
            ? 'Option A'
            : _choiceACtrl.text.trim(),
        _choiceBCtrl.text.trim().isEmpty
            ? 'Option B'
            : _choiceBCtrl.text.trim(),
        _choiceCCtrl.text.trim().isEmpty
            ? 'Option C'
            : _choiceCCtrl.text.trim(),
        _choiceDCtrl.text.trim().isEmpty
            ? 'Option D'
            : _choiceDCtrl.text.trim(),
      ];
    } else if (_selectedQType == QuestionType.trueFalse) {
      choices = ['True', 'False'];
    } else if (_selectedQType == QuestionType.matching) {
      if (_matchingPairs.isEmpty) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Matching Pairs Required',
          message:
              'Add at least one matching pair before adding this question.',
        );
        return;
      }
    }

    final correctAnswer =
        _selectedQType == QuestionType.multipleChoice ||
            _selectedQType == QuestionType.trueFalse
        ? (_selectedChoiceAnswer ?? '')
        : _selectedQType == QuestionType.matching
        ? _matchingPairs.entries.map((e) => '${e.key}=${e.value}').join('|')
        : _qCorrectAnswerCtrl.text.trim();
    if (correctAnswer.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Correct Answer Required',
        message:
            'Select or enter the correct answer before adding the question.',
      );
      return;
    }

    setState(() {
      _questions.add(
        QuestionModel(
          id: 'q_${DateTime.now().millisecondsSinceEpoch}',
          questionText: _qTextCtrl.text.trim(),
          type: _selectedQType,
          choices: choices,
          correctAnswer: correctAnswer,
          points: points.toDouble(),
          matchingPairs: Map<String, String>.from(_matchingPairs),
        ),
      );

      // Clear question builder fields
      _qTextCtrl.clear();
      _qCorrectAnswerCtrl.clear();
      _choiceACtrl.clear();
      _choiceBCtrl.clear();
      _choiceCCtrl.clear();
      _choiceDCtrl.clear();
      _selectedChoiceAnswer = null;
      _matchingPairs.clear();
      _advanceToNextQuestionType();
    });
  }

  List<QuestionType> get _configuredQuestionTypes => QuestionType.values
      .where((type) => (_questionCounts[type] ?? 0) > 0)
      .toList();

  bool get _canAddCurrentQuestion {
    final planned = _questionCounts[_selectedQType] ?? 0;
    final added = _questions
        .where((question) => question.type == _selectedQType)
        .length;
    return planned > 0 && added < planned;
  }

  void _advanceToNextQuestionType() {
    final types = _configuredQuestionTypes;
    if (types.isEmpty) return;
    final currentIndex = types.indexOf(_selectedQType);
    final currentCount = _questions
        .where((q) => q.type == _selectedQType)
        .length;
    if (currentCount < (_questionCounts[_selectedQType] ?? 0)) return;
    for (var index = currentIndex + 1; index < types.length; index++) {
      final type = types[index];
      if (_questions.where((q) => q.type == type).length <
          (_questionCounts[type] ?? 0)) {
        _selectedQType = type;
        return;
      }
    }
  }

  void _setExamTitle(String category) {
    _examCategory = category;
    _titleCtrl.text = switch (category) {
      'ST2' => 'Summative Test 2 (ST2)',
      'TE' => 'Term Examination (TE)',
      _ => 'Summative Test 1 (ST1)',
    };
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

    final duration = int.tryParse(_durationCtrl.text.trim());
    if (duration == null || duration < 1) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid Duration',
        message: 'Duration must be a whole number greater than 0.',
      );
      return;
    }
    if (_selectedSections.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Assigned Section Required',
        message: 'Select at least one assigned section.',
      );
      return;
    }

    final plannedTotal = _questionCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    if (_questions.length != plannedTotal) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Incomplete Question Set',
        message:
            'Add all $plannedTotal planned questions before publishing. Current total: ${_questions.length}.',
      );
      return;
    }

    final totalPoints = _questions.fold<double>(
      0,
      (sum, question) => sum + question.points,
    );
    if (totalPoints > 100) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Maximum Points Exceeded',
        message:
            'The total points for one quiz or examination cannot exceed 100.',
      );
      return;
    }

    final newAssessment = QuizOrExamModel(
      id: '${_isExam ? "exam" : "quiz"}_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      subject: 'General Mathematics',
      section: _selectedSections.join(', '),
      isExam: _isExam,
      durationMinutes: duration,
      scheduleDate: _sectionDeadlines[_selectedSections.first] ?? _scheduleDate,
      sectionDeadlines: {
        for (final section in _selectedSections)
          section: _sectionDeadlines[section] ?? _scheduleDate,
      },
      isPublished: true,
      questions: List.from(_questions),
    );

    MockDatabase.instance.addQuizOrExam(newAssessment);
    widget.onAssessmentCreated();
    Navigator.of(context).pop();

    AppModals.showSuccessDialog(
      context: context,
      title: _isExam
          ? 'Periodical Examination Published'
          : 'Quiz Assessment Published',
      message:
          '${newAssessment.title} has been configured and published for ${newAssessment.section}. Duration: $duration mins, Total Points: ${newAssessment.totalPoints.toInt()} pts.',
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
                      color: _isExam
                          ? AppColors.errorLight
                          : AppColors.infoLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isExam
                          ? Icons.description_outlined
                          : Icons.quiz_outlined,
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _currentStep == 0
                              ? 'Choose the assessment category for Senior High School'
                              : _currentStep == 1
                              ? 'Set title, section, duration, and instructions'
                              : _currentStep == 2
                              ? 'Set details and question distribution'
                              : 'Add questions and answer keys',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _currentStep == 0
                  ? _buildTypeSelectionView()
                  : _currentStep == 1
                  ? _buildBasicDetailsView()
                  : _buildQuestionBuilderView(),
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
                  if (_currentStep > 0)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: Text(
                        _currentStep == 3
                            ? 'Back to Details'
                            : 'Back to Type Selection',
                      ),
                      onPressed: () => setState(
                        () => _currentStep = _currentStep == 3
                            ? 1
                            : _currentStep - 1,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep == 1)
                        AppPrimaryButton(
                          label: 'Continue to Question Builder',
                          icon: Icons.arrow_forward,
                          height: 42,
                          onPressed: _continueToQuestionBuilder,
                        ),
                      if (_currentStep == 3)
                        AppPrimaryButton(
                          label: _isExam ? 'Save Examination' : 'Save Quiz',
                          icon: Icons.check_circle_outline,
                          height: 42,
                          backgroundColor: _isExam
                              ? AppColors.error
                              : AppColors.primary,
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

  Widget _buildBasicDetailsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isExam)
            DropdownButtonFormField<String>(
              initialValue: _examCategory,
              decoration: const InputDecoration(
                labelText: 'Periodical Examination Title',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'ST1',
                  child: Text('Summative Test 1 (ST1)'),
                ),
                DropdownMenuItem(
                  value: 'ST2',
                  child: Text('Summative Test 2 (ST2)'),
                ),
                DropdownMenuItem(
                  value: 'TE',
                  child: Text('Term Examination (TE)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _setExamTitle(value));
              },
            )
          else
            AppTextField(label: 'Quiz Title', controller: _titleCtrl),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Duration (Minutes)',
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Assigned Section & Start Date / Time',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...['Section A', 'Section B'].map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(section),
                      value: _selectedSections.contains(section),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedSections.add(section);
                          } else {
                            _selectedSections.remove(section);
                          }
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectAssessmentDeadline(section),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatAssessmentDeadline(
                                  _sectionDeadlines[section] ?? _scheduleDate,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppTextField(
            label: 'Instructions & Guidelines',
            controller: _descCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          _buildQuestionPlanFields(),
        ],
      ),
    );
  }

  Widget _buildQuestionPlanFields() {
    const labels = {
      QuestionType.multipleChoice: 'Multiple Choices',
      QuestionType.trueFalse: 'True / False',
      QuestionType.matching: 'Matching Type',
      QuestionType.identification: 'Identification',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Distribution',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Set how many questions to include for each question type.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _questionCountCtrls.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels[entry.key]!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: AppTextField(
                        label: '',
                        hint: 'Items',
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Total number of questions: ${_questionCountCtrls.values.fold<int>(0, (sum, controller) => sum + (int.tryParse(controller.text) ?? 0))} / 100',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color:
                _questionCountCtrls.values.fold<int>(
                      0,
                      (sum, controller) =>
                          sum + (int.tryParse(controller.text) ?? 0),
                    ) >
                    100
                ? AppColors.error
                : AppColors.primary,
          ),
        ),
      ],
    );
  }

  void _continueToQuestionSetup() {
    if (_titleCtrl.text.trim().isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Title Required',
        message: 'Please provide a title before continuing.',
      );
      return;
    }
    final duration = int.tryParse(_durationCtrl.text.trim());
    if (duration == null || duration < 1) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid Duration',
        message: 'Duration must be a whole number greater than 0.',
      );
      return;
    }
    setState(() => _currentStep = 2);
  }

  void _continueToQuestionBuilder() {
    final counts = <QuestionType, int>{};
    for (final entry in _questionCountCtrls.entries) {
      final text = entry.value.text.trim();
      final count = text.isEmpty ? 0 : int.tryParse(text);
      if (count == null || count < 0 || count > 100) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Invalid Question Count',
          message: 'Each question type must be empty/0 or a whole number from 1 to 100.',
        );
        return;
      }
      counts[entry.key] = count;
    }
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total < 1 || total > 100) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid Total Number of Questions',
        message: 'The total number of questions must be between 1 and 100.',
      );
      return;
    }
    setState(() {
      _questionCounts
        ..clear()
        ..addAll(counts);
      _selectedQType = _configuredQuestionTypes.first;
      _currentStep = 3;
    });
  }

  Widget _buildQuestionPlanView() {
    final labels = {
      QuestionType.multipleChoice: 'Multiple Choices',
      QuestionType.trueFalse: 'True / False',
      QuestionType.matching: 'Matching Type',
      QuestionType.identification: 'Identification',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isExam
                ? 'Set Examination Question Distribution'
                : 'Set Quiz Question Distribution',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose which question types to include and how many items each section should contain. The total will be calculated automatically.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 22),
          ..._questionCounts.keys.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      labels[type]!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: _questionCountCtrls[type],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Number of items',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(
                          () =>
                              _questionCounts[type] = int.tryParse(value) ?? 0,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total questions: ${_questionCounts.values.fold<int>(0, (sum, count) => sum + count)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: const SizedBox.shrink(),
          ),
        ],
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
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
                    description: 'Short assessment to evaluate student mastery of specific mathematical competencies, piecewise functions, or subtopics.',
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
                    description: 'Official institutional quarterly or midterm examination. Integrated with answer keys, auto-checking, and item analysis.',
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
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
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
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
                child: Text(
                  'Create ${title.split(" ")[0]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 3: BUILD QUESTIONS
  // ==========================================
  Widget _buildQuestionBuilderView() {
    const labels = <QuestionType, String>{
      QuestionType.multipleChoice: 'Multiple Choices',
      QuestionType.trueFalse: 'True / False',
      QuestionType.matching: 'Matching Type',
      QuestionType.identification: 'Identification',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      _isExam
                          ? 'Answer Key & Question Items Setup'
                          : 'Quiz Questions Builder',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Added: ${_questions.length} question(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question Type Selector
                Row(
                  children: [
                    if (_configuredQuestionTypes.length > 1) ...[
                      const Text(
                        'Question Type:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<QuestionType>(
                        value: _configuredQuestionTypes.contains(_selectedQType)
                            ? _selectedQType
                            : _configuredQuestionTypes.first,
                        items: _configuredQuestionTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedQType = val;
                              _selectedChoiceAnswer = null;
                              _matchingPairs.clear();
                            });
                          }
                        },
                      ),
                    ],
                    if (_configuredQuestionTypes.length == 1)
                      Text(
                        labels[_configuredQuestionTypes.first]!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _qPointsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Points',
                          isDense: true,
                        ),
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
                      Radio<String>(
                        value: 'A',
                        groupValue: _selectedChoiceAnswer,
                        onChanged: (value) =>
                            setState(() => _selectedChoiceAnswer = value),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _choiceACtrl,
                          decoration: const InputDecoration(
                            labelText: 'Choice A',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Radio<String>(
                        value: 'B',
                        groupValue: _selectedChoiceAnswer,
                        onChanged: (value) =>
                            setState(() => _selectedChoiceAnswer = value),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _choiceBCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Choice B',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'C',
                        groupValue: _selectedChoiceAnswer,
                        onChanged: (value) =>
                            setState(() => _selectedChoiceAnswer = value),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _choiceCCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Choice C',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Radio<String>(
                        value: 'D',
                        groupValue: _selectedChoiceAnswer,
                        onChanged: (value) =>
                            setState(() => _selectedChoiceAnswer = value),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _choiceDCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Choice D',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_selectedQType == QuestionType.trueFalse) ...[
                  const Text(
                    'Select the correct answer:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  ...['True', 'False'].map(
                    (answer) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(answer),
                      value: answer,
                      groupValue: _selectedChoiceAnswer,
                      onChanged: (value) =>
                          setState(() => _selectedChoiceAnswer = value),
                    ),
                  ),
                ],
                if (_selectedQType == QuestionType.matching) ...[
                  const Text(
                    'Matching pairs',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _matchingLeftCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Item / Prompt',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _matchingRightCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Correct Match',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          final left = _matchingLeftCtrl.text.trim();
                          final right = _matchingRightCtrl.text.trim();
                          if (left.isEmpty || right.isEmpty) return;
                          setState(() {
                            _matchingPairs[left] = right;
                            _matchingLeftCtrl.clear();
                            _matchingRightCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  ..._matchingPairs.entries.map(
                    (pair) => ListTile(
                      dense: true,
                      title: Text(pair.key),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pair.value,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 17),
                            onPressed: () =>
                                setState(() => _matchingPairs.remove(pair.key)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Answer Key / Correct Answer field
                if (_selectedQType == QuestionType.identification)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qCorrectAnswerCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Official Correct Answer',
                            hintText:
                                'Enter the answer used by the auto-checker',
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
                        onPressed: _canAddCurrentQuestion
                            ? _addQuestionToList
                            : null,
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppPrimaryButton(
                      label: 'Add to List',
                      icon: Icons.add,
                      height: 42,
                      width: 130,
                      onPressed: _canAddCurrentQuestion
                          ? _addQuestionToList
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Render List of Questions Added
          if (_questions.isNotEmpty) ...[
            const Text(
              'Configured Questions & Answer Keys:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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
                      child: Text(
                        '$idx',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.questionText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Type: ${q.type.name.toUpperCase()} • Key: "${q.correctAnswer}" • Points: ${q.points}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
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
