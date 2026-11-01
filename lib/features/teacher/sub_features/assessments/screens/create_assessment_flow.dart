// Create Examination (EX) & Assessment Flow Dialog
// Fully redesigned to DepEd Order No. 015, s. 2026 standards.
// Features Online (Take via App) & In-Person (Manual Record), sequential slot
// locking (ST1 -> ST2 -> TE), split-box Date/Time/Duration, and category-isolated Question Builder.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/quiz_exam_authoring/quiz_exam_authoring.dart';

/// Active draft of an individual question during step 2 authoring.
class QuestionDraft {
  final int position;
  final QuestionType type;
  String statement;
  List<String> choices; // 4 choices for multiple choice
  String correctAnswer; // 'A'/'B'/'C'/'D', 'True'/'False', or identification text
  double points;

  QuestionDraft({
    required this.position,
    required this.type,
    this.statement = '',
    List<String>? choices,
    this.correctAnswer = '',
    this.points = 1.0,
  }) : choices = choices ?? ['', '', '', ''];

  bool get isComplete {
    if (statement.trim().isEmpty) return false;
    if (points <= 0) return false;
    if (type == QuestionType.multipleChoice) {
      if (choices.length < 4 || choices.any((c) => c.trim().isEmpty)) return false;
      return correctAnswer.isNotEmpty;
    } else if (type == QuestionType.trueFalse) {
      return correctAnswer == 'True' || correctAnswer == 'False';
    } else if (type == QuestionType.identification) {
      return correctAnswer.trim().isNotEmpty;
    }
    return false;
  }
}

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
  // Stepper: 1 = Basic Configuration, 2 = Question Builder (Online mode)
  int _currentStep = 1;

  // Mode: 'online' (Take via App) or 'in_person' (Manual Record)
  String _completionMode = 'online';

  // Slot: 'ST1', 'ST2', 'TE'
  String _examCategory = 'ST1';

  // Sequential slot statuses for selected offering
  bool _st1Created = false;
  bool _st2Created = false;
  bool _teCreated = false;
  bool _isCheckingSlots = false;

  // Selected Offering
  Map<String, dynamic>? _selectedOffering;
  List<Map<String, dynamic>> _teacherSubjects = [];
  bool _isLoadingOfferings = true;

  // Form Fields - Step 1
  final _titleCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');
  final _hpsPointsCtrl = TextEditingController(text: '100');

  DateTime _scheduledDate = DateTime(
    DateTime.now().year < 2026 ? 2026 : DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);

  // Inline error strings
  String? _instructionsError;
  String? _dateError;
  String? _durationError;
  String? _distributionError;

  // Question distributions (3 types only, max 3 digits)
  final _mcCountCtrl = TextEditingController(text: '5');
  final _tfCountCtrl = TextEditingController(text: '3');
  final _idCountCtrl = TextEditingController(text: '2');

  // Step 2: Question Builder
  List<QuestionDraft> _plannedQuestions = [];
  int _activeQuestionIndex = 0;

  // Active question editor fields
  final _qStatementCtrl = TextEditingController();
  final _qPointsCtrl = TextEditingController(text: '1');
  final _choiceACtrl = TextEditingController();
  final _choiceBCtrl = TextEditingController();
  final _choiceCCtrl = TextEditingController();
  final _choiceDCtrl = TextEditingController();
  String? _selectedMcAnswer; // 'A', 'B', 'C', 'D'
  String? _selectedTfAnswer; // 'True', 'False'
  final _qIdAnswerCtrl = TextEditingController();
  String? _editorError;

  bool _isPublishing = false;

  bool get _isZeroExamSubject {
    if (_selectedOffering == null) return false;
    final exWeight = (_selectedOffering!['ex_weight'] as num?)?.toDouble() ?? 30.0;
    return exWeight == 0.0;
  }

  int get _totalPlannedQuestions {
    final mc = int.tryParse(_mcCountCtrl.text.trim()) ?? 0;
    final tf = int.tryParse(_tfCountCtrl.text.trim()) ?? 0;
    final id = int.tryParse(_idCountCtrl.text.trim()) ?? 0;
    return mc + tf + id;
  }

  bool get _areAllSlotsFilled => _st1Created && _st2Created && _teCreated;

  @override
  void initState() {
    super.initState();
    _instructionsCtrl.addListener(() {
      if (_instructionsError != null) {
        setState(() => _instructionsError = null);
      }
    });
    _durationCtrl.addListener(() {
      if (_durationError != null) {
        setState(() => _durationError = null);
      }
    });
    _loadTeacherOfferings();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    _durationCtrl.dispose();
    _hpsPointsCtrl.dispose();
    _mcCountCtrl.dispose();
    _tfCountCtrl.dispose();
    _idCountCtrl.dispose();
    _qStatementCtrl.dispose();
    _qPointsCtrl.dispose();
    _choiceACtrl.dispose();
    _choiceBCtrl.dispose();
    _choiceCCtrl.dispose();
    _choiceDCtrl.dispose();
    _qIdAnswerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherOfferings() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingOfferings = false);
      return;
    }
    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(user.id);
      if (!mounted) return;

      Map<String, dynamic>? initial;
      if (widget.initialSection.isNotEmpty) {
        initial = subjects.firstWhere(
          (s) => s['section_name']?.toString() == widget.initialSection,
          orElse: () => subjects.isNotEmpty ? subjects.first : <String, dynamic>{},
        );
      } else if (subjects.isNotEmpty) {
        initial = subjects.first;
      }

      setState(() {
        _teacherSubjects = subjects;
        _selectedOffering = initial != null && initial.isNotEmpty ? initial : null;
        _isLoadingOfferings = false;
      });

      if (_selectedOffering != null) {
        final offeringId = _selectedOffering!['id']?.toString() ?? '';
        if (offeringId.isNotEmpty) {
          _checkSlotStatuses(offeringId);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOfferings = false);
    }
  }

  Future<void> _checkSlotStatuses(String offeringId) async {
    setState(() => _isCheckingSlots = true);
    try {
      final client = SupabaseService().client;

      // 1. Check existing classwork items for this offering under EX
      final items = await client
          .from('classwork_items')
          .select('title, gradebook_column_index')
          .eq('subject_offering_id', offeringId)
          .eq('grading_category', 'ex')
          .eq('is_archived', false);

      // 2. Check gradebook sheet HPS
      final termSheet = await SubjectRepository.instance.getGradebookTermSheet(offeringId, 1);
      final hps = termSheet != null ? (termSheet['hps'] as Map? ?? {})['ex'] as Map? ?? {} : {};

      bool hasSt1 = false;
      bool hasSt2 = false;
      bool hasTe = false;

      for (final r in (items as List? ?? [])) {
        final col = r['gradebook_column_index'] as int?;
        final t = (r['title'] ?? '').toString().toUpperCase();
        if (col == 1 || t.contains('ST1') || t.contains('SUMMATIVE TEST 1')) hasSt1 = true;
        if (col == 2 || t.contains('ST2') || t.contains('SUMMATIVE TEST 2')) hasSt2 = true;
        if (col == 3 || t.contains('TE') || t.contains('TERM EXAM') || t.contains('PERIODICAL')) hasTe = true;
      }

      if (hps['st1'] != null && (hps['st1'] as num) > 0) hasSt1 = true;
      if (hps['st2'] != null && (hps['st2'] as num) > 0) hasSt2 = true;
      if (hps['te'] != null && (hps['te'] as num) > 0) hasTe = true;

      if (!mounted) return;
      setState(() {
        _st1Created = hasSt1;
        _st2Created = hasSt2;
        _teCreated = hasTe;
        _isCheckingSlots = false;

        // Auto-select the first available sequential slot
        if (!hasSt1) {
          _setExamSlot('ST1');
        } else if (!hasSt2) {
          _setExamSlot('ST2');
        } else if (!hasTe) {
          _setExamSlot('TE');
        } else {
          _setExamSlot('TE');
        }
      });
    } catch (e) {
      debugPrint('Slot check notice: $e');
      if (mounted) setState(() => _isCheckingSlots = false);
    }
  }

  void _setExamSlot(String slot) {
    setState(() {
      _examCategory = slot;
      _titleCtrl.text = switch (slot) {
        'ST2' => 'Summative Test 2 (ST2)',
        'TE' => 'Term Examination (TE)',
        _ => 'Summative Test 1 (ST1)',
      };
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year < 2026 ? 2026 : now.year, now.month, now.day);
    final minDate = _completionMode == 'online'
        ? today
        : DateTime(2026, 1, 1);

    final picked = await showAppDatePickerDialog(
      context,
      initialDate: _scheduledDate.isBefore(minDate) ? minDate : _scheduledDate,
      firstDate: minDate,
      lastDate: DateTime(2100),
      title: _completionMode == 'online' ? 'Select Scheduled Date' : 'Select Administered Date',
      icon: Icons.calendar_today_outlined,
    );

    if (picked != null && mounted) {
      setState(() {
        _scheduledDate = picked;
        _dateError = null;
      });
    }
  }

  void _handleContinueOrPublish() {
    setState(() {
      _instructionsError = null;
      _dateError = null;
      _durationError = null;
      _distributionError = null;
    });

    if (_isZeroExamSubject) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Zero-Exam Subject',
        message:
            'This subject has no Examination component under DepEd Order No. 015, s. 2026. Initial Grades are computed 100% from Written Works and Performance Tasks.',
      );
      return;
    }

    if (_areAllSlotsFilled) {
      AppModals.showErrorDialog(
        context: context,
        title: 'All Examination Slots Filled',
        message: 'All examination slots (ST1, ST2, TE) are already configured for this offering.',
      );
      return;
    }

    final instructions = _instructionsCtrl.text.trim();
    if (instructions.length < 2) {
      setState(() {
        _instructionsError = 'Instructions & Guidelines are required (min 2 characters).';
      });
      return;
    }

    if (_completionMode == 'in_person') {
      final hps = int.tryParse(_hpsPointsCtrl.text.trim());
      if (hps == null || hps < 1 || hps > 100) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Invalid Points',
          message: 'Total Points (HPS) must be a positive integer between 1 and 100.',
        );
        return;
      }
      _publishInPersonExam(hps);
      return;
    }

    // Online Mode validations
    final duration = int.tryParse(_durationCtrl.text.trim());
    if (duration == null || duration < 1) {
      setState(() => _durationError = 'Duration must be greater than 0.');
      return;
    }

    final mc = int.tryParse(_mcCountCtrl.text.trim()) ?? 0;
    final tf = int.tryParse(_tfCountCtrl.text.trim()) ?? 0;
    final id = int.tryParse(_idCountCtrl.text.trim()) ?? 0;
    final total = mc + tf + id;

    if (total == 0) {
      setState(() => _distributionError = 'Please configure at least 1 question.');
      return;
    }
    if (total > 100) {
      setState(() => _distributionError = 'Total questions cannot exceed 100 items ($total / 100).');
      return;
    }

    // Initialize Question Drafts for Step 2
    final drafts = <QuestionDraft>[];
    int pos = 1;
    for (int i = 0; i < mc; i++) {
      drafts.add(QuestionDraft(position: pos++, type: QuestionType.multipleChoice));
    }
    for (int i = 0; i < tf; i++) {
      drafts.add(QuestionDraft(position: pos++, type: QuestionType.trueFalse));
    }
    for (int i = 0; i < id; i++) {
      drafts.add(QuestionDraft(position: pos++, type: QuestionType.identification));
    }

    setState(() {
      _plannedQuestions = drafts;
      _activeQuestionIndex = 0;
      _currentStep = 2;
    });

    _loadQuestionIntoEditor(0);
  }

  void _loadQuestionIntoEditor(int index) {
    if (index < 0 || index >= _plannedQuestions.length) return;
    final q = _plannedQuestions[index];
    setState(() {
      _activeQuestionIndex = index;
      _qStatementCtrl.text = q.statement;
      _qPointsCtrl.text = q.points.toInt().toString();
      _editorError = null;

      if (q.type == QuestionType.multipleChoice) {
        _choiceACtrl.text = q.choices.isNotEmpty ? q.choices[0] : '';
        _choiceBCtrl.text = q.choices.length > 1 ? q.choices[1] : '';
        _choiceCCtrl.text = q.choices.length > 2 ? q.choices[2] : '';
        _choiceDCtrl.text = q.choices.length > 3 ? q.choices[3] : '';
        _selectedMcAnswer = q.correctAnswer.isNotEmpty ? q.correctAnswer : null;
      } else if (q.type == QuestionType.trueFalse) {
        _selectedTfAnswer = q.correctAnswer.isNotEmpty ? q.correctAnswer : null;
      } else if (q.type == QuestionType.identification) {
        _qIdAnswerCtrl.text = q.correctAnswer;
      }
    });
  }

  bool _saveCurrentEditorState() {
    if (_activeQuestionIndex < 0 || _activeQuestionIndex >= _plannedQuestions.length) {
      return false;
    }
    final q = _plannedQuestions[_activeQuestionIndex];
    final statement = _qStatementCtrl.text.trim();
    if (statement.isEmpty) {
      setState(() => _editorError = 'Question statement cannot be empty.');
      return false;
    }

    final points = double.tryParse(_qPointsCtrl.text.trim()) ?? 1.0;
    if (points <= 0) {
      setState(() => _editorError = 'Points must be at least 1.');
      return false;
    }

    if (q.type == QuestionType.multipleChoice) {
      final a = _choiceACtrl.text.trim();
      final b = _choiceBCtrl.text.trim();
      final c = _choiceCCtrl.text.trim();
      final d = _choiceDCtrl.text.trim();
      if (a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
        setState(() => _editorError = 'All 4 choices (A, B, C, D) are required.');
        return false;
      }
      if (_selectedMcAnswer == null || _selectedMcAnswer!.isEmpty) {
        setState(() => _editorError = 'Please select the correct answer radio.');
        return false;
      }
      q.statement = statement;
      q.points = points;
      q.choices = [a, b, c, d];
      q.correctAnswer = _selectedMcAnswer!;
    } else if (q.type == QuestionType.trueFalse) {
      if (_selectedTfAnswer == null || _selectedTfAnswer!.isEmpty) {
        setState(() => _editorError = 'Please select True or False as the answer key.');
        return false;
      }
      q.statement = statement;
      q.points = points;
      q.choices = ['True', 'False'];
      q.correctAnswer = _selectedTfAnswer!;
    } else if (q.type == QuestionType.identification) {
      final key = _qIdAnswerCtrl.text.trim();
      if (key.isEmpty) {
        setState(() => _editorError = 'Please specify the official answer key for identification.');
        return false;
      }
      q.statement = statement;
      q.points = points;
      q.correctAnswer = key;
    }

    setState(() => _editorError = null);
    _saveDraftLocally();
    return true;
  }

  void _saveDraftLocally() {
    try {
      final offeringId = _selectedOffering?['id']?.toString() ?? 'temp';
      final draftPayload = {
        'offeringId': offeringId,
        'slot': _examCategory,
        'instructions': _instructionsCtrl.text,
        'questions': _plannedQuestions.map((q) => {
          'position': q.position,
          'type': q.type.name,
          'statement': q.statement,
          'choices': q.choices,
          'correctAnswer': q.correctAnswer,
          'points': q.points,
        }).toList(),
      };
      AppDataCache.instance.set(
        'exam_draft_${offeringId}_$_examCategory',
        jsonEncode(draftPayload),
      );
    } catch (_) {}
  }

  Future<void> _publishInPersonExam(int hpsPoints) async {
    if (_selectedOffering == null) return;
    setState(() => _isPublishing = true);

    try {
      final client = SupabaseService().client;
      final offeringId = _selectedOffering!['id'].toString();
      final title = _titleCtrl.text.trim();
      final instructions = _instructionsCtrl.text.trim();

      final slotIndex = switch (_examCategory) {
        'ST2' => 2,
        'TE' => 3,
        _ => 1,
      };

      // 1. Insert into classwork_items
      await client.from('classwork_items').insert({
        'subject_offering_id': offeringId,
        'grading_category': 'ex',
        'title': title,
        'instructions': instructions,
        'max_score': hpsPoints,
        'deadline': _scheduledDate.toIso8601String(),
        'completion_mode': 'in_person',
        'is_requirement': true,
        'term_number': 1,
        'gradebook_column_index': slotIndex,
        'is_published': true,
      });

      // 2. Synchronize Gradebook Term Sheet HPS
      final termSheet = await SubjectRepository.instance.getGradebookTermSheet(offeringId, 1) ?? {};
      final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
      final exHps = Map<String, dynamic>.from(hps['ex'] as Map? ?? {});
      exHps[_examCategory.toLowerCase()] = hpsPoints;
      hps['ex'] = exHps;
      termSheet['hps'] = hps;
      await SubjectRepository.instance.saveGradebookTermSheet(offeringId, 1, termSheet);

      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAssessmentCreated();

      AppModals.showSuccessDialog(
        context: context,
        title: 'Examination Recorded',
        message: '$title has been saved in Gradebook as an In-Person examination with $hpsPoints total points.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Save Failed',
          message: 'Failed to record examination: $e',
        );
      }
    }
  }

  Future<void> _publishOnlineExam() async {
    if (!_saveCurrentEditorState()) return;

    final incomplete = _plannedQuestions.where((q) => !q.isComplete).toList();
    if (incomplete.isNotEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Incomplete Questions',
        message: 'Question #${incomplete.first.position} is missing its statement or answer key. Please review all items.',
      );
      _loadQuestionIntoEditor(incomplete.first.position - 1);
      return;
    }

    if (_selectedOffering == null) return;
    setState(() => _isPublishing = true);

    try {
      final client = SupabaseService().client;
      final offeringId = _selectedOffering!['id'].toString();
      final title = _titleCtrl.text.trim();
      final instructions = _instructionsCtrl.text.trim();
      final duration = int.parse(_durationCtrl.text.trim());

      final startDateTime = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final deadline = startDateTime.add(Duration(minutes: duration));

      final slotIndex = switch (_examCategory) {
        'ST2' => 2,
        'TE' => 3,
        _ => 1,
      };

      final totalPoints = _plannedQuestions.fold<double>(0.0, (sum, q) => sum + q.points);

      // 1. Create digital_assessments record
      final assessmentRow = await client
          .from('digital_assessments')
          .insert({
            'subject_offering_id': offeringId,
            'assessment_type': switch (_examCategory) {
              'ST2' => 'st2',
              'TE' => 'term_exam',
              _ => 'st1',
            },
            'grading_category': 'ex',
            'title': title,
            'instructions': instructions,
            'time_limit_minutes': duration,
            'available_from': startDateTime.toIso8601String(),
            'deadline': deadline.toIso8601String(),
            'attempts_allowed': 1,
            'is_published': true,
          })
          .select()
          .single();

      final assessmentId = assessmentRow['id'].toString();

      // 2. Insert assessment_questions & assessment_question_options
      for (final q in _plannedQuestions) {
        final qTypeStr = switch (q.type) {
          QuestionType.multipleChoice => 'multiple_choice',
          QuestionType.trueFalse => 'true_false',
          QuestionType.identification => 'identification',
          QuestionType.matching => 'matching_type',
        };

        final qRow = await client
            .from('assessment_questions')
            .insert({
              'assessment_id': assessmentId,
              'position': q.position,
              'question_type': qTypeStr,
              'question_text': q.statement,
              'points': q.points,
            })
            .select()
            .single();

        final qId = qRow['id'].toString();

        if (q.type == QuestionType.multipleChoice) {
          const labels = ['A', 'B', 'C', 'D'];
          for (int i = 0; i < 4; i++) {
            await client.from('assessment_question_options').insert({
              'question_id': qId,
              'option_label': labels[i],
              'option_text': q.choices[i],
              'is_correct': q.correctAnswer == labels[i],
            });
          }
        } else if (q.type == QuestionType.trueFalse) {
          await client.from('assessment_question_options').insert([
            {
              'question_id': qId,
              'option_label': 'True',
              'option_text': 'True',
              'is_correct': q.correctAnswer == 'True',
            },
            {
              'question_id': qId,
              'option_label': 'False',
              'option_text': 'False',
              'is_correct': q.correctAnswer == 'False',
            },
          ]);
        } else if (q.type == QuestionType.identification) {
          await client.from('assessment_question_options').insert({
            'question_id': qId,
            'option_label': 'Key',
            'option_text': q.correctAnswer,
            'is_correct': true,
          });
        }
      }

      // 3. Persist to classwork_items
      await client.from('classwork_items').insert({
        'subject_offering_id': offeringId,
        'grading_category': 'ex',
        'title': title,
        'instructions': instructions,
        'max_score': totalPoints.toInt(),
        'deadline': deadline.toIso8601String(),
        'completion_mode': 'online',
        'is_requirement': true,
        'term_number': 1,
        'gradebook_column_index': slotIndex,
        'is_published': true,
      });

      // 4. Update Gradebook Sheet HPS
      final termSheet = await SubjectRepository.instance.getGradebookTermSheet(offeringId, 1) ?? {};
      final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
      final exHps = Map<String, dynamic>.from(hps['ex'] as Map? ?? {});
      exHps[_examCategory.toLowerCase()] = totalPoints.toInt();
      hps['ex'] = exHps;
      termSheet['hps'] = hps;
      await SubjectRepository.instance.saveGradebookTermSheet(offeringId, 1, termSheet);

      // Clean local draft
      AppDataCache.instance.invalidate('exam_draft_${offeringId}_$_examCategory');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAssessmentCreated();

      AppModals.showSuccessDialog(
        context: context,
        title: 'Examination Published',
        message: '$title has been published for ${_selectedOffering!['section_name']}. Scheduled for ${_formatDate(_scheduledDate)} at ${AppTimePickerField.format(_startTime)} (${duration}m duration).',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Publish Failed',
          message: 'Error publishing digital assessment: $e',
        );
      }
    }
  }

  void _openAiGeneration() {
    final subName = _selectedOffering?['subject_name']?.toString() ?? 'General Subject';
    AiGenerationModal.show(
      context,
      isExam: true,
      subjectName: subName,
      onQuestionsGenerated: (generated) {
        final drafts = <QuestionDraft>[];
        int pos = 1;
        for (final q in generated) {
          drafts.add(QuestionDraft(
            position: pos++,
            type: q.type,
            statement: q.questionText,
            choices: List.from(q.choices),
            correctAnswer: q.correctAnswer,
            points: q.points,
          ));
        }
        setState(() {
          _plannedQuestions = drafts;
          _currentStep = 2;
          _activeQuestionIndex = 0;
        });
        _loadQuestionIntoEditor(0);
        AppModals.showSuccessDialog(
          context: context,
          title: 'Questions Generated with Gemini AI',
          message: '${drafts.length} questions were generated. You can now navigate the items, verify answer keys, and adjust points before publishing.',
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 740),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.catRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppTheme.catRed, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configure Periodical Examination',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _currentStep == 1
                              ? 'Set method, slot, schedule, instructions, and distributions'
                              : 'Question Builder — Author statements and mandatory answer keys',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _currentStep == 1
                  ? _buildStep1BasicDetailsView()
                  : _buildStep2QuestionBuilderView(),
            ),

            // Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep == 2)
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
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep == 1)
                        AppPrimaryButton(
                          label: _completionMode == 'in_person'
                              ? (_isPublishing ? 'Publishing...' : 'Publish Examination')
                              : 'Continue',
                          icon: _completionMode == 'in_person'
                              ? Icons.publish
                              : Icons.arrow_forward,
                          height: 42,
                          backgroundColor: AppTheme.catRed,
                          onPressed: (_areAllSlotsFilled || _isPublishing)
                              ? null
                              : _handleContinueOrPublish,
                        ),
                      if (_currentStep == 2)
                        AppPrimaryButton(
                          label: _isPublishing
                              ? 'Publishing Examination...'
                              : 'Save & Publish Examination',
                          icon: Icons.check_circle_outline,
                          height: 42,
                          backgroundColor: AppTheme.catRed,
                          onPressed: _isPublishing ? null : _publishOnlineExam,
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

  // =========================================================================
  // STEP 1: BASIC DETAILS & CONFIGURATION
  // =========================================================================
  Widget _buildStep1BasicDetailsView() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Generation Promo Card (Upfront at the top)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
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
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.catPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.catPurple, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Generate Examination with Gemini AI',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.catPurple),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload syllabus files (.pdf, .docx) to auto-generate questions and answer keys.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Generate with AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.catPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openAiGeneration,
                ),
              ],
            ),
          ),

          // 1. Method Segmented Selector: Online vs In-Person
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _completionMode = 'online'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _completionMode == 'online' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _completionMode == 'online'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.laptop_chromebook,
                            size: 16,
                            color: _completionMode == 'online' ? const Color(0xFF0F8A48) : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Online (Take via App)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _completionMode == 'online' ? FontWeight.w700 : FontWeight.w500,
                              color: _completionMode == 'online' ? const Color(0xFF0F8A48) : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _completionMode = 'in_person'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _completionMode == 'in_person' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _completionMode == 'in_person'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: _completionMode == 'in_person' ? const Color(0xFF0F8A48) : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'In-Person (Manual Record)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _completionMode == 'in_person' ? FontWeight.w700 : FontWeight.w500,
                              color: _completionMode == 'in_person' ? const Color(0xFF0F8A48) : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Target Section Chip
          if (_isLoadingOfferings)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_selectedOffering != null)
            _teacherSubjects.length > 1
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0F8A48).withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedOffering,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F8A48)),
                        items: _teacherSubjects.map((s) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: s,
                            child: Text(
                              'Grade ${s['grade_level'] ?? 11} • ${s['subject_name'] ?? 'Subject'} • ${s['section_name'] ?? 'Section'}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F8A48),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newOff) {
                          if (newOff != null) {
                            setState(() => _selectedOffering = newOff);
                            final offId = newOff['id']?.toString() ?? '';
                            if (offId.isNotEmpty) {
                              _checkSlotStatuses(offId);
                            }
                          }
                        },
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0F8A48).withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Grade ${_selectedOffering!['grade_level'] ?? 11} • ${_selectedOffering!['subject_name'] ?? 'Subject'} • ${_selectedOffering!['section_name'] ?? 'Section'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F8A48),
                      ),
                    ),
                  ),
          const SizedBox(height: 16),

          // 3. Sequential Slot Selector: ST1 -> ST2 -> TE
          Text(
            'Periodical Examination Slot *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (_isCheckingSlots)
            const LinearProgressIndicator(minHeight: 2)
          else
            Row(
              children: [
                Expanded(
                  child: _buildSlotButton(
                    slot: 'ST1',
                    label: 'Summative Test 1 (ST1)',
                    isCreated: _st1Created,
                    isEnabled: !_st1Created,
                    tooltip: _st1Created ? 'ST1 is already created' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSlotButton(
                    slot: 'ST2',
                    label: 'Summative Test 2 (ST2)',
                    isCreated: _st2Created,
                    isEnabled: _st1Created && !_st2Created,
                    tooltip: !_st1Created
                        ? 'Create ST1 first before ST2'
                        : (_st2Created ? 'ST2 is already created' : null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSlotButton(
                    slot: 'TE',
                    label: 'Term Examination (TE)',
                    isCreated: _teCreated,
                    isEnabled: _st1Created && _st2Created && !_teCreated,
                    tooltip: (!_st1Created || !_st2Created)
                        ? 'Complete ST1 & ST2 first before TE'
                        : (_teCreated ? 'TE is already created' : null),
                  ),
                ),
              ],
            ),
          if (_areAllSlotsFilled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All examination slots (ST1, ST2, TE) are already configured for this offering.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // 4. Split-Box Date, Time & Duration Controls
          if (_completionMode == 'online') ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scheduled Date Box
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled Date *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _dateError != null
                                  ? const Color(0xFFDC2626)
                                  : theme.colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDate(_scheduledDate),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_dateError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(_dateError!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Start Time Box
                Expanded(
                  flex: 4,
                  child: AppTimePickerField(
                    label: 'Start Time *',
                    initialTime: _startTime,
                    onTimeSelected: (t) => setState(() => _startTime = t),
                  ),
                ),
                const SizedBox(width: 12),

                // Duration Box
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duration (Mins) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: InputDecoration(
                          hintText: '60',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          errorText: _durationError,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // In-Person Mode Controls: Administered Date & HPS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date Administered *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDate(_scheduledDate),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Points (HPS) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _hpsPointsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: InputDecoration(
                          hintText: '100',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),

          // 5. Instructions & Guidelines (Mandatory with live counter & inline error)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Instructions & Guidelines *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              ),
              Text(
                '${_instructionsCtrl.text.length} / 1000',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _instructionsCtrl.text.length > 1000
                      ? const Color(0xFFDC2626)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _instructionsCtrl,
            maxLines: 3,
            maxLength: 1000,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Provide test-taking guidelines, permitted calculators/materials, and proctoring rules...',
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.all(12),
              errorText: _instructionsError,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _instructionsError != null
                      ? const Color(0xFFDC2626)
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: _instructionsError != null ? 1.5 : 1.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2.0),
              ),
              errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 18),

          // 6. Question Distributions (Only in Online Mode, 3 types max 3 digits)
          if (_completionMode == 'online') ...[
            Text(
              'Question Distributions (3 Types)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the planned number of questions per category (maximum 100 items total):',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _distributionError != null
                      ? const Color(0xFFDC2626)
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              ),
              child: Column(
                children: [
                  _buildDistributionRow('Multiple Choice', _mcCountCtrl),
                  const Divider(height: 12),
                  _buildDistributionRow('True or False', _tfCountCtrl),
                  const Divider(height: 12),
                  _buildDistributionRow('Identification', _idCountCtrl),
                ],
              ),
            ),
            if (_distributionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  _distributionError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items: $_totalPlannedQuestions / 100',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _totalPlannedQuestions > 100
                        ? const Color(0xFFDC2626)
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotButton({
    required String slot,
    required String label,
    required bool isCreated,
    required bool isEnabled,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final isSelected = _examCategory == slot;

    return Tooltip(
      message: tooltip ?? (isCreated ? 'Already configured' : 'Select $slot'),
      child: InkWell(
        onTap: (isEnabled && !isCreated) ? () => _setExamSlot(slot) : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.catRed.withValues(alpha: 0.1)
                : (isCreated
                    ? Colors.grey.shade100
                    : theme.colorScheme.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.catRed
                  : (isCreated
                      ? Colors.grey.shade300
                      : theme.colorScheme.outline.withValues(alpha: 0.3)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                slot,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppTheme.catRed
                      : (isCreated ? Colors.grey : theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 2),
              if (isCreated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Already Created',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                )
              else
                Text(
                  slot == 'TE' ? 'Term Exam' : 'Summative',
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionRow(String title, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 90,
          height: 38,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '0',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 2: QUESTION BUILDER (Active Editor + Matrix Navigator)
  // =========================================================================
  Widget _buildStep2QuestionBuilderView() {
    final theme = Theme.of(context);
    if (_plannedQuestions.isEmpty) {
      return const Center(child: Text('No questions configured.'));
    }

    final currentDraft = _plannedQuestions[_activeQuestionIndex];
    final qTypeLabel = switch (currentDraft.type) {
      QuestionType.multipleChoice => 'Multiple Choice',
      QuestionType.trueFalse => 'True / False',
      QuestionType.identification => 'Identification',
      QuestionType.matching => 'Matching',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Active Question Editor Card
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Editor Card Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppTheme.catRed,
                          child: Text(
                            '${currentDraft.position}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Question ${currentDraft.position} of ${_plannedQuestions.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            qTypeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Points field
                    Row(
                      children: [
                        const Text('Points:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 55,
                          height: 36,
                          child: TextField(
                            controller: _qPointsCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Question Statement Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Question Statement *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${_qStatementCtrl.text.length} / 500', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _qStatementCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Enter question text or problem statement...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Choices & Answer Key Setup based on type
                if (currentDraft.type == QuestionType.multipleChoice) ...[
                  const Text(
                    'Options & Answer Key (Fill all 4 and select the correct radio):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildMcChoiceRow('A', _choiceACtrl),
                  const SizedBox(height: 8),
                  _buildMcChoiceRow('B', _choiceBCtrl),
                  const SizedBox(height: 8),
                  _buildMcChoiceRow('C', _choiceCCtrl),
                  const SizedBox(height: 8),
                  _buildMcChoiceRow('D', _choiceDCtrl),
                ] else if (currentDraft.type == QuestionType.trueFalse) ...[
                  const Text(
                    'Correct Answer Key (Mandatory):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('True', style: TextStyle(fontWeight: FontWeight.bold)),
                          value: 'True',
                          groupValue: _selectedTfAnswer,
                          onChanged: (val) => setState(() => _selectedTfAnswer = val),
                          tileColor: _selectedTfAnswer == 'True'
                              ? AppTheme.catGreen.withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _selectedTfAnswer == 'True' ? AppTheme.catGreen : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('False', style: TextStyle(fontWeight: FontWeight.bold)),
                          value: 'False',
                          groupValue: _selectedTfAnswer,
                          onChanged: (val) => setState(() => _selectedTfAnswer = val),
                          tileColor: _selectedTfAnswer == 'False'
                              ? AppTheme.catRed.withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _selectedTfAnswer == 'False' ? AppTheme.catRed : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (currentDraft.type == QuestionType.identification) ...[
                  const Text(
                    'Official Correct Answer Key *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _qIdAnswerCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Mitochondria, Republic Act 10533, etc.',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],

                if (_editorError != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _editorError!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Stepper Buttons: Previous / Next
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_activeQuestionIndex > 0)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Previous Question'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          if (_saveCurrentEditorState()) {
                            _loadQuestionIntoEditor(_activeQuestionIndex - 1);
                          }
                        },
                      )
                    else
                      const SizedBox.shrink(),
                    if (_activeQuestionIndex < _plannedQuestions.length - 1)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Next Question'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () {
                          if (_saveCurrentEditorState()) {
                            _loadQuestionIntoEditor(_activeQuestionIndex + 1);
                          }
                        },
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Review Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.catGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () {
                          _saveCurrentEditorState();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Vertical divider
        Container(
          width: 1,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),

        // Right Column: Question Navigator Matrix (1..N)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question Navigator (${_plannedQuestions.length} Items)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Click any question number to edit. Delete is prohibited to preserve test integrity.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 12),

                // Question Chips Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _plannedQuestions.length,
                    itemBuilder: (ctx, i) {
                      final q = _plannedQuestions[i];
                      final isActive = i == _activeQuestionIndex;
                      final isDone = q.isComplete;

                      return InkWell(
                        onTap: () {
                          if (_saveCurrentEditorState()) {
                            _loadQuestionIntoEditor(i);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.colorScheme.primary
                                : (isDone
                                    ? AppTheme.catGreen.withValues(alpha: 0.15)
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : (isDone
                                      ? AppTheme.catGreen
                                      : Colors.grey.shade300),
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${q.position}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.white
                                  : (isDone ? AppTheme.catGreen : Colors.black87),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem('Done', AppTheme.catGreen),
                    _buildLegendItem('Active', theme.colorScheme.primary),
                    _buildLegendItem('Pending', Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMcChoiceRow(String label, TextEditingController controller) {
    final isCorrect = _selectedMcAnswer == label;

    return Row(
      children: [
        Radio<String>(
          value: label,
          groupValue: _selectedMcAnswer,
          onChanged: (val) => setState(() => _selectedMcAnswer = val),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Choice $label',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              fillColor: isCorrect ? AppTheme.catGreen.withValues(alpha: 0.05) : Colors.white,
              filled: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
