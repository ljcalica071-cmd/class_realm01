import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/services/gemini_service.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
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
  String _selectedQuarter = 'Quarter 1';

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

  // Inline validation error states (never bottom SnackBars)
  String? _gradeError;
  String? _quarterError;
  String? _subjectError;
  String? _topicError;
  String? _durationError;
  String? _strategyError;
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

  List<String> _cachedTeacherSubjects = const [];

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
    _selectedQuarter = existing?.quarter ?? 'Quarter 1';

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

    _loadTeacherSubjectSuggestions();
  }

  void _loadTeacherSubjectSuggestions() {
    final uid = widget.currentTeacher?.id ?? '';
    if (uid.isEmpty) return;
    final raw = LocalStorageService.getTeacherSubjects(uid);
    final names = <String>{};
    for (final row in raw) {
      final n = (row['subject_name'] ?? row['name'] ?? '').toString().trim();
      if (n.isNotEmpty) {
        names.add(n);
      }
    }
    _cachedTeacherSubjects = names.take(6).toList();
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
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
  }

  bool _validateStep1() {
    final gErr = IlawLessonPlanValidator.validateGradeLevel(_selectedGrade);
    final qErr = IlawLessonPlanValidator.validateQuarter(_selectedQuarter);
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
      _quarterError = qErr;
      _subjectError = sErr;
      _topicError = tErr;
      _durationError = dErr;
      _strategyError = stErr;
      _competencyError = cErr;
      _inlineAlertMessage = null;
    });

    final isValid = gErr == null &&
        qErr == null &&
        sErr == null &&
        tErr == null &&
        dErr == null &&
        stErr == null &&
        cErr == null;
    if (!isValid) {
      _scrollToTop();
    }
    return isValid;
  }

  bool _validateStep2({required bool requireCompleteSections}) {
    final tErr = IlawLessonPlanValidator.validateTopic(_topicCtrl.text);
    final dErr = IlawLessonPlanValidator.validateDuration(_durationCtrl.text);

    String? iErr;
    String? lErr;
    String? aErr;
    String? wErr;

    if (requireCompleteSections) {
      iErr = IlawLessonPlanValidator.validateSectionContent(
        _outcomesCtrl.text,
        sectionName: 'Intended Learning Outcomes',
      );
      lErr = IlawLessonPlanValidator.validateSectionContent(
        _contentCtrl.text,
        sectionName: 'Learning Content & Resources',
      );
      aErr = IlawLessonPlanValidator.validateSectionContent(
        _assessmentCtrl.text,
        sectionName: 'Assessment & Learning Activities',
      );
      wErr = IlawLessonPlanValidator.validateSectionContent(
        _workCtrl.text,
        sectionName: 'Work / Learning Experiences',
        maxLength: IlawLessonPlanValidator.maxProcedureSectionLength,
      );
    }

    setState(() {
      _topicError = tErr;
      _durationError = dErr;
      _outcomesError = iErr;
      _contentError = lErr;
      _assessmentError = aErr;
      _workError = wErr;
      _inlineAlertMessage = null;
    });

    return tErr == null &&
        dErr == null &&
        iErr == null &&
        lErr == null &&
        aErr == null &&
        wErr == null;
  }

  Future<void> _handleGenerateWithAi() async {
    if (!_validateStep1()) return;

    setState(() {
      _isGenerating = true;
      _showMissingKeysPrompt = false;
      _inlineAlertMessage = null;
    });

    final durationMins = int.parse(_durationCtrl.text.trim());
    final result = await widget.geminiService.generateStructuredIlawPlan(
      subject: _subjectCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      gradeLevel: _selectedGrade,
      quarter: _selectedQuarter,
      durationMinutes: durationMins,
      teachingStrategy: _strategyCtrl.text.trim(),
      learningCompetency: _competencyCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result.isSuccess && result.sections != null) {
      final sections = result.sections!;
      setState(() {
        _isGenerating = false;
        _outcomesCtrl.text = sections.intendedOutcomes;
        _contentCtrl.text = sections.learningContent;
        _assessmentCtrl.text = sections.assessment;
        _workCtrl.text = sections.workExperiences;
        _outcomesError = null;
        _contentError = null;
        _assessmentError = null;
        _workError = null;
        _status = IlawPlanStatus.draft;
        _step = IlawWizardStep.reviewEdit;
        _inlineAlertIsError = false;
        _inlineAlertMessage =
            'AI draft generated (Account Slot #${result.usedKeySlot ?? 1}). Review and edit any section below before approving.';
      });
      return;
    }

    if (result.missingApiKeys) {
      setState(() {
        _isGenerating = false;
        _showMissingKeysPrompt = true;
        _inlineAlertIsError = false;
        _inlineAlertMessage =
            'Gemini API keys (GEMINI_API_KEY_1..3) are not placed in .env yet. You can load a sample SHS iLAW draft below to test editing, formatting, and DOCX/PDF export now.';
      });
      return;
    }

    setState(() {
      _isGenerating = false;
      _inlineAlertIsError = true;
      _inlineAlertMessage =
          result.errorMessage ?? 'Unable to generate lesson plan right now.';
    });
  }

  void _handleLoadTemplateDraft() {
    if (!_validateStep1()) return;
    final durationMins = int.parse(_durationCtrl.text.trim());
    final template = IlawLessonPlan.buildTemplateSections(
      subject: _subjectCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      gradeLevel: _selectedGrade,
      quarter: _selectedQuarter,
      durationMinutes: durationMins,
      teachingStrategy: _strategyCtrl.text.trim(),
      learningCompetency: _competencyCtrl.text.trim(),
    );

    setState(() {
      _showMissingKeysPrompt = false;
      _outcomesCtrl.text = template.intendedOutcomes;
      _contentCtrl.text = template.learningContent;
      _assessmentCtrl.text = template.assessment;
      _workCtrl.text = template.workExperiences;
      _outcomesError = null;
      _contentError = null;
      _assessmentError = null;
      _workError = null;
      _status = IlawPlanStatus.draft;
      _step = IlawWizardStep.reviewEdit;
      _inlineAlertIsError = false;
      _inlineAlertMessage =
          'Structured SHS iLAW draft loaded. Customize any section below before approving.';
    });
  }

  IlawLessonPlan _buildCurrentPlanModel(IlawPlanStatus targetStatus) {
    final teacher = widget.currentTeacher;
    final durationMins = int.tryParse(_durationCtrl.text.trim()) ?? 60;
    return IlawLessonPlan(
      id: _planId,
      teacherId: teacher?.id ?? '',
      teacherName: teacher?.fullName ?? 'Subject Teacher',
      gradeLevel: _selectedGrade,
      quarter: _selectedQuarter,
      subject: _subjectCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      durationMinutes: durationMins,
      teachingStrategy: _strategyCtrl.text.trim(),
      learningCompetency: _competencyCtrl.text.trim(),
      intendedOutcomes: _outcomesCtrl.text.trim(),
      learningContent: _contentCtrl.text.trim(),
      assessment: _assessmentCtrl.text.trim(),
      workExperiences: _workCtrl.text.trim(),
      status: targetStatus,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _handleSaveDraft() async {
    if (!_validateStep2(requireCompleteSections: false)) return;

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
        _inlineAlertMessage =
            'Saved privately to your teacher lesson plan drafts.';
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

  Future<void> _handleApproveAndFormat() async {
    if (!_validateStep2(requireCompleteSections: true)) return;

    setState(() {
      _isSaving = true;
      _inlineAlertMessage = null;
      _exportFeedbackMessage = null;
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
    final dialogWidth = (screenSize.width - 32).clamp(320.0, 880.0);
    final dialogMaxHeight = (screenSize.height - 48).clamp(420.0, 820.0);

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
        subtitle =
            'Strengthened Senior High School Curriculum  •  Private to your account';
      case IlawWizardStep.reviewEdit:
        title = 'Teacher Review & Edit';
        subtitle =
            'Refine the AI-generated sections before formatting into official iLAW.';
      case IlawWizardStep.previewExport:
        title = 'Approved iLAW Format & Download';
        subtitle =
            'Minimalist print-ready layout  •  Choose Word (.docx) or PDF (.pdf)';
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
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: (_isGenerating || _isSaving)
                ? null
                : () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperBar(ThemeData theme) {
    final currentIdx = _step.index;
    final labels = const [
      '1. Lesson Details',
      '2. Review & Edit',
      '3. iLAW Format & Export',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List.generate(labels.length, (idx) {
          final isCurrent = idx == currentIdx;
          final isDone = idx < currentIdx;
          final badgeColor = isCurrent
              ? theme.colorScheme.primary
              : (isDone
                    ? AppTheme.catGreen
                    : theme.colorScheme.onSurface.withValues(alpha: 0.35));

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : (isDone
                            ? AppTheme.catGreen.withValues(alpha: 0.1)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCurrent || isDone
                        ? badgeColor.withValues(alpha: 0.4)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDone) ...[
                      const Icon(
                        Icons.check,
                        size: 13,
                        color: AppTheme.catGreen,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      labels[idx],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : (isDone
                                  ? AppTheme.catGreen
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.55,
                                    )),
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < labels.length - 1) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPinnedAlertRegion(ThemeData theme) {
    final hasInline = _inlineAlertMessage != null;
    final hasExport =
        _step == IlawWizardStep.previewExport && _exportFeedbackMessage != null;
    if (!hasInline && !hasExport) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasInline)
            _buildInlineStatusBox(
              theme,
              message: _inlineAlertMessage!,
              isError: _inlineAlertIsError,
              trailing: (_step == IlawWizardStep.details &&
                      _showMissingKeysPrompt)
                  ? AppButton.outline(
                      label: 'Continue with Sample SHS Draft',
                      icon: Icons.edit_note_outlined,
                      isSmall: true,
                      onPressed: _handleLoadTemplateDraft,
                    )
                  : null,
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
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildGradeDropdown(theme)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildQuarterDropdown(theme)),
                ],
              )
            else ...[
              _buildGradeDropdown(theme),
              const SizedBox(height: 16),
              _buildQuarterDropdown(theme),
            ],
            const SizedBox(height: 16),
            _buildValidatedTextField(
              theme: theme,
              fieldKey: const Key('ilaw_subject_field'),
              label: 'Subject *',
              hint: 'e.g., General Mathematics or Oral Communication',
              controller: _subjectCtrl,
              errorText: _subjectError,
              maxLength: IlawLessonPlanValidator.maxSubjectLength,
              showCounter: true,
              onChanged: (_) {
                if (_subjectError != null) {
                  setState(() => _subjectError = null);
                }
              },
            ),
            if (_cachedTeacherSubjects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _cachedTeacherSubjects.map((sub) {
                  return ActionChip(
                    label: Text(sub, style: const TextStyle(fontSize: 11.5)),
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
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDurationSection(theme)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStrategySection(theme)),
                ],
              )
            else ...[
              _buildDurationSection(theme),
              const SizedBox(height: 16),
              _buildStrategySection(theme),
            ],
            const SizedBox(height: 16),
            _buildValidatedTextField(
              theme: theme,
              fieldKey: const Key('ilaw_competency_field'),
              label: 'Learning Competency / Specific Instructions (Optional)',
              hint:
                  'e.g., Distinguishes rational function, rational equation, and rational inequality.',
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

  Widget _buildDurationSection(ThemeData theme) {
    const presets = ['45', '60', '90', '120'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidatedTextField(
          theme: theme,
          fieldKey: const Key('ilaw_duration_field'),
          label: 'Duration (Minutes) *',
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

  Widget _buildStrategySection(ThemeData theme) {
    return _buildValidatedTextField(
      theme: theme,
      fieldKey: const Key('ilaw_strategy_field'),
      label: 'Teaching Approach (Optional)',
      hint: 'e.g., Inquiry-Based / Collaborative',
      controller: _strategyCtrl,
      errorText: _strategyError,
      maxLength: IlawLessonPlanValidator.maxStrategyLength,
      onChanged: (_) {
        if (_strategyError != null) {
          setState(() => _strategyError = null);
        }
      },
    );
  }

  Widget _buildGradeDropdown(ThemeData theme) {
    return _buildDropdownField(
      theme: theme,
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

  Widget _buildQuarterDropdown(ThemeData theme) {
    return _buildDropdownField(
      theme: theme,
      label: 'Quarter *',
      value: _selectedQuarter,
      items: IlawLessonPlanValidator.allowedQuarters,
      errorText: _quarterError,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedQuarter = val;
            _quarterError = null;
          });
        }
      },
    );
  }

  Widget _buildStep2ReviewEdit(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final topicInput = _buildValidatedTextField(
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
              );
              final durationInput = _buildValidatedTextField(
                theme: theme,
                fieldKey: const Key('ilaw_review_duration_field'),
                label: 'Duration (Mins) *',
                hint: '60',
                controller: _durationCtrl,
                errorText: _durationError,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  if (_durationError != null) {
                    setState(() => _durationError = null);
                  }
                },
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_subjectCtrl.text.trim()}  •  $_selectedGrade  •  $_selectedQuarter',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: topicInput),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: durationInput),
                      ],
                    )
                  else ...[
                    topicInput,
                    const SizedBox(height: 12),
                    durationInput,
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildIlawEditableSectionCard(
          theme: theme,
          badgeLetter: 'I',
          title: 'Intended Learning Outcomes (Objectives) *',
          subtitle: 'Clear, measurable SHS learning outcomes for this session.',
          fieldKey: const Key('ilaw_edit_outcomes_field'),
          controller: _outcomesCtrl,
          errorText: _outcomesError,
          maxLines: 4,
          maxLength: IlawLessonPlanValidator.maxStandardSectionLength,
          onChanged: () {
            if (_outcomesError != null) setState(() => _outcomesError = null);
          },
        ),
        const SizedBox(height: 16),
        _buildIlawEditableSectionCard(
          theme: theme,
          badgeLetter: 'L',
          title: 'Learning Content & Resources *',
          subtitle:
              'Key concepts, SHS curriculum references, and instructional materials.',
          fieldKey: const Key('ilaw_edit_content_field'),
          controller: _contentCtrl,
          errorText: _contentError,
          maxLines: 4,
          maxLength: IlawLessonPlanValidator.maxStandardSectionLength,
          onChanged: () {
            if (_contentError != null) setState(() => _contentError = null);
          },
        ),
        const SizedBox(height: 16),
        _buildIlawEditableSectionCard(
          theme: theme,
          badgeLetter: 'A',
          title: 'Assessment & Learning Activities *',
          subtitle:
              'Formative or performance evaluation tasks and grading focus.',
          fieldKey: const Key('ilaw_edit_assessment_field'),
          controller: _assessmentCtrl,
          errorText: _assessmentError,
          maxLines: 4,
          maxLength: IlawLessonPlanValidator.maxStandardSectionLength,
          onChanged: () {
            if (_assessmentError != null) {
              setState(() => _assessmentError = null);
            }
          },
        ),
        const SizedBox(height: 16),
        _buildIlawEditableSectionCard(
          theme: theme,
          badgeLetter: 'W',
          title: 'Work / Learning Experiences (Procedure) *',
          subtitle:
              'Step-by-step classroom flow, learner engagement, and assignment.',
          fieldKey: const Key('ilaw_edit_work_field'),
          controller: _workCtrl,
          errorText: _workError,
          maxLines: 6,
          maxLength: IlawLessonPlanValidator.maxProcedureSectionLength,
          onChanged: () {
            if (_workError != null) setState(() => _workError = null);
          },
        ),
      ],
    );
  }

  Widget _buildIlawEditableSectionCard({
    required ThemeData theme,
    required String badgeLetter,
    required String title,
    required String subtitle,
    required Key fieldKey,
    required TextEditingController controller,
    required String? errorText,
    required int maxLines,
    required int maxLength,
    required VoidCallback onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorText != null
              ? _errorRed
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          width: errorText != null ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLetter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.58,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildValidatedTextField(
            theme: theme,
            fieldKey: fieldKey,
            label: '',
            hint: 'Enter $title...',
            controller: controller,
            errorText: errorText,
            maxLines: maxLines,
            maxLength: maxLength,
            showCounter: true,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3MinimalistPreview(ThemeData theme) {
    final plan = _buildCurrentPlanModel(_status);
    final teacherName = plan.teacherName.isNotEmpty
        ? plan.teacherName
        : 'Subject Teacher';
    final dateStr = plan.updatedAt.toLocal().toString().split(' ').first;
    final strategy = plan.teachingStrategy.isNotEmpty
        ? plan.teachingStrategy
        : 'Collaborative / Inquiry-Based';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Minimalist A4-styled Paper Sheet
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 740),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 3.5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'DEPARTMENT OF EDUCATION  •  SENIOR HIGH SCHOOL NEW CURRICULUM',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'iLAW LESSON PLAN',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  StatusBadge(
                    text: 'Approved',
                    backgroundColor: AppTheme.catGreen.withValues(alpha: 0.12),
                    textColor: AppTheme.catGreen,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Minimalist Metadata Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewMetaPairRow(
                      theme,
                      leftLabel: 'Subject',
                      leftValue: plan.subject,
                      rightLabel: 'Grade & Quarter',
                      rightValue: '${plan.gradeLevel}  •  ${plan.quarter}',
                    ),
                    const SizedBox(height: 10),
                    _buildPreviewMetaPairRow(
                      theme,
                      leftLabel: 'Lesson Topic',
                      leftValue: plan.topic,
                      rightLabel: 'Time Allotment',
                      rightValue: '${plan.durationMinutes} Minutes',
                    ),
                    const SizedBox(height: 10),
                    _buildPreviewMetaPairRow(
                      theme,
                      leftLabel: 'Prepared By',
                      leftValue: teacherName,
                      rightLabel: 'Date Prepared',
                      rightValue: dateStr,
                    ),
                    const SizedBox(height: 10),
                    _buildPreviewMetaPairRow(
                      theme,
                      leftLabel: 'Approach',
                      leftValue: strategy,
                      rightLabel: 'Format Standard',
                      rightValue: 'SHS Strengthened iLAW',
                    ),
                    if (plan.learningCompetency.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      Text(
                        'Learning Competency',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.learningCompetency,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _buildPreviewIlawBlock(
                theme,
                code: 'I',
                heading: 'INTENDED LEARNING OUTCOMES (OBJECTIVES)',
                content: plan.intendedOutcomes,
              ),
              const SizedBox(height: 18),
              _buildPreviewIlawBlock(
                theme,
                code: 'L',
                heading: 'LEARNING CONTENT & RESOURCES',
                content: plan.learningContent,
              ),
              const SizedBox(height: 18),
              _buildPreviewIlawBlock(
                theme,
                code: 'A',
                heading: 'ASSESSMENT & LEARNING ACTIVITIES',
                content: plan.assessment,
              ),
              const SizedBox(height: 18),
              _buildPreviewIlawBlock(
                theme,
                code: 'W',
                heading: 'WORK / LEARNING EXPERIENCES (PROCEDURE)',
                content: plan.workExperiences,
              ),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 20),
              Text(
                'Prepared and Approved by:',
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                teacherName.toUpperCase(),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Senior High School Subject Teacher',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewMetaPairRow(
    ThemeData theme, {
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSingleMetaItem(theme, leftLabel, leftValue),
              const SizedBox(height: 8),
              _buildSingleMetaItem(theme, rightLabel, rightValue),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSingleMetaItem(theme, leftLabel, leftValue)),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSingleMetaItem(theme, rightLabel, rightValue),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleMetaItem(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewIlawBlock(
    ThemeData theme, {
    required String code,
    required String heading,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$code.  $heading',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.58,
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton.outline(
                  label: 'Lesson Details',
                  icon: Icons.arrow_back,
                  onPressed: (_isGenerating || _isSaving)
                      ? null
                      : () => setState(() {
                          _inlineAlertMessage = null;
                          _step = IlawWizardStep.details;
                        }),
                ),
                AppButton.outline(
                  label: _isGenerating ? 'Regenerating...' : 'Regenerate AI',
                  icon: Icons.refresh,
                  isLoading: _isGenerating,
                  onPressed: (_isGenerating || _isSaving)
                      ? null
                      : _handleGenerateWithAi,
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppButton.outline(
                  label: 'Save as Draft',
                  icon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: (_isGenerating || _isSaving)
                      ? null
                      : _handleSaveDraft,
                ),
                AppButton.success(
                  label: 'Approve & Format iLAW',
                  icon: Icons.check_circle_outline,
                  isLoading: _isSaving,
                  onPressed: (_isGenerating || _isSaving)
                      ? null
                      : _handleApproveAndFormat,
                ),
              ],
            ),
          ],
        );

      case IlawWizardStep.previewExport:
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            AppButton.outline(
              label: 'Back to Edit',
              icon: Icons.arrow_back,
              onPressed: (_isExportingDocx || _isExportingPdf)
                  ? null
                  : () => setState(() {
                      _exportFeedbackMessage = null;
                      _step = IlawWizardStep.reviewEdit;
                    }),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppButton.primary(
                  label: 'Download Word (.docx)',
                  icon: Icons.description_outlined,
                  isLoading: _isExportingDocx,
                  onPressed: (_isExportingDocx || _isExportingPdf)
                      ? null
                      : () => _handleExport(IlawExportFormat.docx),
                ),
                AppButton.primary(
                  label: 'Download PDF (.pdf)',
                  icon: Icons.picture_as_pdf_outlined,
                  backgroundColor: AppTheme.catSlate,
                  isLoading: _isExportingPdf,
                  onPressed: (_isExportingDocx || _isExportingPdf)
                      ? null
                      : () => _handleExport(IlawExportFormat.pdf),
                ),
                AppButton.outline(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildInlineStatusBox(
    ThemeData theme, {
    required String message,
    required bool isError,
    Widget? trailing,
  }) {
    final accent = isError ? _errorRed : theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: isError ? _errorRed : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ],
      ),
    );
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
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
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
        if (label.isEmpty && showCounter && maxLength != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<TextEditingValue>(
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
                        : theme.colorScheme.onSurface.withValues(alpha: 0.48),
                  ),
                );
              },
            ),
          ),
        ],
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
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 13.5)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
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
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
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
