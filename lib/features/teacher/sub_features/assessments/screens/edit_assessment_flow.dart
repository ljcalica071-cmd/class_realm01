import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';

class EditAssessmentFlowDialog extends StatefulWidget {
  final QuizOrExamModel assessment;
  final FutureOr<void> Function() onAssessmentUpdated;

  const EditAssessmentFlowDialog({
    super.key,
    required this.assessment,
    required this.onAssessmentUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required QuizOrExamModel assessment,
    required FutureOr<void> Function() onAssessmentUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditAssessmentFlowDialog(
        assessment: assessment,
        onAssessmentUpdated: onAssessmentUpdated,
      ),
    );
  }

  @override
  State<EditAssessmentFlowDialog> createState() =>
      _EditAssessmentFlowDialogState();
}

class _EditAssessmentFlowDialogState extends State<EditAssessmentFlowDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _hpsCtrl;
  late List<QuestionModel> _questions;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _scheduleError;
  bool _isSaving = false;

  bool get _isInPerson => widget.assessment.completionMode == 'in_person';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.assessment.title);
    _descCtrl = TextEditingController(text: widget.assessment.description);
    _durationCtrl = TextEditingController(
      text: widget.assessment.durationMinutes.toString(),
    );
    _hpsCtrl = TextEditingController(
      text: widget.assessment.totalPoints.toInt().toString(),
    );
    _questions = List.from(widget.assessment.questions);

    final localSched = widget.assessment.scheduleDate.toLocal();
    _selectedDate = DateTime(localSched.year, localSched.month, localSched.day);
    _selectedTime = TimeOfDay.fromDateTime(localSched);
    _titleCtrl.addListener(_onFieldChanged);
    _descCtrl.addListener(_onFieldChanged);
    _durationCtrl.addListener(_onFieldChanged);
    _hpsCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasEditChanges {
    final a = widget.assessment;
    if (_titleCtrl.text.trim() != a.title.trim()) return true;
    if (_descCtrl.text.trim() != a.description.trim()) return true;
    if (_isInPerson) {
      final hps = int.tryParse(_hpsCtrl.text.trim());
      if (hps != a.totalPoints.toInt()) return true;
    } else {
      final dur = int.tryParse(_durationCtrl.text.trim());
      if (dur != a.durationMinutes) return true;
    }
    if (!isSameClassworkSchedule(
      a.scheduleDate,
      _candidateSchedule,
      isInPerson: _isInPerson,
    )) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onFieldChanged);
    _descCtrl.removeListener(_onFieldChanged);
    _durationCtrl.removeListener(_onFieldChanged);
    _hpsCtrl.removeListener(_onFieldChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _hpsCtrl.dispose();
    super.dispose();
  }

  String get _slotDisplayLabel {
    final col = widget.assessment.gradebookColumnIndex;
    if (widget.assessment.isExam) {
      if (col == 1 || widget.assessment.examType == 'st1') return 'ST1';
      if (col == 2 || widget.assessment.examType == 'st2') return 'ST2';
      if (col == 3 || widget.assessment.examType == 'term_exam') return 'TE';
      return 'Exam';
    }
    return col != null ? 'WW $col' : 'WW';
  }

  DateTime get _candidateSchedule {
    if (_isInPerson) {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
      );
    }
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  String? _validateOnlineScheduleIfChanged(DateTime candidate) {
    if (_isInPerson) return null;
    final isChanged = !isSameClassworkSchedule(
      widget.assessment.scheduleDate,
      candidate,
      isInPerson: false,
    );
    if (!isChanged) return null;
    if (!candidate.isAfter(DateTime.now())) {
      return 'Updated schedule must be in the future.';
    }
    return null;
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    final candidate = _candidateSchedule;
    final schedErr = _validateOnlineScheduleIfChanged(candidate);
    setState(() => _scheduleError = schedErr);
    if (!formValid || schedErr != null) return;

    final title = _titleCtrl.text.trim();
    final instructions = _descCtrl.text.trim();
    final duration = _isInPerson
        ? 0
        : (int.tryParse(_durationCtrl.text.trim()) ??
              widget.assessment.durationMinutes);
    final hpsPoints = _isInPerson
        ? (int.tryParse(_hpsCtrl.text.trim()) ??
              widget.assessment.totalPoints.toInt())
        : widget.assessment.totalPoints.toInt();

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService().client;
      if (_isInPerson) {
        final existing = await client
            .from('classwork_items')
            .select(
              'id, subject_offering_id, term_number, gradebook_column_index, grading_category',
            )
            .eq('id', widget.assessment.id)
            .eq('is_archived', false)
            .maybeSingle();

        if (existing == null) {
          AppDataCache.instance.invalidatePrefix('teacher_assessments_');
          AppDataCache.instance.invalidatePrefix('teacher_activities_');
          AppDataCache.instance.invalidatePrefix('student_dashboard_');
          AppDataCache.instance.invalidatePrefix('gradebook_');
          if (!mounted) return;
          Navigator.of(context).pop();
          await AppModals.showWarningDialog(
            context: context,
            title: 'Assessment Removed',
            message:
                'This assessment was already deleted from the database and can no longer be edited.',
          );
          return;
        }

        await client
            .from('classwork_items')
            .update({
              'title': title,
              'description': instructions,
              'instructions': instructions,
              'max_score': hpsPoints,
              'deadline': candidate.toUtc().toIso8601String(),
              'updated_instructions_at': DateTime.now()
                  .toUtc()
                  .toIso8601String(),
            })
            .eq('id', widget.assessment.id);

        final offeringId =
            existing['subject_offering_id']?.toString() ??
            widget.assessment.subjectOfferingId;
        final termNum =
            (existing['term_number'] as num?)?.toInt() ??
            widget.assessment.termNumber;
        final colIdx =
            (existing['gradebook_column_index'] as num?)?.toInt() ??
            widget.assessment.gradebookColumnIndex;
        final catKey =
            existing['grading_category']?.toString().toLowerCase() ??
            (widget.assessment.isExam ? 'ex' : 'ww');

        if (offeringId != null && colIdx != null) {
          final sheet =
              await SubjectRepository.instance.getGradebookTermSheet(
                offeringId,
                termNum,
              ) ??
              <String, dynamic>{};
          final hps = Map<String, dynamic>.from(sheet['hps'] as Map? ?? {});
          final catHps = Map<String, dynamic>.from(hps[catKey] as Map? ?? {});
          final colKey = catKey == 'ex'
              ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
              : colIdx.toString();
          catHps[colKey] = hpsPoints;
          hps[catKey] = catHps;
          sheet['hps'] = hps;
          await SubjectRepository.instance.saveGradebookTermSheet(
            offeringId,
            termNum,
            sheet,
          );
        }
      } else {
        final existing = await client
            .from('digital_assessments')
            .select('id')
            .eq('id', widget.assessment.id)
            .eq('is_archived', false)
            .maybeSingle();

        if (existing == null) {
          AppDataCache.instance.invalidatePrefix('teacher_assessments_');
          AppDataCache.instance.invalidatePrefix('teacher_activities_');
          AppDataCache.instance.invalidatePrefix('student_dashboard_');
          AppDataCache.instance.invalidatePrefix('gradebook_');
          if (!mounted) return;
          Navigator.of(context).pop();
          await AppModals.showWarningDialog(
            context: context,
            title: 'Assessment Removed',
            message:
                'This assessment was already deleted from the database and can no longer be edited.',
          );
          return;
        }

        final newDeadlineUtc = candidate
            .add(Duration(minutes: duration))
            .toUtc()
            .toIso8601String();

        await client
            .from('digital_assessments')
            .update({
              'title': title,
              'description': instructions,
              'instructions': instructions,
              'time_limit_minutes': duration,
              'available_from': candidate.toUtc().toIso8601String(),
              'deadline': newDeadlineUtc,
            })
            .eq('id', widget.assessment.id);

        await client
            .from('classwork_items')
            .update({
              'title': title,
              'description': instructions,
              'instructions': instructions,
              'deadline': newDeadlineUtc,
              'updated_instructions_at': DateTime.now()
                  .toUtc()
                  .toIso8601String(),
            })
            .eq('id', widget.assessment.id);
      }

      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
      AppDataCache.instance.invalidatePrefix('gradebook_');
      TeacherGradebookTab.gradebookRefreshNotifier.value++;

      await widget.onAssessmentUpdated();
      if (!mounted) return;
      final rootCtx = Navigator.of(context).context;
      Navigator.of(context).pop();

      if (rootCtx.mounted) {
        await AppModals.showSuccessDialog(
          context: rootCtx,
          title: 'Assessment Updated',
          message: 'Changes to "$title" have been saved and synchronized.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await AppModals.showErrorDialog(
        context: context,
        title: 'Save Failed',
        message: 'Could not save assessment changes: $e',
      );
    }
  }

  Widget _buildLockedField(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
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
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final originalLocal = widget.assessment.scheduleDate.toLocal();
    final isSelectedToday =
        _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 750,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit ${widget.assessment.isExam ? "Periodical Examination" : "Unit Quiz"}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isInPerson
                                ? 'Update title, scheduled date, total points (HPS), and instructions'
                                : 'Update title, schedule, duration, and instructions',
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
                      icon: const Icon(Icons.close),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: widget.assessment.isExam
                            ? 'Examination Title *'
                            : 'Quiz Title *',
                        controller: _titleCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Assessment title is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLockedField(
                              context,
                              label: 'Section (Locked)',
                              value: widget.assessment.section,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildLockedField(
                              context,
                              label: 'Gradebook Term (Locked)',
                              value: 'Term ${widget.assessment.termNumber}',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildLockedField(
                              context,
                              label: 'Gradebook Slot (Locked)',
                              value: _slotDisplayLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isInPerson
                                      ? 'Update Date *'
                                      : 'Update Schedule Date *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _isSaving
                                      ? null
                                      : () async {
                                          final tNow = DateTime.now();
                                          final tToday = DateTime(
                                            tNow.year,
                                            tNow.month,
                                            tNow.day,
                                          );
                                          final picked =
                                              await showAppDatePickerDialog(
                                                context,
                                                initialDate: _selectedDate,
                                                firstDate: _isInPerson
                                                    ? DateTime(
                                                        tToday.year - 1,
                                                        1,
                                                        1,
                                                      )
                                                    : tToday,
                                                lastDate: DateTime(
                                                  tToday.year + 5,
                                                  12,
                                                  31,
                                                ),
                                                title: _isInPerson
                                                    ? 'Update Date'
                                                    : 'Update Schedule',
                                                icon: Icons
                                                    .event_available_outlined,
                                                highlightDate: originalLocal,
                                                highlightLabel: _isInPerson
                                                    ? 'Current Date'
                                                    : 'Current Schedule',
                                              );
                                          if (picked != null && mounted) {
                                            setState(() {
                                              _selectedDate = picked;
                                              _scheduleError =
                                                  _validateOnlineScheduleIfChanged(
                                                    _candidateSchedule,
                                                  );
                                            });
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _scheduleError != null
                                            ? const Color(0xFFDC2626)
                                            : theme.colorScheme.outline
                                                  .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 18,
                                          color: Color(0xFF0F8A48),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isInPerson) ...[
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: AppTimePickerField(
                                key: ValueKey(
                                  '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}-${_selectedTime.hour}-${_selectedTime.minute}',
                                ),
                                label: 'Start Time *',
                                initialTime: _selectedTime,
                                minTime: isSelectedToday
                                    ? TimeOfDay.fromDateTime(
                                        DateTime.now().add(
                                          const Duration(minutes: 1),
                                        ),
                                      )
                                    : null,
                                onTimeSelected: (t) {
                                  setState(() {
                                    _selectedTime = t;
                                    _scheduleError =
                                        _validateOnlineScheduleIfChanged(
                                          _candidateSchedule,
                                        );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 1,
                              child: AppTextField(
                                label: 'Duration (Mins) *',
                                controller: _durationCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final d = int.tryParse(val.trim());
                                  if (d == null || d < 1) {
                                    return 'Min 1 min';
                                  }
                                  if (d > 120) {
                                    return 'Max 120 mins';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                label: 'Total Points (HPS) *',
                                controller: _hpsCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Total points is required.';
                                  }
                                  final p = int.tryParse(val.trim());
                                  if (p == null || p < 1 || p > 100) {
                                    return 'Enter 1 to 100 points.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_scheduleError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _scheduleError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ExpandableInstructionsInputField(
                        label: 'Instructions & Guidelines *',
                        hint:
                            'Provide test-taking guidelines or instructions...',
                        controller: _descCtrl,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: AppValidators.validateClassworkInstructions,
                      ),
                      if (!_isInPerson) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Questions & Answer Keys (${_questions.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._questions.asMap().entries.map((entry) {
                          final i = entry.key + 1;
                          final q = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text(
                                    '$i',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    q.questionText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Key: ${q.correctAnswer} (${q.points} pts)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.03)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    AppPrimaryButton(
                      label: _isSaving ? 'Saving...' : 'Save Changes',
                      height: 40,
                      onPressed: (_isSaving || !_hasEditChanges)
                          ? null
                          : _saveChanges,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
