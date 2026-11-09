// Create Examination (EX) & Assessment Flow Dialog
// Fully redesigned to DepEd Order No. 015, s. 2026 standards.
// Features Online (Take via App) & In-Person (Manual Record), sequential slot
// locking (ST1 -> ST2 -> TE), split-box Date/Time/Duration, and category-isolated Question Builder.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/data/repositories/supabase_teacher_classwork_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';
import 'package:class_realm/widgets/common/app_duration_picker_field.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/widgets/anti_cheating_documentation_modal.dart';

/// Active draft of an individual question during step 2 authoring.
class QuestionDraft {
  final int position;
  final QuestionType type;
  String statement;
  List<String> choices; // 4 choices for multiple choice
  String
  correctAnswer; // 'A'/'B'/'C'/'D', 'True'/'False', or identification text
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
    if (statement.trim().length < 2) return false;
    if (points <= 0) return false;
    if (type == QuestionType.multipleChoice) {
      if (choices.length < 4 || choices.any((c) => c.trim().length < 2)) {
        return false;
      }
      return correctAnswer.isNotEmpty;
    } else if (type == QuestionType.trueFalse) {
      return correctAnswer == 'True' || correctAnswer == 'False';
    } else if (type == QuestionType.identification) {
      return correctAnswer.trim().length >= 2;
    }
    return false;
  }
}

class CreateAssessmentFlowDialog extends StatefulWidget {
  final VoidCallback onAssessmentCreated;
  final String initialSection;
  final String? initialSubject;
  final String? initialOfferingId;
  final List<Map<String, dynamic>>? initialOfferings;
  final TeacherClassworkRepository? repository;
  final bool initialIsExam;
  final bool skipTypeSelection;

  const CreateAssessmentFlowDialog({
    super.key,
    required this.onAssessmentCreated,
    this.initialSection = '',
    this.initialSubject,
    this.initialOfferingId,
    this.initialOfferings,
    this.repository,
    this.initialIsExam = false,
    this.skipTypeSelection = true,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAssessmentCreated,
    String? initialSection,
    String? initialSubject,
    String? initialOfferingId,
    List<Map<String, dynamic>>? initialOfferings,
    TeacherClassworkRepository? repository,
    bool initialIsExam = false,
    bool skipTypeSelection = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateAssessmentFlowDialog(
        onAssessmentCreated: onAssessmentCreated,
        initialSection: initialSection ?? '',
        initialSubject: initialSubject,
        initialOfferingId: initialOfferingId,
        initialOfferings: initialOfferings,
        repository: repository,
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

  bool get _isExam => widget.initialIsExam;

  // Mode: 'online' (Take via App) or 'in_person' (Manual Record)
  String _completionMode = 'online';

  // Slot: 'ST1', 'ST2', 'TE' (for Periodical Exams)
  String _examCategory = 'ST1';

  // Slot for Quiz (Written Works: WW 1..maxWwSlots)
  int _quizSlotIndex = 1;
  int _maxWwSlots = 3;
  Set<int> _occupiedWwSlots = <int>{};

  // Sequential slot statuses for selected offering (Exams)
  bool _st1Created = false;
  bool _st2Created = false;
  bool _teCreated = false;
  bool _isCheckingSlots = false;

  // Selected Offering & Active Term
  Map<String, dynamic>? _selectedOffering;
  List<Map<String, dynamic>> _teacherSubjects = [];
  bool _isLoadingOfferings = true;
  int _termNumber = 1;
  int _slotCheckRequestId = 0;

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
  String? _hpsPointsError;
  String? _distributionError;

  // Question distributions (3 types only, max 3 digits)
  final _mcCountCtrl = TextEditingController(text: '');
  final _tfCountCtrl = TextEditingController(text: '');
  final _idCountCtrl = TextEditingController(text: '');

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
    if (!_isExam) return false;
    if (_selectedOffering == null) return false;
    final exWeight =
        (_selectedOffering!['ex_weight'] as num?)?.toDouble() ?? 30.0;
    return exWeight == 0.0;
  }

  int get _totalPlannedQuestions {
    final mc = int.tryParse(_mcCountCtrl.text.trim()) ?? 0;
    final tf = int.tryParse(_tfCountCtrl.text.trim()) ?? 0;
    final id = int.tryParse(_idCountCtrl.text.trim()) ?? 0;
    return mc + tf + id;
  }

  bool get _areAllSlotsFilled => _isExam
      ? (_st1Created && _st2Created && _teCreated)
      : (_occupiedWwSlots.where((s) => s <= _maxWwSlots).length >= _maxWwSlots);

  @override
  void initState() {
    super.initState();
    _instructionsCtrl.addListener(() {
      if (_instructionsError != null) {
        setState(() => _instructionsError = null);
      }
    });
    _durationCtrl.addListener(() {
      final text = _durationCtrl.text.trim();
      if (text.isNotEmpty) {
        final d = int.tryParse(text);
        if (d != null && d > 180) {
          if (_durationError != 'Duration cannot exceed 180 minutes.') {
            setState(() => _durationError = 'Duration cannot exceed 180 minutes.');
          }
        } else if (_durationError != null) {
          setState(() => _durationError = null);
        }
      } else if (_durationError != null) {
        setState(() => _durationError = null);
      }
    });

    void syncDraft() {
      _syncCurrentDraftFromInputs();
      setState(() {});
    }

    _qStatementCtrl.addListener(syncDraft);
    _choiceACtrl.addListener(syncDraft);
    _choiceBCtrl.addListener(syncDraft);
    _choiceCCtrl.addListener(syncDraft);
    _choiceDCtrl.addListener(syncDraft);
    _qIdAnswerCtrl.addListener(syncDraft);
    if (widget.initialOfferings != null) {
      _teacherSubjects = List<Map<String, dynamic>>.from(
        widget.initialOfferings!,
      );
      _selectedOffering = _resolveInitialOffering(_teacherSubjects);
      if (_selectedOffering != null) {
        final terms = _getAvailableTermsForOffering(_selectedOffering);
        _termNumber = terms.isNotEmpty ? terms.first : 1;
      }
      _isLoadingOfferings = false;
      final offeringId = _selectedOffering?['id']?.toString() ?? '';
      if (offeringId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkSlotStatuses(offeringId);
        });
      }
    } else {
      _loadTeacherOfferings();
    }
  }

