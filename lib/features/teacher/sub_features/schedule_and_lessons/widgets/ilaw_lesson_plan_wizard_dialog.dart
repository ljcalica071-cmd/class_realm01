import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/services/gemini_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/ilaw_file_downloader.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/ilaw_lesson_plan_validator.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/teacher_lesson_plan_store.dart';

enum IlawWizardStep { details, reviewEdit, previewExport }

class IlawLessonPlanWizardDialog extends StatefulWidget {
  final IlawLessonPlan? existingPlan;
  final IlawWizardStep initialStep;
  final TeacherLessonPlanStore store;
  final GeminiService geminiService;
  final UserModel? currentTeacher;
  final IlawFileSaveHandler? fileSaveHandler;
  final VoidCallback onSaved;

  const IlawLessonPlanWizardDialog({
    super.key,
    this.existingPlan,
    this.initialStep = IlawWizardStep.details,
    required this.store,
    required this.geminiService,
    required this.currentTeacher,
    this.fileSaveHandler,
    required this.onSaved,
  });

  @override
  State<IlawLessonPlanWizardDialog> createState() =>
      _IlawLessonPlanWizardDialogState();
}

class _IlawLessonPlanWizardDialogState
    extends State<IlawLessonPlanWizardDialog> {
  static const Color _errorRed = Color(0xFFDC2626);

  late IlawWizardStep _step;
  late String _planId;
  late DateTime _createdAt;
  late IlawPlanStatus _status;

  String _selectedGrade = 'Grade 11';
  String _selectedTerm = 'Term 1';
  int _selectedSessions = 4;
  DepEdProficiencyLevel _selectedProficiency = DepEdProficiencyLevel.developing;
  IlawTemplateType _selectedTemplate = IlawTemplateType.ilawModified;
  IlawContentSource _selectedSource = IlawContentSource.curriculumBased;

  late final TextEditingController _subjectCtrl;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _strategyCtrl;
  late final TextEditingController _competencyCtrl;

  late final TextEditingController _outcomesCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _assessmentCtrl;
  late final TextEditingController _workCtrl;

  final ScrollController _scrollCtrl = ScrollController();

  List<IlawSessionData> _sessions = [];
  List<IlawRubricItem> _rubricItems = [];
  int _activeSessionIndex = 0;
  List<String> _teacherSubjectNames = [];

  // Session edit controllers
  final List<TextEditingController> _sessionTitleCtrls = [];
  final List<TextEditingController> _sessionObjectivesCtrls = [];
  final List<TextEditingController> _sessionExperiencesCtrls = [];
  final List<TextEditingController> _sessionAssessmentCtrls = [];
  final List<TextEditingController> _sessionParentGuideCtrls = [];
  final List<TextEditingController> _sessionCommunityCtrls = [];
  final List<TextEditingController> _sessionReflectionCtrls = [];

  // Inline validation error states
  String? _gradeError;
  String? _termError;
  String? _sessionsError;
  String? _proficiencyError;
  String? _subjectError;
  String? _topicError;
  String? _durationError;
  String? _competencyError;

  String? _outcomesError;
  String? _contentError;
  String? _assessmentError;
  String? _workError;

  bool _isGenerating = false;
  bool _isSaving = false;
  bool _isExportingDocx = false;
  bool _isExportingPdf = false;

  bool _showMissingKeysPrompt = false;
  String? _inlineAlertMessage;
  bool _inlineAlertIsError = false;
  String? _exportFeedbackMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPlan;
    _step = widget.initialStep;
    _planId =
        existing?.id ??
        'ilaw_${DateTime.now().microsecondsSinceEpoch.toString()}';
    _createdAt = existing?.createdAt ?? DateTime.now();
    _status = existing?.status ?? IlawPlanStatus.draft;

    _selectedGrade = existing?.gradeLevel ?? 'Grade 11';
    _selectedTerm = existing?.term ?? 'Term 1';
    _selectedSessions = existing?.numberOfSessions ?? 4;
    _selectedProficiency =
        existing?.targetProficiency ?? DepEdProficiencyLevel.developing;
    _selectedTemplate = existing?.templateType ?? IlawTemplateType.ilawModified;
    _selectedSource =
        existing?.contentSource ?? IlawContentSource.curriculumBased;

    _subjectCtrl = TextEditingController(text: existing?.subject ?? '');
    _topicCtrl = TextEditingController(text: existing?.topic ?? '');
    _durationCtrl = TextEditingController(
      text: (existing?.durationMinutes ?? 60).toString(),
    );
    _strategyCtrl = TextEditingController(
      text: existing?.teachingStrategy ?? '',
    );
    _competencyCtrl = TextEditingController(
      text: existing?.learningCompetency ?? '',
    );

    _outcomesCtrl = TextEditingController(
      text: existing?.intendedOutcomes ?? '',
    );
    _contentCtrl = TextEditingController(text: existing?.learningContent ?? '');
    _assessmentCtrl = TextEditingController(text: existing?.assessment ?? '');
    _workCtrl = TextEditingController(text: existing?.workExperiences ?? '');

    _sessions = existing != null ? List.from(existing.effectiveSessions) : [];
    _rubricItems = existing != null
        ? List.from(existing.effectiveRubrics)
        : IlawRubricItem.defaultRubrics();

    _syncSessionControllers();
    _loadTeacherSubjects();
  }

  void _loadTeacherSubjects() async {
    final teacherId =
        widget.currentTeacher?.id ?? AuthRepository.instance.currentUser?.id;
    if (teacherId == null || teacherId.trim().isEmpty) return;

    // 1. Synchronously populate from cached subjects first
    try {
      final cached = SubjectRepository.instance.getCachedTeacherSubjects(
        teacherId,
      );
      final cachedNames = cached
          .map((m) => (m['subject_name'] ?? m['name'])?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (cachedNames.isNotEmpty) {
        _teacherSubjectNames = cachedNames;
        if (widget.existingPlan == null && _subjectCtrl.text.trim().isEmpty) {
          _subjectCtrl.text = cachedNames.first;
        }
      }
    } catch (_) {}

    // 2. Refresh asynchronously from repository
    try {
      final activeRows = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
      final refreshedNames = activeRows
          .map((m) => (m['subject_name'] ?? m['name'])?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (mounted && refreshedNames.isNotEmpty) {
        setState(() {
          _teacherSubjectNames = refreshedNames;
          if (widget.existingPlan == null && _subjectCtrl.text.trim().isEmpty) {
            _subjectCtrl.text = refreshedNames.first;
          }
        });
      }
    } catch (_) {}
  }

  void _syncSessionControllers() {
    _disposeSessionControllers();
    for (final s in _sessions) {
      _sessionTitleCtrls.add(TextEditingController(text: s.sessionTitle));
      _sessionObjectivesCtrls.add(TextEditingController(text: s.objectives));
      _sessionExperiencesCtrls.add(
        TextEditingController(text: s.learningExperiences),
      );
      _sessionAssessmentCtrls.add(
        TextEditingController(text: s.formativeAssessment),
      );
      _sessionParentGuideCtrls.add(TextEditingController(text: s.parentGuide));
      _sessionCommunityCtrls.add(
        TextEditingController(text: s.communityExperience),
      );
      _sessionReflectionCtrls.add(
        TextEditingController(text: s.teacherReflections),
      );
    }
  }

  void _disposeSessionControllers() {
    for (final c in _sessionTitleCtrls) {
      c.dispose();
    }
    for (final c in _sessionObjectivesCtrls) {
      c.dispose();
    }
    for (final c in _sessionExperiencesCtrls) {
      c.dispose();
    }
    for (final c in _sessionAssessmentCtrls) {
      c.dispose();
    }
    for (final c in _sessionParentGuideCtrls) {
      c.dispose();
    }
    for (final c in _sessionCommunityCtrls) {
      c.dispose();
    }
    for (final c in _sessionReflectionCtrls) {
      c.dispose();
    }
    _sessionTitleCtrls.clear();
    _sessionObjectivesCtrls.clear();
    _sessionExperiencesCtrls.clear();
    _sessionAssessmentCtrls.clear();
    _sessionParentGuideCtrls.clear();
    _sessionCommunityCtrls.clear();
    _sessionReflectionCtrls.clear();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _topicCtrl.dispose();
    _durationCtrl.dispose();
    _strategyCtrl.dispose();
    _competencyCtrl.dispose();
    _outcomesCtrl.dispose();
    _contentCtrl.dispose();
    _assessmentCtrl.dispose();
    _workCtrl.dispose();
    _scrollCtrl.dispose();
    _disposeSessionControllers();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
  }

  bool _validateStep1() {
    final gErr = IlawLessonPlanValidator.validateGradeLevel(_selectedGrade);
    final qErr = IlawLessonPlanValidator.validateTerm(_selectedTerm);
    final sesErr = IlawLessonPlanValidator.validateNumberOfSessions(
      _selectedSessions,
    );
    final sErr = IlawLessonPlanValidator.validateSubject(_subjectCtrl.text);
    final tErr = IlawLessonPlanValidator.validateTopic(_topicCtrl.text);
    final dErr = IlawLessonPlanValidator.validateDuration(_durationCtrl.text);
    final stErr = IlawLessonPlanValidator.validateTeachingStrategy(
      _strategyCtrl.text,
    );
    final cErr = IlawLessonPlanValidator.validateCompetency(
      _competencyCtrl.text,
    );

    setState(() {
      _gradeError = gErr;
      _termError = qErr;
      _sessionsError = sesErr;
      _subjectError = sErr;
      _topicError = tErr;
      _durationError = dErr;
      _competencyError = cErr;
    });

    return gErr == null &&
        qErr == null &&
        sesErr == null &&
        sErr == null &&
        tErr == null &&
        dErr == null &&
        stErr == null &&
        cErr == null;
  }

  bool _validateStep2() {
    final tErr = IlawLessonPlanValidator.validateTopic(_topicCtrl.text);
    final dErr = IlawLessonPlanValidator.validateDuration(_durationCtrl.text);
    final oErr = IlawLessonPlanValidator.validateSectionContent(
      _outcomesCtrl.text,
      sectionName: 'Intended Learning Outcomes',
    );
    final cErr = IlawLessonPlanValidator.validateSectionContent(
      _contentCtrl.text,
      sectionName: 'Learning Content & Resources',
    );
    final aErr = IlawLessonPlanValidator.validateSectionContent(
      _assessmentCtrl.text,
      sectionName: 'Assessment & Activities',
    );
    final wErr = IlawLessonPlanValidator.validateSectionContent(
      _workCtrl.text,
      sectionName: 'Work / Learning Experiences',
      maxLength: IlawLessonPlanValidator.maxProcedureSectionLength,
    );

    setState(() {
      _topicError = tErr;
      _durationError = dErr;
      _outcomesError = oErr;
      _contentError = cErr;
      _assessmentError = aErr;
      _workError = wErr;
    });

    return tErr == null &&
        dErr == null &&
        oErr == null &&
        cErr == null &&
        aErr == null &&
        wErr == null;
  }

  void _saveSessionFormValuesToState() {
    for (int i = 0; i < _sessions.length; i++) {
      if (i < _sessionTitleCtrls.length) {
        _sessions[i] = _sessions[i].copyWith(
          sessionTitle: _sessionTitleCtrls[i].text,
          objectives: _sessionObjectivesCtrls[i].text,
          learningExperiences: _sessionExperiencesCtrls[i].text,
          formativeAssessment: _sessionAssessmentCtrls[i].text,
          parentGuide: _sessionParentGuideCtrls[i].text,
          communityExperience: _sessionCommunityCtrls[i].text,
          teacherReflections: _sessionReflectionCtrls[i].text,
        );
      }
    }
  }

  Future<void> _handleGenerateWithAi() async {
    if (!_validateStep1()) return;

    if (!widget.geminiService.hasConfiguredKeys) {
      setState(() {
        _isGenerating = false;
        _showMissingKeysPrompt = true;
        _inlineAlertIsError = true;
        _inlineAlertMessage = 'No Gemini API key is configured in .env yet. You can inspect sample drafts or add your key to enable live generation.';
      });
      return;
    }

    // Show DepEd Order No. 003, s. 2026 Confirmation Modal
    final confirmed = await _showDepEdEthicsNoticeDialog();
    if (confirmed != true || !mounted) return;

    setState(() {
      _isGenerating = true;
      _inlineAlertMessage = null;
      _inlineAlertIsError = false;
      _showMissingKeysPrompt = false;
      _exportFeedbackMessage = null;
    });

    final durationMins = int.tryParse(_durationCtrl.text.trim()) ?? 60;

    final result = await widget.geminiService.generateStructuredIlawPlan(
      subject: _subjectCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      gradeLevel: _selectedGrade,
      quarter: _selectedTerm,
      durationMinutes: durationMins,
      teachingStrategy: _strategyCtrl.text.trim(),
      learningCompetency: _competencyCtrl.text.trim(),
      numberOfSessions: _selectedSessions,
      proficiencyLevel: _selectedProficiency,
      templateType: _selectedTemplate,
    );

    if (!mounted) return;

    if (result.missingApiKeys) {
      setState(() {
        _isGenerating = false;
        _showMissingKeysPrompt = true;
        _inlineAlertIsError = true;
        _inlineAlertMessage = 'No Gemini API key is configured in .env yet. You can inspect sample drafts or add your key to enable live generation.';
      });
      return;
    }

    if (!result.isSuccess || result.sections == null) {
      setState(() {
        _isGenerating = false;
        _inlineAlertIsError = true;
        _inlineAlertMessage = GeminiService.formatUserFriendlyErrorMessage(
          result.errorMessage,
        );
      });
      return;
    }

    final sections = result.sections!;
    setState(() {
      _isGenerating = false;
      _outcomesCtrl.text = sections.intendedOutcomes;
      _contentCtrl.text = sections.learningContent;
      _assessmentCtrl.text = sections.assessment;
      _workCtrl.text = sections.workExperiences;
      _sessions = List.from(sections.sessions);
      _rubricItems = List.from(sections.rubricItems);
      _activeSessionIndex = 0;
      _syncSessionControllers();
      _step = IlawWizardStep.reviewEdit;
      _inlineAlertMessage = null;
    });

    _scrollToTop();
  }

  Future<bool?> _showDepEdEthicsNoticeDialog() {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'DepEd Order No. 003, s. 2026 AI Ethics Notice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This lesson plan is generated using AI in accordance with DepEd guidelines (DO 3 s.2026). As a professional Senior High School teacher, you are responsible for reviewing, validating, and adapting all generated contents before classroom execution.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Targeting: $_selectedGrade • $_selectedTerm • $_selectedSessions Sessions • ${_selectedProficiency.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            AppButton.primary(
              label: 'I Understand & Generate',
              isSmall: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );
  }

  void _handleLoadTemplateDraft() {
    final durationMins = int.tryParse(_durationCtrl.text.trim()) ?? 60;
    final sub = _subjectCtrl.text.trim().isNotEmpty
        ? _subjectCtrl.text.trim()
        : 'General Mathematics';
    final top = _topicCtrl.text.trim().isNotEmpty
        ? _topicCtrl.text.trim()
        : 'Rational Functions & Models';

    final draft = IlawLessonPlan.buildTemplateSections(
      subject: sub,
      topic: top,
      gradeLevel: _selectedGrade,
      quarter: _selectedTerm,
      durationMinutes: durationMins,
      teachingStrategy: _strategyCtrl.text.trim(),
      learningCompetency: _competencyCtrl.text.trim(),
      numberOfSessions: _selectedSessions,
      proficiencyLevel: _selectedProficiency,
    );

    setState(() {
      _outcomesCtrl.text = draft.intendedOutcomes;
      _contentCtrl.text = draft.learningContent;
      _assessmentCtrl.text = draft.assessment;
      _workCtrl.text = draft.workExperiences;
      _sessions = List.from(draft.sessions);
      _rubricItems = List.from(draft.rubricItems);
      _activeSessionIndex = 0;
      _syncSessionControllers();
      _showMissingKeysPrompt = false;
      _inlineAlertMessage = null;
      _step = IlawWizardStep.reviewEdit;
    });

    _scrollToTop();
  }

  IlawLessonPlan _buildCurrentPlanModel([IlawPlanStatus? status]) {
    _saveSessionFormValuesToState();
    final durationMins = int.tryParse(_durationCtrl.text.trim()) ?? 60;
    final teacher = widget.currentTeacher;

    return IlawLessonPlan(
      id: _planId,
      teacherId: teacher?.id ?? 'teacher_local',
      teacherName: teacher?.fullName ?? 'Senior High School Teacher',
      gradeLevel: _selectedGrade,
      quarter: _selectedTerm,
      subject: _subjectCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      durationMinutes: durationMins,
      teachingStrategy: _strategyCtrl.text.trim(),
      learningCompetency: _competencyCtrl.text.trim(),
      intendedOutcomes: _outcomesCtrl.text.trim(),
      learningContent: _contentCtrl.text.trim(),
      assessment: _assessmentCtrl.text.trim(),
      workExperiences: _workCtrl.text.trim(),
      templateType: _selectedTemplate,
      contentSource: _selectedSource,
      targetProficiency: _selectedProficiency,
      numberOfSessions: _selectedSessions,
      sessions: _sessions,
      rubricItems: _rubricItems,
      status: status ?? _status,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _handleSaveDraft() async {
    _saveSessionFormValuesToState();
    setState(() {
      _isSaving = true;
      _inlineAlertMessage = null;
    });

    try {
      final draft = _buildCurrentPlanModel(IlawPlanStatus.draft);
      await widget.store.savePlan(draft);
      widget.onSaved();
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _status = IlawPlanStatus.draft;
        _inlineAlertIsError = false;
        _inlineAlertMessage = 'Draft saved to your lesson plan library.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _inlineAlertIsError = true;
        _inlineAlertMessage = e.toString();
      });
    }
  }

  Future<void> _handleApproveAndFinalize() async {
    if (!_validateStep2()) return;
    _saveSessionFormValuesToState();

    setState(() {
      _isSaving = true;
      _inlineAlertMessage = null;
    });

    try {
      final approved = _buildCurrentPlanModel(IlawPlanStatus.approved);
      await widget.store.savePlan(approved);
      widget.onSaved();
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _status = IlawPlanStatus.approved;
        _step = IlawWizardStep.previewExport;
      });
      _scrollToTop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _inlineAlertIsError = true;
        _inlineAlertMessage = e.toString();
      });
    }
  }

  Future<void> _handleExport(IlawExportFormat format) async {
    final isDocx = format == IlawExportFormat.docx;
    setState(() {
      if (isDocx) {
        _isExportingDocx = true;
      } else {
        _isExportingPdf = true;
      }
      _exportFeedbackMessage = null;
      _inlineAlertMessage = null;
    });

    try {
      final approvedPlan = _buildCurrentPlanModel(IlawPlanStatus.approved);
      final msg = await IlawFileDownloader.exportAndDownload(
        plan: approvedPlan,
        format: format,
        customSaveHandler: widget.fileSaveHandler,
      );
      if (!mounted) return;
      setState(() {
        _isExportingDocx = false;
        _isExportingPdf = false;
        _exportFeedbackMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExportingDocx = false;
        _isExportingPdf = false;
        _inlineAlertIsError = true;
        _inlineAlertMessage = 'Export failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width - 32).clamp(320.0, 920.0);
    final dialogMaxHeight = (screenSize.height - 48).clamp(440.0, 840.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            _buildStepperBar(theme),
            _buildPinnedAlertRegion(theme),
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(24),
                child: _buildActiveStepBody(theme),
              ),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    String title;
    String subtitle;
    switch (_step) {
      case IlawWizardStep.details:
        title = 'Generate SHS iLAW Lesson Plan';
        subtitle = 'DepEd Strengthened Senior High School Curriculum • Private to your account';
      case IlawWizardStep.reviewEdit:
        title = 'Teacher Review & Edit';
        subtitle = 'Refine multi-session matrices and self-check rubrics before finalizing.';
      case IlawWizardStep.previewExport:
        title = 'Approved iLAW Format & Download';
        subtitle = 'Official DepEd print-ready layout  •  Choose Word (.docx) or PDF (.pdf)';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _step == IlawWizardStep.previewExport
                  ? Icons.verified_outlined
                  : Icons.auto_awesome_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperBar(ThemeData theme) {
    final steps = [
      (IlawWizardStep.details, '1. Lesson Details'),
      (IlawWizardStep.reviewEdit, '2. Review & Edit'),
      (IlawWizardStep.previewExport, '3. iLAW Format & Export'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              _buildStepIndicator(
                theme,
                label: steps[i].$2,
                isActive: _step == steps[i].$1,
                isCompleted: _step.index > steps[i].$1.index,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(
    ThemeData theme, {
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color bg;
    Color fg;
    Border? border;

    if (isActive) {
      bg = theme.colorScheme.primary.withValues(alpha: 0.12);
      fg = theme.colorScheme.primary;
      border = Border.all(
        color: theme.colorScheme.primary.withValues(alpha: 0.4),
      );
    } else if (isCompleted) {
      bg = AppTheme.catGreen.withValues(alpha: 0.12);
      fg = AppTheme.catGreen;
    } else {
      bg = Colors.transparent;
      fg = theme.colorScheme.onSurface.withValues(alpha: 0.42);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive || isCompleted
              ? FontWeight.w600
              : FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildPinnedAlertRegion(ThemeData theme) {
    final hasInline = _inlineAlertMessage != null;
    final hasExport = _exportFeedbackMessage != null;
    if (!hasInline && !hasExport) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          if (hasInline)
            _buildInlineStatusBox(
              theme,
              message: _inlineAlertMessage!,
              isError: _inlineAlertIsError,
              action: _showMissingKeysPrompt
                  ? AppButton.outline(
                      label: 'Continue with Sample SHS Draft',
                      icon: Icons.edit_note_outlined,
                      isSmall: true,
                      onPressed: _handleLoadTemplateDraft,
                    )
                  : (_inlineAlertIsError && _step == IlawWizardStep.details
                      ? AppButton.outline(
                          label: 'Open Manual Template',
                          icon: Icons.edit_note_outlined,
                          isSmall: true,
                          onPressed: _handleLoadTemplateDraft,
                        )
                      : null),
              onDismiss: () {
                setState(() {
                  _inlineAlertMessage = null;
                });
              },
            ),
          if (hasInline && hasExport) const SizedBox(height: 8),
          if (hasExport)
            _buildInlineStatusBox(
              theme,
              message: _exportFeedbackMessage!,
              isError: false,
            ),
        ],
      ),
    );
  }

  Widget _buildActiveStepBody(ThemeData theme) {
    switch (_step) {
      case IlawWizardStep.details:
        return _buildStep1Details(theme);
      case IlawWizardStep.reviewEdit:
        return _buildStep2ReviewEdit(theme);
      case IlawWizardStep.previewExport:
        return _buildStep3MinimalistPreview(theme);
    }
  }

  Widget _buildStep1Details(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Grade Level & Term
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildGradeDropdown(theme)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTermDropdown(theme)),
                ],
              )
            else ...[
              _buildGradeDropdown(theme),
              const SizedBox(height: 16),
              _buildTermDropdown(theme),
            ],
            const SizedBox(height: 16),

            // Row 2: Sessions & Proficiency
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSessionsDropdown(theme)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildProficiencyDropdown(theme)),
                ],
              )
            else ...[
              _buildSessionsDropdown(theme),
              const SizedBox(height: 16),
              _buildProficiencyDropdown(theme),
            ],
            const SizedBox(height: 16),

            // Subject input
            _buildValidatedTextField(
              theme: theme,
              fieldKey: const Key('ilaw_subject_field'),
              label: 'Senior High School Subject *',
              hint: 'e.g., General Mathematics or Oral Communication',
              controller: _subjectCtrl,
              errorText: _subjectError,
              maxLength: IlawLessonPlanValidator.maxSubjectLength,
              showCounter: true,
              onChanged: (_) {
                setState(() {
                  _subjectError = null;
                });
              },
            ),

            // Suggested SHS Subjects (Teacher's own active subjects only)
            const SizedBox(height: 8),
            if (_teacherSubjectNames.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _teacherSubjectNames.map((sub) {
                  final isSelected =
                      _subjectCtrl.text.trim().toLowerCase() ==
                      sub.toLowerCase();
                  return ActionChip(
                    avatar: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    label: Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : null,
                    onPressed: () {
                      setState(() {
                        _subjectCtrl.text = sub;
                        _subjectError = null;
                      });
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    DepEdCurriculumCatalog.getStandardSubjects(
                      _selectedGrade,
                    ).take(6).map((sub) {
                      return ActionChip(
                        label: Text(sub, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _subjectCtrl.text = sub;
                            _subjectError = null;
                          });
                        },
                      );
                    }).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Template & Source Toggles
            _buildFormatAndSourceOptions(theme),
            const SizedBox(height: 16),

            // Curriculum Competencies Checklist
            _buildCompetencyChecklist(theme),
            const SizedBox(height: 16),

            // Topic field
            _buildValidatedTextField(
              theme: theme,
              fieldKey: const Key('ilaw_topic_field'),
              label: 'Lesson Topic / Title *',
              hint: 'e.g., Rational Functions, Equations, and Inequalities',
              controller: _topicCtrl,
              errorText: _topicError,
              maxLength: IlawLessonPlanValidator.maxTopicLength,
              showCounter: true,
              onChanged: (_) {
                if (_topicError != null) {
                  setState(() => _topicError = null);
                }
              },
            ),
            const SizedBox(height: 16),

            // Duration per Session
            _buildDurationSection(theme),
            const SizedBox(height: 16),

            // Competency / Teacher Notes
            _buildValidatedTextField(
              theme: theme,
              fieldKey: const Key('ilaw_competency_field'),
              label: 'Selected Competencies / Teacher Instructions (Optional)',
              hint: 'Checked competencies will appear here, or type custom notes.',
              controller: _competencyCtrl,
              errorText: _competencyError,
              maxLines: 3,
              maxLength: IlawLessonPlanValidator.maxCompetencyLength,
              showCounter: true,
              onChanged: (_) {
                if (_competencyError != null) {
                  setState(() => _competencyError = null);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormatAndSourceOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Format Template & Content Source',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text(
                'iLAW Modified (DepEd 2026)',
                style: TextStyle(fontSize: 11.5),
              ),
              selected: _selectedTemplate == IlawTemplateType.ilawModified,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(
                () => _selectedTemplate = IlawTemplateType.ilawModified,
              ),
            ),
            ChoiceChip(
              label: const Text(
                'Curriculum Based',
                style: TextStyle(fontSize: 11.5),
              ),
              selected: _selectedSource == IlawContentSource.curriculumBased,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(
                () => _selectedSource = IlawContentSource.curriculumBased,
              ),
            ),
            ChoiceChip(
              label: const Text(
                'Manual Input',
                style: TextStyle(fontSize: 11.5),
              ),
              selected: _selectedSource == IlawContentSource.manual,
              visualDensity: VisualDensity.compact,
              onSelected: (_) =>
                  setState(() => _selectedSource = IlawContentSource.manual),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompetencyChecklist(ThemeData theme) {
    final comps = DepEdCurriculumCatalog.getCompetenciesFor(
      gradeLevel: _selectedGrade,
      subject: _subjectCtrl.text,
      term: _selectedTerm,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rtl_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DepEd Curriculum Competencies ($_selectedGrade • $_selectedTerm)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final comp in comps.take(4)) ...[
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() {
                  if (_competencyCtrl.text.contains(comp)) {
                    _competencyCtrl.text = _competencyCtrl.text
                        .replaceAll(comp, '')
                        .trim();
                  } else {
                    final curr = _competencyCtrl.text.trim();
                    _competencyCtrl.text = curr.isEmpty ? comp : '$curr\n$comp';
                  }
                  _competencyError = null;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _competencyCtrl.text.contains(comp)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: _competencyCtrl.text.contains(comp)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comp,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationSection(ThemeData theme) {
    const presets = ['45', '60', '90', '120'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidatedTextField(
          theme: theme,
          fieldKey: const Key('ilaw_duration_field'),
          label: 'Duration per Session (Minutes) *',
          hint: 'e.g., 60',
          controller: _durationCtrl,
          errorText: _durationError,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) {
            if (_durationError != null) {
              setState(() => _durationError = null);
            }
          },
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: presets.map((mins) {
            final isSelected = _durationCtrl.text.trim() == mins;
            return ChoiceChip(
              label: Text('$mins mins', style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              visualDensity: VisualDensity.compact,
              onSelected: (_) {
                setState(() {
                  _durationCtrl.text = mins;
                  _durationError = null;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGradeDropdown(ThemeData theme) {
    return _buildDropdownField(
      theme: theme,
      fieldKey: const Key('ilaw_grade_dropdown'),
      label: 'SHS Grade Level *',
      value: _selectedGrade,
      items: IlawLessonPlanValidator.allowedGrades,
      errorText: _gradeError,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedGrade = val;
            _gradeError = null;
          });
        }
      },
    );
  }

  Widget _buildTermDropdown(ThemeData theme) {
    return _buildDropdownField(
      theme: theme,
      fieldKey: const Key('ilaw_term_dropdown'),
      label: 'Term *',
      value: _selectedTerm,
      items: IlawLessonPlanValidator.allowedTerms,
      errorText: _termError,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedTerm = val;
            _termError = null;
          });
        }
      },
    );
  }

  Widget _buildSessionsDropdown(ThemeData theme) {
    final items = [
      '1 Session',
      '2 Sessions',
      '3 Sessions',
      '4 Sessions',
      '5 Sessions',
    ];
    final currentLabel =
        '$_selectedSessions ${_selectedSessions == 1 ? "Session" : "Sessions"}';

    return _buildDropdownField(
      theme: theme,
      fieldKey: const Key('ilaw_sessions_dropdown'),
      label: 'Number of Sessions (1 to 5) *',
      value: currentLabel,
      items: items,
      errorText: _sessionsError,
      onChanged: (val) {
        if (val != null) {
          final count = int.tryParse(val.split(' ').first) ?? 4;
          setState(() {
            _selectedSessions = count;
            _sessionsError = null;
          });
        }
      },
    );
  }

  Widget _buildProficiencyDropdown(ThemeData theme) {
    final items = DepEdProficiencyLevel.values.map((p) => p.label).toList();

    return _buildDropdownField(
      theme: theme,
      fieldKey: const Key('ilaw_proficiency_dropdown'),
      label: 'Proficiency Target (CRLA/RMA Aligned) *',
      value: _selectedProficiency.label,
      items: items,
      errorText: _proficiencyError,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedProficiency = DepEdProficiencyLevel.fromString(val);
            _proficiencyError = null;
          });
        }
      },
    );
  }

  Widget _buildStep2ReviewEdit(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic & Duration Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildValidatedTextField(
                theme: theme,
                fieldKey: const Key('ilaw_review_topic_field'),
                label: 'Lesson Topic *',
                hint: 'Lesson topic',
                controller: _topicCtrl,
                errorText: _topicError,
                maxLength: IlawLessonPlanValidator.maxTopicLength,
                onChanged: (_) {
                  if (_topicError != null) {
                    setState(() => _topicError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    '$_selectedGrade  •  $_selectedTerm  •  $_selectedSessions Sessions  •  ${_selectedProficiency.label}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section I: Outcomes
        _buildSectionHeader(theme, 'I', 'INTENDED LEARNING OUTCOMES'),
        const SizedBox(height: 8),
        _buildValidatedTextField(
          theme: theme,
          fieldKey: const Key('ilaw_edit_outcomes_field'),
          label: '',
          hint: 'Learning objectives...',
          controller: _outcomesCtrl,
          errorText: _outcomesError,
          maxLines: 4,
          maxLength: IlawLessonPlanValidator.maxStandardSectionLength,
          showCounter: true,
          onChanged: (_) {
            if (_outcomesError != null) {
              setState(() => _outcomesError = null);
            }
          },
        ),
        const SizedBox(height: 20),

        // Section L: Content
        _buildSectionHeader(theme, 'L', 'LEARNING CONTENT & RESOURCES'),
        const SizedBox(height: 8),
        _buildValidatedTextField(
          theme: theme,
          fieldKey: const Key('ilaw_edit_content_field'),
          label: '',
          hint: 'Content and materials...',
          controller: _contentCtrl,
          errorText: _contentError,
          maxLines: 4,
          maxLength: IlawLessonPlanValidator.maxStandardSectionLength,
          showCounter: true,
          onChanged: (_) {
            if (_contentError != null) {
              setState(() => _contentError = null);
            }
          },
        ),
        const SizedBox(height: 20),

        // Section A: Assessment
        _buildSectionHeader(theme, 'A', 'ASSESSMENT & ACTIVITIES'),
        const SizedBox(height: 8),
        _buildValidatedTextField(
          theme: theme,
          fieldKey: const Key('ilaw_edit_assessment_field'),
          label: '',
          hint: 'Assessment plan...',
          controller: _assessmentCtrl,
          errorText: _assessmentError,
          maxLines: 4,
          maxLength: IlawLessonPlanValidator.maxStandardSectionLength,
          showCounter: true,
          onChanged: (_) {
            if (_assessmentError != null) {
              setState(() => _assessmentError = null);
            }
          },
        ),
        const SizedBox(height: 20),

        // Section W: Procedure
        _buildSectionHeader(theme, 'W', 'WORK / LEARNING EXPERIENCES'),
        const SizedBox(height: 8),
        _buildValidatedTextField(
          theme: theme,
          fieldKey: const Key('ilaw_edit_work_field'),
          label: '',
          hint: 'Procedure...',
          controller: _workCtrl,
          errorText: _workError,
          maxLines: 6,
          maxLength: IlawLessonPlanValidator.maxProcedureSectionLength,
          showCounter: true,
          onChanged: (_) {
            if (_workError != null) {
              setState(() => _workError = null);
            }
          },
        ),
        const SizedBox(height: 24),

        // Multi-Session Detailed Matrix Cards
        if (_sessions.isNotEmpty) ...[
          _buildMultiSessionMatrixEditor(theme),
          const SizedBox(height: 24),
        ],

        // Rubric Checklist
        _buildRubricsChecklistEditor(theme),
      ],
    );
  }

  Widget _buildMultiSessionMatrixEditor(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.view_column_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MULTI-SESSION INSTRUCTIONAL MATRIX (${_sessions.length} Sessions)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Session Tab selector
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < _sessions.length; i++)
                ChoiceChip(
                  label: Text('Session ${i + 1}'),
                  selected: _activeSessionIndex == i,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _activeSessionIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Session Editor
          if (_activeSessionIndex < _sessionTitleCtrls.length) ...[
            Text(
              'Session ${_activeSessionIndex + 1}: ${_sessionTitleCtrls[_activeSessionIndex].text}',
              key: ValueKey('session_title_header_$_activeSessionIndex'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('session_title_field_$_activeSessionIndex'),
              controller: _sessionTitleCtrls[_activeSessionIndex],
              decoration: const InputDecoration(
                labelText: 'Session Title',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sessionObjectivesCtrls[_activeSessionIndex],
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Session Objectives',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sessionExperiencesCtrls[_activeSessionIndex],
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Learning Experiences (Warm-up, Modeling, Practice)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sessionAssessmentCtrls[_activeSessionIndex],
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Formative Assessment',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sessionParentGuideCtrls[_activeSessionIndex],
              decoration: const InputDecoration(
                labelText: 'Ways Forward: Parent Guide (Home Follow-up)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sessionCommunityCtrls[_activeSessionIndex],
              decoration: const InputDecoration(
                labelText: 'Ways Forward: Community Experience',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sessionReflectionCtrls[_activeSessionIndex],
              decoration: const InputDecoration(
                labelText: 'Teacher Reflections',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRubricsChecklistEditor(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rubric for Lesson Planning Self-Check & Peer Coaching',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < _rubricItems.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _rubricItems[i].isMet,
                    onChanged: (val) {
                      setState(() {
                        _rubricItems[i] = _rubricItems[i].copyWith(
                          isMet: val ?? false,
                        );
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      _rubricItems[i].criterion,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String code, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildStep3MinimalistPreview(ThemeData theme) {
    final plan = _buildCurrentPlanModel(IlawPlanStatus.approved);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Export Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Lesson Plan Approved. Ready for official DepEd document download.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  AppButton.outline(
                    label: _isExportingDocx
                        ? 'Exporting...'
                        : 'Download Word (.docx)',
                    icon: Icons.description_outlined,
                    isSmall: true,
                    isLoading: _isExportingDocx,
                    onPressed: () => _handleExport(IlawExportFormat.docx),
                  ),
                  AppButton.primary(
                    label: _isExportingPdf
                        ? 'Exporting...'
                        : 'Download PDF (.pdf)',
                    icon: Icons.picture_as_pdf_outlined,
                    isSmall: true,
                    isLoading: _isExportingPdf,
                    onPressed: () => _handleExport(IlawExportFormat.pdf),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Document Canvas
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEPARTMENT OF EDUCATION  •  SENIOR HIGH SCHOOL CURRICULUM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'iLAW LESSON PLAN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Metadata Grid
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildMetaPair(
                      'Subject',
                      plan.subject,
                      'Grade & Term',
                      '${plan.gradeLevel} - ${plan.term}',
                    ),
                    const SizedBox(height: 8),
                    _buildMetaPair(
                      'Topic',
                      plan.topic,
                      'Duration & Sessions',
                      '${plan.durationMinutes}m • ${plan.numberOfSessions} Sessions',
                    ),
                    const SizedBox(height: 8),
                    _buildMetaPair(
                      'Proficiency Target',
                      plan.targetProficiency.label,
                      'Governance',
                      plan.depedOrderCitation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildPreviewBlock(
                theme,
                'I',
                'Intended Learning Outcomes',
                plan.intendedOutcomes,
              ),
              const SizedBox(height: 14),
              _buildPreviewBlock(
                theme,
                'L',
                'Learning Content & Resources',
                plan.learningContent,
              ),
              const SizedBox(height: 14),
              _buildPreviewBlock(
                theme,
                'A',
                'Assessment & Activities',
                plan.assessment,
              ),
              const SizedBox(height: 14),
              _buildPreviewBlock(
                theme,
                'W',
                'Work & Learning Experiences',
                plan.workExperiences,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaPair(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l1,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              Text(
                v1,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              Text(
                v2,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBlock(
    ThemeData theme,
    String code,
    String title,
    String body,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$code. $title',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: _buildFooterActions(theme),
    );
  }

  Widget _buildFooterActions(ThemeData theme) {
    switch (_step) {
      case IlawWizardStep.details:
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            AppButton.outline(
              label: 'Open Manual Template',
              icon: Icons.edit_note_outlined,
              onPressed: _isGenerating ? null : _handleLoadTemplateDraft,
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppButton.outline(
                  label: 'Cancel',
                  onPressed: _isGenerating
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
                AppButton.primary(
                  label: _isGenerating
                      ? 'Generating...'
                      : 'Generate with Gemini AI',
                  icon: Icons.auto_awesome_outlined,
                  isLoading: _isGenerating,
                  onPressed: _isGenerating ? null : _handleGenerateWithAi,
                ),
              ],
            ),
          ],
        );

      case IlawWizardStep.reviewEdit:
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            AppButton.outline(
              label: 'Back to Details',
              icon: Icons.arrow_back,
              onPressed: () => setState(() => _step = IlawWizardStep.details),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppButton.outline(
                  label: 'Save Draft',
                  icon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: _handleSaveDraft,
                ),
                AppButton.primary(
                  label: 'Approve & Format iLAW',
                  icon: Icons.verified_outlined,
                  isLoading: _isSaving,
                  onPressed: _handleApproveAndFinalize,
                ),
              ],
            ),
          ],
        );

      case IlawWizardStep.previewExport:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppButton.outline(
              label: 'Edit Content',
              icon: Icons.edit_outlined,
              onPressed: () =>
                  setState(() => _step = IlawWizardStep.reviewEdit),
            ),
            AppButton.primary(
              label: 'Done',
              icon: Icons.check,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
    }
  }

  Widget _buildValidatedTextField({
    required ThemeData theme,
    required Key fieldKey,
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? errorText,
    int maxLines = 1,
    int? maxLength,
    bool showCounter = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (showCounter && maxLength != null)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, val, _) {
                    final len = val.text.length;
                    return Text(
                      '$len/$maxLength',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: len >= maxLength
                            ? _errorRed
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.48,
                              ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
                width: hasError ? 1.8 : 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildDropdownField({
    required ThemeData theme,
    required Key fieldKey,
    required String label,
    required String value,
    required List<String> items,
    required String? errorText,
    required ValueChanged<String?> onChanged,
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
        LayoutBuilder(
          builder: (context, constraints) {
            final menuWidth = constraints.maxWidth;
            return MenuAnchor(
              alignmentOffset: const Offset(0, 4),
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(
                  theme.colorScheme.surface,
                ),
                surfaceTintColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                elevation: const WidgetStatePropertyAll(6),
                shadowColor: WidgetStatePropertyAll(
                  Colors.black.withValues(alpha: 0.16),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 4),
                ),
                minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
                maximumSize: WidgetStatePropertyAll(Size(menuWidth, 240)),
                side: WidgetStatePropertyAll(
                  BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              menuChildren: items.map((item) {
                final isSelected = item == value;
                return SizedBox(
                  width: menuWidth,
                  child: MenuItemButton(
                    onPressed: () => onChanged(item),
                    style: ButtonStyle(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (isSelected) {
                          return theme.colorScheme.primary.withValues(
                            alpha: 0.10,
                          );
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          );
                        }
                        return Colors.transparent;
                      }),
                    ),
                    trailingIcon: isSelected
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
              builder: (context, controller, child) {
                return InkWell(
                  key: fieldKey,
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.02,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasError
                            ? _errorRed
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.16,
                              ),
                        width: hasError ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildInlineStatusBox(
    ThemeData theme, {
    required String message,
    required bool isError,
    Widget? action,
    VoidCallback? onDismiss,
  }) {
    final color = isError ? _errorRed : AppTheme.catGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isError ? _errorRed : theme.colorScheme.onSurface,
                    fontWeight: isError ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 8), action],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
