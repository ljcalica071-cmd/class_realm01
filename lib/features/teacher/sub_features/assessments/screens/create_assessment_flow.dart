// Legacy question-planning helpers remain available for future wiring.
// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/quiz_exam_authoring/quiz_exam_authoring.dart';

class CreateAssessmentFlowDialog extends StatefulWidget {
  final VoidCallback onAssessmentCreated;
  final String initialSection;
  final bool initialIsExam;
  final bool skipTypeSelection;

  const CreateAssessmentFlowDialog({
    super.key,
    required this.onAssessmentCreated,
    this.initialSection = '',
    this.initialIsExam = false,
    this.skipTypeSelection = true,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAssessmentCreated,
    String? initialSection,
    bool initialIsExam = false,
    bool skipTypeSelection = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateAssessmentFlowDialog(
        onAssessmentCreated: onAssessmentCreated,
        initialSection: initialSection ?? '',
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
  // 1: Configure & Add Questions / Details
  // 3: Question Builder
  int _currentStep = 1;
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
  final Set<String> _selectedSections = {};
  final Map<String, DateTime> _sectionDeadlines = {};
  List<String> _availableSections = [];
  List<Map<String, dynamic>> _teacherSubjects = [];
  String _subjectName = '';
  bool _isLoadingSections = true;

  bool get _isZeroExamSubject {
    if (_teacherSubjects.isEmpty) return false;
    final match = _teacherSubjects.firstWhere(
      (s) => _selectedSections.contains(s['section_name']),
      orElse: () => _teacherSubjects.first,
    );
    final exWeight = (match['ex_weight'] as num?)?.toDouble() ?? 30.0;
    return exWeight == 0.0;
  }

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
    _loadTeacherSections();
    if (widget.skipTypeSelection) {
      _selectAssessmentType(widget.initialIsExam);
    }
  }

  Future<void> _loadTeacherSections() async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      if (mounted) setState(() => _isLoadingSections = false);
      return;
    }
    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(teacherId);
      final sections = subjects
          .map((s) => s['section_name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final sub = subjects.isNotEmpty
          ? (subjects.first['subject_name']?.toString() ?? '')
          : '';
      if (!mounted) return;
      setState(() {
        _teacherSubjects = subjects;
        _availableSections = sections;
        _subjectName = sub;
        _isLoadingSections = false;
        _selectedSections.clear();
        if (sections.contains(widget.initialSection)) {
          _selectedSections.add(widget.initialSection);
          _sectionDeadlines[widget.initialSection] = _scheduleDate;
        } else if (sections.isNotEmpty) {
          _selectedSections.add(sections.first);
          _sectionDeadlines[sections.first] = _scheduleDate;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSections = false);
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
    if (isExam && _isZeroExamSubject) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Zero-Exam Subject',
        message:
            'This subject has no Examination component under DepEd Order No. 015, s. 2026. Initial Grades are computed 100% from Written Works and Performance Tasks.',
      );
      return;
    }
    setState(() {
      _isExam = isExam;
      _currentStep = 1;
      _durationCtrl.text = isExam ? '60' : '30';
      _titleCtrl.text = '';
      _descCtrl.text = '';
      if (_isExam) {
        _setExamTitle('ST1');
      }
    });
  }

  Future<void> _selectAssessmentDeadline(String section) async {
    final current = _sectionDeadlines[section] ?? _scheduleDate;
    final now = DateTime.now();
    final initial = current.isBefore(now) ? now.add(const Duration(hours: 1)) : current;
    final date = await showAppDatePickerDialog(
      context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
      title: 'Select Assessment Deadline',
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
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
    final isMatching = _selectedQType == QuestionType.matching;
    if (_qTextCtrl.text.trim().isEmpty && !isMatching) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Incomplete Question',
        message:
            'Please provide question text and the correct answer before adding.',
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
      // For matching type, choices are the options students can pick from (Column B)
      choices = _matchingPairs.values.toList();
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
          questionText: isMatching && _qTextCtrl.text.trim().isEmpty
              ? 'Match the items in Column A with the correct items in Column B.'
              : _qTextCtrl.text.trim(),
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

    // Strict EX (ST1, ST2, TE single slot) and WW (10 limit) validation
    if (_isExam) {
      if (_isZeroExamSubject) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Zero-Exam Subject',
          message:
              'This subject has no Examination component under DepEd Order No. 015, s. 2026. Initial Grades are computed 100% from Written Works and Performance Tasks.',
        );
        return;
      }
      final existingExams = MockDatabase.instance.quizzesAndExams.where(
        (a) => a.isExam && a.title.contains(_examCategory),
      );
      if (existingExams.isNotEmpty) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Exam Slot Occupied',
          message:
              'You already have an existing $_examCategory scheduled for this subject. In accordance with DepEd guidelines, only one ST1, one ST2, and one TE are allowed per term.',
        );
        return;
      }
    } else {
      final existingQuizzes = MockDatabase.instance.quizzesAndExams.where((a) => !a.isExam).length;
      final existingActivities = MockDatabase.instance.activities.where((a) => !a.isRequirement).length;
      if (existingQuizzes + existingActivities >= 10) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Maximum Limit Reached',
          message:
              'Maximum limit reached: You have already assigned all 10 WW columns for this Term.',
        );
        return;
      }
    }

    final newAssessment = QuizOrExamModel(
      id: '${_isExam ? "exam" : "quiz"}_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      subject: _subjectName.isNotEmpty ? _subjectName : 'General Subject',
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

    // Synchronize Quiz or Exam HPS into Gradebook sheet for the assigned sections
    try {
      final categoryKey = _isExam ? 'ex' : 'ww';
      final hpsSlotKey = _isExam ? _examCategory.toLowerCase() : '1';

      final user = AuthRepository.instance.currentUser;
      if (user != null) {
        SubjectRepository.instance.getTeacherSubjects(user.id).then((offerings) {
          for (final section in _selectedSections) {
            final match = offerings.firstWhere(
              (o) => o['section_name']?.toString() == section,
              orElse: () => <String, dynamic>{},
            );
            final offeringId = match['id']?.toString();
            if (offeringId != null) {
              SubjectRepository.instance.getGradebookTermSheet(offeringId, 1).then((termSheet) {
                final sheet = Map<String, dynamic>.from(termSheet ?? {});
                final hps = Map<String, dynamic>.from(sheet['hps'] as Map? ?? {});
                final catMap = Map<String, dynamic>.from(hps[categoryKey] as Map? ?? {});

                catMap[hpsSlotKey] = totalPoints;
                hps[categoryKey] = catMap;
                sheet['hps'] = hps;

                SubjectRepository.instance.saveGradebookTermSheet(offeringId, 1, sheet);
              }).catchError((e) {
                debugPrint('Assessment HPS sync notice: $e');
              });
            }
          }
        });
      }
    } catch (_) {}

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
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isExam
                          ? AppTheme.catRed.withValues(alpha: 0.1)
                          : AppTheme.catBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isExam
                          ? Icons.description_outlined
                          : Icons.quiz_outlined,
                      color: _isExam ? AppTheme.catRed : Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isExam
                              ? 'Configure Periodical Examination'
                              : 'Configure Unit Quiz',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _currentStep == 1
                              ? 'Set title, section, duration, and instructions'
                              : 'Add questions and answer keys',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _currentStep == 1
                  ? _buildBasicDetailsView()
                  : _buildQuestionBuilderView(),
            ),

            // Footer / Bottom Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep == 3)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Details'),
                      onPressed: () => setState(() => _currentStep = 1),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                              ? AppTheme.catRed
                              : Theme.of(context).colorScheme.primary,
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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upfront AI Generation Card (Prominently placed at the front/top of the modal)
          Container(
            margin: const EdgeInsets.only(bottom: 22),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.catPurple.withValues(alpha: 0.12),
                  theme.colorScheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.catPurple.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.catPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.catPurple, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isExam ? 'Generate Examination with Gemini AI' : 'Generate Quiz with Gemini AI',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.catPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AI POWERED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.catPurple),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Upload syllabus files (.pdf, .docx, .txt) or enter topics to auto-generate questions, choices, and answer keys.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('Generate with AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.catPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openAiGeneration,
                ),
              ],
            ),
          ),

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
            AppTextField(
              label: 'Quiz Title',
              hint: 'e.g., Short Quiz on Piecewise Functions',
              controller: _titleCtrl,
            ),
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
          Text(
            'Assigned Section & Start Date / Time',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (_isLoadingSections)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_availableSections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No sections available yet. Please set up your sections in Classroom Setup first.',
                style: TextStyle(
                  color: AppTheme.catRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            ..._availableSections.map(
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
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
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
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
        Text(
          'Question Distribution',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Set how many questions to include for each question type.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
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
                        style: TextStyle(fontWeight: FontWeight.w600),
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
                ? AppTheme.catRed
                : Theme.of(context).colorScheme.primary,
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

  void _openAiGeneration() {
    AiGenerationModal.show(
      context,
      isExam: _isExam,
      subjectName: _subjectName,
      onQuestionsGenerated: (generated) {
        setState(() {
          _questions.addAll(generated);
          _currentStep = 3;
        });
        AppModals.showSuccessDialog(
          context: context,
          title: 'Questions Generated with Gemini AI',
          message:
              '${generated.length} questions were successfully generated. Please review each question, verify answer keys, and adjust points before publishing.',
        );
      },
    );
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
          // AI Generation Prompt Card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.catPurple.withValues(alpha: 0.1),
                  AppTheme.catBlue.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.catPurple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.catPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.catPurple, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate Assessment with Gemini AI',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload a reference document (.pdf, .docx, .txt) to automatically create questions grounded on your syllabus.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Auto-Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.catPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openAiGeneration,
                ),
              ],
            ),
          ),
          Text(
            _isExam
                ? 'Set Examination Question Distribution'
                : 'Set Quiz Question Distribution',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose which question types to include and how many items each section should contain. The total will be calculated automatically.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
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
                      style: TextStyle(fontWeight: FontWeight.w600),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
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
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome, size: 14),
                          label: const Text('Generate with AI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.catPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _openAiGeneration,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Added: ${_questions.length} question(s)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question Type Selector
                Row(
                  children: [
                    if (_configuredQuestionTypes.length > 1) ...[
                      Text(
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
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
                if (_selectedQType != QuestionType.matching)
                  TextField(
                    controller: _qTextCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Enter Question Statement',
                      hintText:
                          'e.g. Find the horizontal asymptote of f(x) = (3x + 1) / (2x - 5)',
                      isDense: true,
                    ),
                  ),
                if (_selectedQType != QuestionType.matching)
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
                  Text(
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
                  Text(
                    'Matching pairs',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_matchingPairs.length + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                        icon: Icon(
                          Icons.add_circle,
                          color: Theme.of(context).colorScheme.primary,
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
                  const SizedBox(height: 10),
                  ..._matchingPairs.entries.toList().asMap().entries.map(
                    (entry) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      title: Text(entry.value.key),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value.value,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 17),
                            onPressed: () => setState(
                                () => _matchingPairs.remove(entry.value.key)),
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
            Text(
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
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        '$idx',
                        style: TextStyle(
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Type: ${q.type.name.toUpperCase()} • Key: "${q.correctAnswer}" • Points: ${q.points}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppTheme.catRed,
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