  String _termLabel(int term) {
    switch (term) {
      case 1:
        return '1st Term';
      case 2:
        return '2nd Term';
      case 3:
        return '3rd Term';
      default:
        return 'Term $term';
    }
  }

  List<int> _getAvailableTermsForOffering(Map<String, dynamic>? offering) {
    if (offering == null || offering.isEmpty) return const [1, 2, 3];

    int? termsTaught;
    String? termBlock;

    if (offering['terms_taught'] != null) {
      final tt = offering['terms_taught'];
      termsTaught = tt is int ? tt : int.tryParse(tt.toString());
    }
    if (offering['term_block'] != null) {
      termBlock = offering['term_block']?.toString();
    }

    final subjectName = offering['subject_name']?.toString().trim();
    if (termsTaught == null || termsTaught == 3) {
      if (subjectName != null && subjectName.isNotEmpty) {
        try {
          final catalogMatch = DepEdSubjectCatalog.allSubjects.firstWhere(
            (item) => item.name.toLowerCase() == subjectName.toLowerCase(),
          );
          termsTaught = catalogMatch.termsTaught;
        } catch (_) {}
      }
    }

    termsTaught ??= 3;
    termBlock ??= (termsTaught == 1
        ? '1ST'
        : (termsTaught == 2 ? '1ST & 2ND' : '1ST, 2ND, 3RD'));

    try {
      final active = DepEdSubjectCatalog.getActiveTermsForBlock(
        termsTaught.clamp(1, 3),
        termBlock,
      );
      if (active.isNotEmpty) return active;
    } catch (_) {
      if (termsTaught == 1) {
        final upper = termBlock.toUpperCase();
        if (upper.contains('3') || upper.contains('THIRD')) return const [3];
        if (upper.contains('2') || upper.contains('SECOND')) return const [2];
        return const [1];
      } else if (termsTaught == 2) {
        final upper = termBlock.toUpperCase();
        if (upper.contains('3') || upper.contains('2ND & 3RD')) {
          return const [2, 3];
        }
        return const [1, 2];
      }
    }
    return const [1, 2, 3];
  }

  Map<String, dynamic>? _resolveInitialOffering(
    List<Map<String, dynamic>> subjects,
  ) {
    if (subjects.isEmpty) return null;
    if (widget.initialOfferingId != null &&
        widget.initialOfferingId!.isNotEmpty) {
      final byId = subjects.firstWhere(
        (s) => s['id']?.toString() == widget.initialOfferingId,
        orElse: () => <String, dynamic>{},
      );
      if (byId.isNotEmpty) return byId;
    }
    if (widget.initialSection.isNotEmpty ||
        (widget.initialSubject != null && widget.initialSubject!.isNotEmpty)) {
      final byContext = subjects.firstWhere(
        (s) {
          final secOk =
              widget.initialSection.isEmpty ||
              s['section_name']?.toString().trim() ==
                  widget.initialSection.trim();
          final subOk =
              widget.initialSubject == null ||
              widget.initialSubject!.isEmpty ||
              s['subject_name']?.toString().trim() ==
                  widget.initialSubject!.trim();
          return secOk && subOk;
        },
        orElse: () => subjects.firstWhere(
          (s) =>
              widget.initialSection.isNotEmpty &&
              s['section_name']?.toString().trim() ==
                  widget.initialSection.trim(),
          orElse: () => subjects.first,
        ),
      );
      if (byContext.isNotEmpty) return byContext;
    }
    return subjects.first;
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
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        user.id,
      );
      if (!mounted) return;

      final initial = _resolveInitialOffering(subjects);
      final activeTerms = _getAvailableTermsForOffering(initial);

      setState(() {
        _teacherSubjects = subjects;
        _selectedOffering = initial != null && initial.isNotEmpty
            ? initial
            : null;
        if (activeTerms.isNotEmpty && !activeTerms.contains(_termNumber)) {
          _termNumber = activeTerms.first;
        }
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
    final reqId = ++_slotCheckRequestId;
    setState(() => _isCheckingSlots = true);
    try {
      final repo =
          widget.repository ?? SupabaseTeacherClassworkRepository.instance;
      final summary = await repo.getOccupiedSlots(
        subjectOfferingId: offeringId,
        termNumber: _termNumber,
      );
      if (!mounted || reqId != _slotCheckRequestId) return;

      if (!_isExam) {
        final occupied = summary.occupiedWwSlots;
        final maxWw = summary.maxWwSlot.clamp(3, 10);
        int firstAvailable = 1;
        for (int i = 1; i <= maxWw; i++) {
          if (!occupied.contains(i)) {
            firstAvailable = i;
            break;
          }
        }

        setState(() {
          _occupiedWwSlots = occupied;
          _maxWwSlots = maxWw;
          _quizSlotIndex = firstAvailable;
          _isCheckingSlots = false;
          if (_titleCtrl.text.isEmpty ||
              _titleCtrl.text.startsWith('Quiz ') ||
              _titleCtrl.text.startsWith('Summative')) {
            _titleCtrl.text = 'Quiz $firstAvailable';
          }
        });
        return;
      }

      setState(() {
        _st1Created = summary.st1Created;
        _st2Created = summary.st2Created;
        _teCreated = summary.teCreated;
        _isCheckingSlots = false;

        if (!summary.st1Created) {
          _setExamSlot('ST1');
        } else if (!summary.st2Created) {
          _setExamSlot('ST2');
        } else {
          _setExamSlot('TE');
        }
      });
    } catch (e) {
      debugPrint('Slot check notice: $e');
      if (mounted && reqId == _slotCheckRequestId) {
        setState(() => _isCheckingSlots = false);
      }
    }
  }

  void _setQuizSlot(int slot) {
    setState(() {
      _quizSlotIndex = slot;
      if (_titleCtrl.text.isEmpty ||
          _titleCtrl.text.startsWith('Quiz ') ||
          _titleCtrl.text.startsWith('Summative')) {
        _titleCtrl.text = 'Quiz $slot';
      }
    });
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
    final today = DateTime(
      now.year < 2026 ? 2026 : now.year,
      now.month,
      now.day,
    );
    final minDate = _completionMode == 'online'
        ? today
        : DateTime(today.year - 1, 1, 1);

    final picked = await showAppDatePickerDialog(
      context,
      initialDate: _scheduledDate.isBefore(minDate) ? minDate : _scheduledDate,
      firstDate: minDate,
      lastDate: DateTime(2100),
      title: _completionMode == 'online'
          ? 'Select Scheduled Date'
          : 'Set Date',
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

    if (_isExam && _isZeroExamSubject) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Zero-Exam Subject',
        message: 'This subject has no Examination component under DepEd Order No. 015, s. 2026. Initial Grades are computed 100% from Written Works and Performance Tasks.',
      );
      return;
    }

    if (_areAllSlotsFilled) {
      AppModals.showErrorDialog(
        context: context,
        title: _isExam ? 'All Examination Slots Filled' : 'All Written Work Slots Filled',
        message: _isExam
            ? 'All examination slots (ST1, ST2, TE) are already configured for this offering.'
            : 'All 10 Written Work slots are already configured for this offering.',
      );
      return;
    }

    final instrErr = AppValidators.validateClassworkInstructions(
      _instructionsCtrl.text,
    );
    if (instrErr != null) {
      setState(() {
        _instructionsError = instrErr;
      });
      return;
    }

    if (_completionMode == 'in_person') {
      final hpsText = _hpsPointsCtrl.text.trim();
      final hps = int.tryParse(hpsText);
      if (hps == null || hps < 1 || hps > 100) {
        setState(() {
          _hpsPointsError = hps == 0
              ? 'HPS cannot be 0. Must be 1 to 100.'
              : 'Total Points (HPS) must be between 1 and 100.';
        });
        return;
      }
      setState(() => _hpsPointsError = null);
      _publishInPersonExam(hps);
      return;
    }

    // Online Mode validations
    final scheduledDateTime = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickedDay = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
    );
    if (pickedDay.isBefore(today) ||
        scheduledDateTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
      setState(
        () => _dateError =
            'Scheduled start date and time cannot be in the past.',
      );
      return;
    }

    final duration = int.tryParse(_durationCtrl.text.trim());
    if (duration == null || duration < 1) {
      setState(() => _durationError = 'Duration must be at least 1 minute.');
      return;
    }
    if (duration > 180) {
      setState(() => _durationError = 'Duration cannot exceed 180 minutes.');
      return;
    }

    final mc = int.tryParse(_mcCountCtrl.text.trim()) ?? 0;
    final tf = int.tryParse(_tfCountCtrl.text.trim()) ?? 0;
    final id = int.tryParse(_idCountCtrl.text.trim()) ?? 0;
    final total = mc + tf + id;

    if (total == 0) {
      setState(
        () => _distributionError = 'Please configure at least 1 question.',
      );
      return;
    }
    if (total > 100) {
      setState(
        () => _distributionError =
            'Total questions cannot exceed 100 items ($total / 100).',
      );
      return;
    }

    if (_plannedQuestions.isNotEmpty) {
      // Logic for Back Button Adjustments
      final existingMc = _plannedQuestions
          .where((q) => q.type == QuestionType.multipleChoice)
          .toList();
      final existingTf = _plannedQuestions
          .where((q) => q.type == QuestionType.trueFalse)
          .toList();
      final existingId = _plannedQuestions
          .where((q) => q.type == QuestionType.identification)
          .toList();

      if (mc < existingMc.length ||
          tf < existingTf.length ||
          id < existingId.length) {
        // Reduced count - needs confirmation modal
        _showCountReductionWarning(
          mc,
          tf,
          id,
          existingMc,
          existingTf,
          existingId,
        );
        return;
      } else {
        _applyQuestionCountAdjustments(
          mc,
          tf,
          id,
          existingMc,
          existingTf,
          existingId,
        );
        setState(() => _currentStep = 2);
        return;
      }
    }

    final drafts = <QuestionDraft>[];
    int pos = 1;
    for (int i = 0; i < mc; i++) {
      drafts.add(
        QuestionDraft(position: pos++, type: QuestionType.multipleChoice),
      );
    }
    for (int i = 0; i < tf; i++) {
      drafts.add(QuestionDraft(position: pos++, type: QuestionType.trueFalse));
    }
    for (int i = 0; i < id; i++) {
      drafts.add(
        QuestionDraft(position: pos++, type: QuestionType.identification),
      );
    }

    setState(() {
      _plannedQuestions = drafts;
      _activeQuestionIndex = 0;
      _currentStep = 2;
    });

    _loadQuestionIntoEditor(0);
  }

  void _applyQuestionCountAdjustments(
    int targetMc,
    int targetTf,
    int targetId,
    List<QuestionDraft> exMc,
    List<QuestionDraft> exTf,
    List<QuestionDraft> exId,
  ) {
    // Create new list preserving order Part 1 -> Part 2 -> Part 3
    final newDrafts = <QuestionDraft>[];
    int pos = 1;

    // Multiple Choice
    for (int i = 0; i < targetMc; i++) {
      if (i < exMc.length) {
        newDrafts.add(
          QuestionDraft(
            position: pos++,
            type: QuestionType.multipleChoice,
            statement: exMc[i].statement,
            choices: exMc[i].choices,
            correctAnswer: exMc[i].correctAnswer,
            points: exMc[i].points,
          ),
        );
      } else {
        newDrafts.add(
          QuestionDraft(position: pos++, type: QuestionType.multipleChoice),
        );
      }
    }

    // True/False
    for (int i = 0; i < targetTf; i++) {
      if (i < exTf.length) {
        newDrafts.add(
          QuestionDraft(
            position: pos++,
            type: QuestionType.trueFalse,
            statement: exTf[i].statement,
            correctAnswer: exTf[i].correctAnswer,
            points: exTf[i].points,
          ),
        );
      } else {
        newDrafts.add(
          QuestionDraft(position: pos++, type: QuestionType.trueFalse),
        );
      }
    }

    // Identification
    for (int i = 0; i < targetId; i++) {
      if (i < exId.length) {
        newDrafts.add(
          QuestionDraft(
            position: pos++,
            type: QuestionType.identification,
            statement: exId[i].statement,
            correctAnswer: exId[i].correctAnswer,
            points: exId[i].points,
          ),
        );
      } else {
        newDrafts.add(
          QuestionDraft(position: pos++, type: QuestionType.identification),
        );
      }
    }

    setState(() {
      _plannedQuestions = newDrafts;
      if (_activeQuestionIndex >= _plannedQuestions.length) {
        _activeQuestionIndex = _plannedQuestions.length - 1;
      }
    });
    _loadQuestionIntoEditor(_activeQuestionIndex);
  }

  void _showCountReductionWarning(
    int targetMc,
    int targetTf,
    int targetId,
    List<QuestionDraft> exMc,
    List<QuestionDraft> exTf,
    List<QuestionDraft> exId,
  ) {
    int reducedMc = exMc.length > targetMc ? exMc.length - targetMc : 0;
    int reducedTf = exTf.length > targetTf ? exTf.length - targetTf : 0;
    int reducedId = exId.length > targetId ? exId.length - targetId : 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reduce Questions?'),
        content: Text(
          'You reduced the number of questions. The last '
          '${reducedMc > 0 ? '$reducedMc MC, ' : ''}'
          '${reducedTf > 0 ? '$reducedTf TF, ' : ''}'
          '${reducedId > 0 ? '$reducedId ID ' : ''}'
          'question(s) will be permanently deleted. Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close modal
              // Revert counters in UI
              setState(() {
                _mcCountCtrl.text = exMc.length.toString();
                _tfCountCtrl.text = exTf.length.toString();
                _idCountCtrl.text = exId.length.toString();
              });
            },
            child: const Text('Cancel'),
          ),
          AppButton.danger(
            label: 'Proceed',
            onPressed: () {
              Navigator.pop(ctx); // Close modal
              _applyQuestionCountAdjustments(
                targetMc,
                targetTf,
                targetId,
                exMc,
                exTf,
                exId,
              );
              setState(() => _currentStep = 2);
            },
          ),
        ],
      ),
    );
  }

  bool _isLoadingQuestion = false;

  void _syncCurrentDraftFromInputs() {
    if (_isLoadingQuestion) return;
    if (_activeQuestionIndex < 0 ||
        _activeQuestionIndex >= _plannedQuestions.length) {
      return;
    }
    final q = _plannedQuestions[_activeQuestionIndex];
    q.statement = _qStatementCtrl.text;
    q.points = 1.0;
    if (q.type == QuestionType.multipleChoice) {
      q.choices = [
        _choiceACtrl.text,
        _choiceBCtrl.text,
        _choiceCCtrl.text,
        _choiceDCtrl.text,
      ];
      q.correctAnswer = _selectedMcAnswer ?? '';
    } else if (q.type == QuestionType.trueFalse) {
      q.choices = ['True', 'False'];
      q.correctAnswer = _selectedTfAnswer ?? '';
    } else if (q.type == QuestionType.identification) {
      q.correctAnswer = _qIdAnswerCtrl.text;
    }
  }

  void _loadQuestionIntoEditor(int index) {
    if (index < 0 || index >= _plannedQuestions.length) return;
    final q = _plannedQuestions[index];
    _isLoadingQuestion = true;
    setState(() {
      _activeQuestionIndex = index;
      _qStatementCtrl.text = q.statement;
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
    _isLoadingQuestion = false;
  }

  bool _saveCurrentEditorState() {
    if (_activeQuestionIndex < 0 ||
        _activeQuestionIndex >= _plannedQuestions.length) {
      return false;
    }
    final q = _plannedQuestions[_activeQuestionIndex];
    final statement = _qStatementCtrl.text.trim();
    if (statement.length < 2) {
      setState(
        () =>
            _editorError = 'Question statement must be at least 2 characters.',
      );
      return false;
    }

    q.points = 1.0;

    if (q.type == QuestionType.multipleChoice) {
      final a = _choiceACtrl.text.trim();
      final b = _choiceBCtrl.text.trim();
      final c = _choiceCCtrl.text.trim();
      final d = _choiceDCtrl.text.trim();
      if (a.length < 2 || b.length < 2 || c.length < 2 || d.length < 2) {
        setState(
          () => _editorError =
              'All 4 choices (A, B, C, D) are required (min 2 characters each).',
        );
        return false;
      }
      if (_selectedMcAnswer == null || _selectedMcAnswer!.isEmpty) {
        setState(
          () => _editorError = 'Please select the correct answer radio.',
        );
        return false;
      }
      q.statement = statement;
      q.choices = [a, b, c, d];
      q.correctAnswer = _selectedMcAnswer!;
    } else if (q.type == QuestionType.trueFalse) {
      if (_selectedTfAnswer == null || _selectedTfAnswer!.isEmpty) {
        setState(
          () => _editorError = 'Please select True or False as the answer key.',
        );
        return false;
      }
      q.statement = statement;
      q.choices = ['True', 'False'];
      q.correctAnswer = _selectedTfAnswer!;
    } else if (q.type == QuestionType.identification) {
      final key = _qIdAnswerCtrl.text.trim();
      if (key.length < 2) {
        setState(
          () => _editorError =
              'Please specify the official answer key for identification (min 2 characters).',
        );
        return false;
      }
      q.statement = statement;
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
        'questions': _plannedQuestions
            .map(
              (q) => {
                'position': q.position,
                'type': q.type.name,
                'statement': q.statement,
                'choices': q.choices,
                'correctAnswer': q.correctAnswer,
                'points': q.points,
              },
            )
            .toList(),
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

      final slotIndex = _isExam
          ? switch (_examCategory) {
              'ST2' => 2,
              'TE' => 3,
              _ => 1,
            }
          : _quizSlotIndex;

      final category = _isExam ? 'ex' : 'ww';
      final repo =
          widget.repository ?? SupabaseTeacherClassworkRepository.instance;
      final alreadyUsed = await repo.isGradebookSlotOccupied(
        subjectOfferingId: offeringId,
        gradingCategory: category,
        termNumber: _termNumber,
        gradebookColumnIndex: slotIndex,
      );
      if (alreadyUsed) {
        if (mounted) {
          setState(() => _isPublishing = false);
          await _checkSlotStatuses(offeringId);
          if (mounted) {
            AppModals.showWarningDialog(
              context: context,
              title: 'Slot Already Occupied',
              message: _isExam
                  ? '$_examCategory was already created in the database for ${_termLabel(_termNumber)}. Please use the next available slot.'
                  : 'WW $_quizSlotIndex is already occupied in the database for ${_termLabel(_termNumber)}. Please select an available slot.',
            );
          }
        }
        return;
      }

      final dateUtc = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        23,
        59,
      ).toUtc();

      // 1. Insert into classwork_items
      await client.from('classwork_items').insert({
        'subject_offering_id': offeringId,
        'classwork_type': _isExam ? 'exam' : 'quiz',
        'grading_category': category,
        'title': title,
        'instructions': instructions,
        'max_score': hpsPoints,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
        'deadline': dateUtc.toIso8601String(),
        'completion_mode': 'in_person',
        'term_number': _termNumber,
        'gradebook_column_index': slotIndex,
        'allow_late_submission': false,
        'is_archived': false,
        'is_published': true,
      });

      // 2. Synchronize Gradebook Term Sheet HPS
      final termSheet =
          await SubjectRepository.instance.getGradebookTermSheet(
            offeringId,
            _termNumber,
          ) ??
          {};
      final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
      if (_isExam) {
        final exHps = Map<String, dynamic>.from(hps['ex'] as Map? ?? {});
        exHps[_examCategory.toLowerCase()] = hpsPoints;
        hps['ex'] = exHps;
      } else {
        final wwHps = Map<String, dynamic>.from(hps['ww'] as Map? ?? {});
        wwHps[_quizSlotIndex.toString()] = hpsPoints;
        hps['ww'] = wwHps;
      }
      termSheet['hps'] = hps;
      termSheet['scores'] ??= <String, dynamic>{};
      await SubjectRepository.instance.saveGradebookTermSheet(
        offeringId,
        _termNumber,
        termSheet,
      );

      AppDataCache.instance.invalidatePrefix('gradebook_');
      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
      TeacherGradebookTab.gradebookRefreshNotifier.value++;

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAssessmentCreated();

      AppModals.showSuccessDialog(
        context: context,
        title: _isExam ? 'Examination Recorded' : 'Quiz Recorded',
        message: _isExam
            ? '$title has been saved in Gradebook as an In-Person examination with $hpsPoints total points.'
            : '$title has been saved in Gradebook as an In-Person quiz with $hpsPoints total points under Written Works (WW $_quizSlotIndex).',
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
        message:
            'Question #${incomplete.first.position} is missing its statement or answer key. Please review all items.',
      );
      _loadQuestionIntoEditor(incomplete.first.position - 1);
      return;
    }

    if (_selectedOffering == null) return;
    setState(() => _isPublishing = true);

    String? createdAssessmentId;
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

      final slotIndex = _isExam
          ? switch (_examCategory) {
              'ST2' => 2,
              'TE' => 3,
              _ => 1,
            }
          : _quizSlotIndex;

      final category = _isExam ? 'ex' : 'ww';
      final repo =
          widget.repository ?? SupabaseTeacherClassworkRepository.instance;
      final alreadyUsed = await repo.isGradebookSlotOccupied(
        subjectOfferingId: offeringId,
        gradingCategory: category,
        termNumber: _termNumber,
        gradebookColumnIndex: slotIndex,
      );
      if (alreadyUsed) {
        if (mounted) {
          setState(() => _isPublishing = false);
          await _checkSlotStatuses(offeringId);
          if (mounted) {
            AppModals.showWarningDialog(
              context: context,
              title: 'Slot Already Occupied',
              message: _isExam
                  ? '$_examCategory was already created in the database for ${_termLabel(_termNumber)}. Please review the active slot before publishing.'
                  : 'WW $_quizSlotIndex is already occupied in the database for ${_termLabel(_termNumber)}. Please select an available slot.',
            );
          }
        }
        return;
      }

      final assessType = _isExam
          ? switch (_examCategory) {
              'ST2' => 'st2',
              'TE' => 'term_exam',
              _ => 'st1',
            }
          : 'quiz';

      final totalPoints = _plannedQuestions.fold<double>(
        0.0,
        (sum, q) => sum + q.points,
      );

      // 1. Create digital_assessments record
      final assessmentRow = await client
          .from('digital_assessments')
          .insert({
            'subject_offering_id': offeringId,
            'assessment_type': assessType,
            'grading_category': category,
            'title': title,
            'instructions': instructions,
            'time_limit_minutes': duration,
            'available_from': startDateTime.toUtc().toIso8601String(),
            'deadline': deadline.toUtc().toIso8601String(),
            'attempts_allowed': 1,
            'is_published': true,
          })
          .select()
          .single();

      final assessmentId = assessmentRow['id'].toString();
      createdAssessmentId = assessmentId;

      // 2. Insert assessment_questions & assessment_question_options using position
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
          final optionRows = <Map<String, dynamic>>[];
          for (int i = 0; i < 4; i++) {
            optionRows.add({
              'question_id': qId,
              'position': i + 1,
              'option_text': q.choices[i],
              'is_correct': q.correctAnswer == labels[i],
            });
          }
          await client.from('assessment_question_options').insert(optionRows);
        } else if (q.type == QuestionType.trueFalse) {
          await client.from('assessment_question_options').insert([
            {
              'question_id': qId,
              'position': 1,
              'option_text': 'True',
              'is_correct': q.correctAnswer == 'True',
            },
            {
              'question_id': qId,
              'position': 2,
              'option_text': 'False',
              'is_correct': q.correctAnswer == 'False',
            },
          ]);
        } else if (q.type == QuestionType.identification) {
          await client.from('assessment_question_options').insert({
            'question_id': qId,
            'position': 1,
            'option_text': q.correctAnswer,
            'is_correct': true,
          });
        }
      }

      // 3. Persist to classwork_items (shared ID for single source of truth)
      await client.from('classwork_items').insert({
        'id': assessmentId,
        'subject_offering_id': offeringId,
        'classwork_type': _isExam ? 'exam' : 'quiz',
        'grading_category': category,
        'title': title,
        'instructions': instructions,
        'max_score': totalPoints.toInt(),
        'assigned_at': startDateTime.toUtc().toIso8601String(),
        'deadline': deadline.toUtc().toIso8601String(),
        'completion_mode': 'online',
        'term_number': _termNumber,
        'gradebook_column_index': slotIndex,
        'allow_late_submission': false,
        'is_archived': false,
        'is_published': true,
      });

      // 4. Update Gradebook Sheet HPS for the active term
      final termSheet =
          await SubjectRepository.instance.getGradebookTermSheet(
            offeringId,
            _termNumber,
          ) ??
          {};
      final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
      if (_isExam) {
        final exHps = Map<String, dynamic>.from(hps['ex'] as Map? ?? {});
        exHps[_examCategory.toLowerCase()] = totalPoints.toInt();
        hps['ex'] = exHps;
      } else {
        final wwHps = Map<String, dynamic>.from(hps['ww'] as Map? ?? {});
        wwHps[_quizSlotIndex.toString()] = totalPoints.toInt();
        hps['ww'] = wwHps;
      }
      termSheet['hps'] = hps;
      termSheet['scores'] ??= <String, dynamic>{};
      await SubjectRepository.instance.saveGradebookTermSheet(
        offeringId,
        _termNumber,
        termSheet,
      );

      // Clean local draft & refresh caches
      AppDataCache.instance.invalidate(
        _isExam
            ? 'exam_draft_${offeringId}_$_examCategory'
            : 'quiz_draft_${offeringId}_$_quizSlotIndex',
      );
      AppDataCache.instance.invalidatePrefix('gradebook_');
      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
      TeacherGradebookTab.gradebookRefreshNotifier.value++;

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAssessmentCreated();

      AppModals.showSuccessDialog(
        context: context,
        title: _isExam ? 'Examination Published' : 'Quiz Published',
        message: _isExam
            ? '$title has been published for ${_selectedOffering!['section_name']} (${_termLabel(_termNumber)}). Scheduled for ${_formatDate(_scheduledDate)} at ${AppTimePickerField.format(_startTime)} (${duration}m duration).'
            : '$title has been published for ${_selectedOffering!['section_name']} (${_termLabel(_termNumber)}) under Written Works (WW $_quizSlotIndex). Scheduled for ${_formatDate(_scheduledDate)} at ${AppTimePickerField.format(_startTime)} (${duration}m duration).',
      );
    } catch (e) {
      // Rollback any partially created records so orphan rows never remain in DB (child-first cascade)
      if (createdAssessmentId != null) {
        final client = SupabaseService().client;
        try {
          final qRows = await client
              .from('assessment_questions')
              .select('id')
              .eq('assessment_id', createdAssessmentId);
          final qIds = (qRows as List).map((r) => r['id'].toString()).toList();
          if (qIds.isNotEmpty) {
            await client
                .from('assessment_question_options')
                .delete()
                .inFilter('question_id', qIds);
          }
        } catch (_) {}
        try {
          await client
              .from('assessment_questions')
              .delete()
              .eq('assessment_id', createdAssessmentId);
        } catch (_) {}
        try {
          await client
              .from('classwork_items')
              .delete()
              .eq('id', createdAssessmentId);
        } catch (_) {}
        try {
          await client
              .from('digital_assessments')
              .delete()
              .eq('id', createdAssessmentId);
        } catch (_) {}
      }
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

  bool _hasUnsavedChanges() {
    if (_currentStep == 1) {
      if (_instructionsCtrl.text.trim().isNotEmpty) return true;
      if (_mcCountCtrl.text != '0' && _mcCountCtrl.text.isNotEmpty) return true;
      if (_tfCountCtrl.text != '0' && _tfCountCtrl.text.isNotEmpty) return true;
      if (_idCountCtrl.text != '0' && _idCountCtrl.text.isNotEmpty) return true;
      return false;
    } else {
      // Step 2 always has generated questions
      return _plannedQuestions.any((q) => q.statement.trim().isNotEmpty);
    }
  }

  void _handleClose() {
    if (_hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard Assessment?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to close this? Your progress will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Editing'),
            ),
            AppPrimaryButton(
              label: 'Discard',
              icon: Icons.delete_outline,
              backgroundColor: const Color(
                0xFFDC2626,
              ), // Keep discard action red
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _openAiGeneration() {
    AppModals.showUpcomingFeatureDialog(
      context,
      featureName: 'AI Exam Question Generator',
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_isExam ? AppTheme.catRed : theme.colorScheme.primary).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isExam ? Icons.description_outlined : Icons.quiz_outlined,
                      color: _isExam ? AppTheme.catRed : theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isExam ? 'Configure Periodical Examination' : 'Configure Quiz',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentStep == 1
                              ? (_isExam
                                    ? 'Set method, slot, schedule, instructions, and distributions'
                                    : 'Set method, WW slot, schedule, instructions, and distributions')
                              : 'Question Builder — Author statements and mandatory answer keys',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: _handleClose,
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
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                    : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
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
                      if (_currentStep == 1) ...[
                        TextButton(
                          onPressed: _handleClose,
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        AppPrimaryButton(
                          label: _completionMode == 'in_person'
                              ? (_isPublishing
                                    ? 'Publishing...'
                                    : (_isExam ? 'Publish Examination' : 'Publish Quiz'))
                              : 'Continue',
                          icon: _completionMode == 'in_person'
                              ? Icons.publish
                              : Icons.arrow_forward,
                          height: 42,
                          backgroundColor:
                              theme.colorScheme.primary, // 30% Primary
                          onPressed:
                              (_areAllSlotsFilled ||
                                  _isPublishing ||
                                  (_completionMode == 'online' &&
                                      (_totalPlannedQuestions == 0 ||
                                          _totalPlannedQuestions > 100)))
                              ? null
                              : _handleContinueOrPublish,
                        ),
                      ],
                      if (_currentStep == 2) ...[
                        Builder(
                          builder: (context) {
                            final bool areAllQuestionsComplete =
                                _plannedQuestions.isNotEmpty &&
                                _plannedQuestions.every((q) => q.isComplete);
                            return AppPrimaryButton(
                              label: _isPublishing
                                  ? (_isExam
                                      ? 'Publishing Examination...'
                                      : 'Publishing Quiz...')
                                  : (_isExam
                                      ? 'Publish Examination'
                                      : 'Publish Quiz'),
                              icon: Icons.check_circle_outline,
                              height: 42,
                              backgroundColor: theme.colorScheme.primary,
                              onPressed: (_isPublishing || !areAllQuestionsComplete)
                                  ? null
                                  : _publishOnlineExam,
                            );
                          },
                        ),
                      ],
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
    final isDark = theme.brightness == Brightness.dark;

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
              border: Border.all(
                color: AppTheme.catPurple.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.catPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppTheme.catPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _isExam
                                  ? 'Generate Examination with Gemini AI'
                                  : 'Generate Quiz with Gemini AI',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.catPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NEXT UPDATE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.catPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload syllabus files (.pdf, .docx) to auto-generate questions and answer keys.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Generate with AI (Next Update)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.catPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _completionMode = 'online'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _completionMode == 'online'
                            ? (isDark
                                ? theme.colorScheme.surfaceContainerHighest
                                : Colors.white)
                            : Colors.transparent,
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
                            color: _completionMode == 'online'
                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48))
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Online (Take via App)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _completionMode == 'online'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _completionMode == 'online'
                                  ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48))
                                  : theme.colorScheme.onSurfaceVariant,
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
                        color: _completionMode == 'in_person'
                            ? (isDark
                                ? theme.colorScheme.surfaceContainerHighest
                                : Colors.white)
                            : Colors.transparent,
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
                            Icons.group,
                            size: 16,
                            color: _completionMode == 'in_person'
                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48))
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'In-Person (Manual Record)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _completionMode == 'in_person'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _completionMode == 'in_person'
                                  ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48))
                                  : theme.colorScheme.onSurfaceVariant,
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

          // 2. Target Section Chip (Static centered badge, NO dropdown, matching Create PT)
          if (_isLoadingOfferings)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_selectedOffering != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F8A48).withValues(alpha: 0.15)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF0F8A48).withValues(alpha: isDark ? 0.4 : 0.2),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Grade ${_selectedOffering!['grade_level'] ?? 11} • ${_selectedOffering!['subject_name'] ?? 'Subject'} • ${_selectedOffering!['section_name'] ?? 'Section'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // 2b. Gradebook Term Selector / Display
          if (_selectedOffering != null) ...[
            Builder(
              builder: (context) {
                final availableTerms = _getAvailableTermsForOffering(
                  _selectedOffering,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gradebook Term *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (availableTerms.length <= 1)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          _termLabel(_termNumber),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: availableTerms.contains(_termNumber)
                            ? _termNumber
                            : availableTerms.first,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                        items: availableTerms
                            .map(
                              (t) => DropdownMenuItem<int>(
                                value: t,
                                child: Text(
                                  _termLabel(t),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (newTerm) {
                          if (newTerm != null && newTerm != _termNumber) {
                            setState(() => _termNumber = newTerm);
                            final offId =
                                _selectedOffering?['id']?.toString() ?? '';
                            if (offId.isNotEmpty) {
                              _checkSlotStatuses(offId);
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],

          // 3. Slot Selector: ST1 -> ST2 -> TE for Exam, or WW Slots for Quiz
          if (_isExam) ...[
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
              _buildSlotSkeletonRow(theme)
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
                  color: isDark ? AppTheme.catOrange.withValues(alpha: 0.12) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.catOrange.withValues(alpha: 0.3) : Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark ? AppTheme.catOrange : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All examination slots (ST1, ST2, TE) are already configured for this offering.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.catOrange : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Text(
              'Written Work Slot (Gradebook) *',
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
              _buildQuizSlotSelector(theme),
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _dateError != null
                                  ? const Color(0xFFDC2626)
                                  : theme.colorScheme.outline.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDate(_scheduledDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_dateError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            _dateError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626),
                            ),
                          ),
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

                // Duration Box (AppDurationPickerField with max 180m and quick presets)
                Expanded(
                  flex: 3,
                  child: AppDurationPickerField(
                    label: 'Duration (Mins) *',
                    initialDurationMinutes: int.tryParse(_durationCtrl.text.trim()) ?? 60,
                    onDurationSelected: (mins) {
                      setState(() {
                        _durationCtrl.text = mins.toString();
                        _durationError = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            // In-Person Mode Controls: Set Date & HPS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Date *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDate(_scheduledDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _hpsPointsCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          if (_hpsPointsError != null) {
                            setState(() => _hpsPointsError = null);
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: InputDecoration(
                          hintText: '1 to 100',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          errorText: _hpsPointsError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC2626),
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC2626),
                              width: 2.0,
                            ),
                          ),
                          errorStyle: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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

          // 5. Instructions & Guidelines (2 lines + See more / See less + min 2 chars)
          ExpandableInstructionsInputField(
            controller: _instructionsCtrl,
            label: 'Instructions & Guidelines *',
            hint:
                'e.g. Provide test-taking guidelines, no calculators allowed...',
            errorText: _instructionsError,
          ),
          if (_completionMode == 'online') ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  AntiCheatingDocumentationModal.show(context);
                },
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text(
                  'View Complete Anti-Cheating & Exam Taking Guidelines',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),

          // 6. Question Distributions (Only in Online Mode, 3 types max 3 digits)
          if (_completionMode == 'online') ...[
            Text(
              'Question Distributions (3 Types)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the planned number of questions per category (maximum 100 items total):',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.2,
                ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w500,
                  ),
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

  Widget _buildSlotSkeletonRow(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final skeletonColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : Colors.grey.shade100;
    final borderColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.15)
        : Colors.grey.shade300;

    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index > 0 ? 5.0 : 0.0,
              right: index < 2 ? 5.0 : 0.0,
            ),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Container(
                  width: 44,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
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
    final isDark = theme.brightness == Brightness.dark;
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
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : (isCreated
                      ? (isDark
                          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
                          : Colors.grey.shade100)
                      : theme.colorScheme.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isCreated
                        ? (isDark
                            ? theme.colorScheme.outline.withValues(alpha: 0.15)
                            : Colors.grey.shade300)
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
                      ? theme.colorScheme.primary
                      : (isCreated
                          ? (isDark ? Colors.grey.shade500 : Colors.grey)
                          : theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 2),
              if (isCreated)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Already Created',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade300 : Colors.black54,
                    ),
                  ),
                )
              else
                Text(
                  slot == 'TE' ? 'Term Exam' : 'Summative',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizSlotSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_maxWwSlots, (idx) {
            final slot = idx + 1;
            final isOccupied = _occupiedWwSlots.contains(slot);
            final isSelected = _quizSlotIndex == slot;

            return Tooltip(
              message: isOccupied
                  ? 'WW $slot is already used in Gradebook/Classwork'
                  : 'Select WW $slot for this Quiz',
              child: InkWell(
                onTap: isOccupied ? null : () => _setQuizSlot(slot),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : (isOccupied
                            ? Colors.grey.shade100
                            : theme.colorScheme.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isOccupied
                              ? Colors.grey.shade300
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                )),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WW $slot',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isOccupied
                                  ? Colors.grey
                                  : theme.colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOccupied
                            ? 'Occupied'
                            : (isSelected ? 'Selected' : 'Available'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isOccupied
                                  ? Colors.grey
                                  : Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All 10 Written Work (WW) slots are already configured for this offering.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDistributionRow(String title, TextEditingController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          width: 90,
          height: 38,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                fontWeight: FontWeight.normal,
              ),
              filled: true,
              fillColor: isDark
                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            'Q${currentDraft.position}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Question ${currentDraft.position} of ${_plannedQuestions.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '1 Point',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Question Statement Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question Statement *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${_qStatementCtrl.text.length} / 500',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _qStatementCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => const SizedBox.shrink(),
                  onChanged: (_) {
                    _syncCurrentDraftFromInputs();
                    setState(() {});
                  },
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter question text or problem statement...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                        : Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(
                          alpha: theme.brightness == Brightness.dark ? 0.3 : 0.2,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Choices & Answer Key Setup based on type
                if (currentDraft.type == QuestionType.multipleChoice) ...[
                  Text(
                    'Options & Answer Key (Fill all 4 and select the correct radio):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
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
                  Text(
                    'Correct Answer Key (Mandatory):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTfAnswer = 'True';
                              _syncCurrentDraftFromInputs();
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTfAnswer == 'True'
                                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                  : (theme.brightness == Brightness.dark
                                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                                      : theme.colorScheme.surface),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedTfAnswer == 'True'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                                width: _selectedTfAnswer == 'True' ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'True',
                                  groupValue: _selectedTfAnswer,
                                  activeColor: theme.colorScheme.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedTfAnswer = val;
                                      _syncCurrentDraftFromInputs();
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'True',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _selectedTfAnswer == 'True'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTfAnswer = 'False';
                              _syncCurrentDraftFromInputs();
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTfAnswer == 'False'
                                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                  : (theme.brightness == Brightness.dark
                                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                                      : theme.colorScheme.surface),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedTfAnswer == 'False'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                                width: _selectedTfAnswer == 'False' ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'False',
                                  groupValue: _selectedTfAnswer,
                                  activeColor: theme.colorScheme.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedTfAnswer = val;
                                      _syncCurrentDraftFromInputs();
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'False',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _selectedTfAnswer == 'False'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (currentDraft.type ==
                    QuestionType.identification) ...[
                  Text(
                    'Official Correct Answer Key *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _qIdAnswerCtrl,
                    onChanged: (_) {
                      _syncCurrentDraftFromInputs();
                      setState(() {});
                    },
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Mitochondria, Republic Act 10533, etc.',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.vpn_key_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: theme.brightness == Brightness.dark ? 0.3 : 0.2,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],

                if (_editorError != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _editorError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w500,
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
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
                          backgroundColor:
                              theme.colorScheme.primary, // 30% primary theme
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Click any question number to edit. Delete is prohibited to preserve test integrity.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),

                // Question Chips List grouped by type
                Expanded(
                  child: ListView(
                    children: [
                      _buildQuestionNavigatorCategory(
                        'Multiple Choice',
                        QuestionType.multipleChoice,
                      ),
                      const SizedBox(height: 12),
                      _buildQuestionNavigatorCategory(
                        'True or False',
                        QuestionType.trueFalse,
                      ),
                      const SizedBox(height: 12),
                      _buildQuestionNavigatorCategory(
                        'Identification',
                        QuestionType.identification,
                      ),
                    ],
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

  Widget _buildQuestionNavigatorCategory(String title, QuestionType type) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryQuestions = <int>[];
    for (int i = 0; i < _plannedQuestions.length; i++) {
      if (_plannedQuestions[i].type == type) {
        categoryQuestions.add(i);
      }
    }

    if (categoryQuestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: categoryQuestions.map((index) {
            final q = _plannedQuestions[index];
            final isActive = index == _activeQuestionIndex;
            final isDone = q.isComplete;

            final Color chipBg = isActive
                ? theme.colorScheme.primary
                : (isDone
                    ? AppTheme.catGreen.withValues(alpha: isDark ? 0.2 : 0.12)
                    : (isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                        : Colors.grey.shade200));

            final Color chipBorder = isActive
                ? theme.colorScheme.primary
                : (isDone
                    ? AppTheme.catGreen
                    : (isDark
                        ? theme.colorScheme.outline.withValues(alpha: 0.2)
                        : Colors.grey.shade300));

            final Color chipTextColor = isActive
                ? Colors.white
                : (isDone
                    ? (isDark ? const Color(0xFF4ADE80) : AppTheme.catGreen)
                    : theme.colorScheme.onSurfaceVariant);

            return InkWell(
              onTap: () {
                if (_saveCurrentEditorState()) {
                  _loadQuestionIntoEditor(index);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: chipBorder,
                    width: isActive ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${q.position}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: chipTextColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMcChoiceRow(String label, TextEditingController controller) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCorrect = _selectedMcAnswer == label;

    return Row(
      children: [
        Radio<String>(
          value: label,
          groupValue: _selectedMcAnswer,
          activeColor: theme.colorScheme.primary,
          onChanged: (val) {
            setState(() {
              _selectedMcAnswer = val;
              _syncCurrentDraftFromInputs();
            });
          },
        ),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) {
              _syncCurrentDraftFromInputs();
              setState(() {});
            },
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: 'Choice $label',
              labelStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isCorrect
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(
                          alpha: isDark ? 0.3 : 0.2,
                        ),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              fillColor: isCorrect
                  ? theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.12 : 0.05,
                    )
                  : (isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                      : Colors.white),
              filled: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
