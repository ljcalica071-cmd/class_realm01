import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';
import '../../../widgets/common/app_text_field.dart';

class CreateRequirementFlowDialog extends StatefulWidget {
  final VoidCallback onRequirementCreated;
  final String initialSection;
  final ActivityModel? existingTask;
  final bool isPerformanceTask;

  const CreateRequirementFlowDialog({
    super.key,
    required this.onRequirementCreated,
    this.initialSection = 'Section A',
    this.existingTask,
    this.isPerformanceTask = true,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRequirementCreated,
    String initialSection = 'Section A',
    ActivityModel? existingTask,
    bool isPerformanceTask = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateRequirementFlowDialog(
        onRequirementCreated: onRequirementCreated,
        initialSection: initialSection,
        existingTask: existingTask,
        isPerformanceTask: isPerformanceTask,
      ),
    );
  }

  @override
  State<CreateRequirementFlowDialog> createState() =>
      _CreateRequirementFlowDialogState();
}

class _CreateRequirementFlowDialogState
    extends State<CreateRequirementFlowDialog> {
  final _titleCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _maxScoreCtrl = TextEditingController(text: '100');
  String? _attachmentName;
  final Set<String> _selectedSections = {};
  final Map<String, DateTime> _sectionDeadlines = {};

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleCtrl.text = task?.title ?? '';
    _instructionsCtrl.text = task?.instructions ?? '';
    _maxScoreCtrl.text = task?.maxScore.toInt().toString() ?? '100';
    _attachmentName = task?.attachmentName;
    if (task != null) {
      _selectedSections.addAll(task.assignedSections);
      _sectionDeadlines.addAll(task.sectionDeadlines);
    } else {
      _selectedSections.add(widget.initialSection);
      _sectionDeadlines[widget.initialSection] = DateTime.now().add(
        const Duration(days: 7),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    _maxScoreCtrl.dispose();
    super.dispose();
  }

  void _savePerformanceTask() {
    if (_titleCtrl.text.trim().isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title:
            '${widget.isPerformanceTask ? 'Performance Task' : 'Activity / Assignment'} Title Required',
        message: 'Please enter a valid title.',
      );
      return;
    }
    if (_selectedSections.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Section Required',
        message: 'Select at least one section for this performance task.',
      );
      return;
    }

    final maxScore = double.tryParse(_maxScoreCtrl.text.trim());
    if (maxScore == null || maxScore < 10 || maxScore > 100) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid Total Points',
        message: 'Total points must be a whole number from 10 to 100.',
      );
      return;
    }

    final newTask = ActivityModel(
      id:
          widget.existingTask?.id ??
          'classwork_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      description: '',
      instructions: _instructionsCtrl.text.trim(),
      subject: 'General Mathematics',
      gradeLevel: 'Grade 11',
      section: _selectedSections.join(', '),
      deadline: _sectionDeadlines.values.first,
      maxScore: maxScore,
      isPublished: true,
      isRequirement: widget.isPerformanceTask,
      attachmentName: _attachmentName,
      sectionDeadlines: Map<String, DateTime>.from(_sectionDeadlines),
    );

    if (widget.existingTask == null) {
      MockDatabase.instance.addActivity(newTask);
    } else {
      final index = MockDatabase.instance.activities.indexWhere(
        (activity) => activity.id == widget.existingTask!.id,
      );
      if (index != -1) {
        MockDatabase.instance.activities[index] = newTask;
      }
    }
    widget.onRequirementCreated();
    Navigator.of(context).pop();

    AppModals.showSuccessDialog(
      context: context,
      title: widget.existingTask == null
          ? '${widget.isPerformanceTask ? 'Performance Task' : 'Activity / Assignment'} Published'
          : '${widget.isPerformanceTask ? 'Performance Task' : 'Activity / Assignment'} Updated',
      message:
          '${widget.isPerformanceTask ? 'Performance task' : 'Activity / Assignment'} "${newTask.title}" has been successfully ${widget.existingTask == null ? 'published' : 'updated'} for ${_sectionReqText(newTask.section)}.',
    );
  }

  String _sectionReqText(String section) => section;

  Future<void> _selectDeadline(String section) async {
    final current = _sectionDeadlines[section]!;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
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
    });
  }

  String _formatDeadline(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${date.year} ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Widget _buildSectionChoice(String section) {
    final isSelected = _selectedSections.contains(section);
    return InkWell(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedSections.remove(section);
          _sectionDeadlines.remove(section);
        } else {
          _selectedSections.add(section);
          _sectionDeadlines[section] = DateTime.now().add(
            const Duration(days: 7),
          );
        }
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              section,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDeadlineRow(String section) {
    final deadline =
        _sectionDeadlines[section] ??
        DateTime.now().add(const Duration(days: 7));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _buildSectionChoice(section)),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _selectedSections.contains(section)
                  ? () => _selectDeadline(section)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDeadline(deadline),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        key: ValueKey(_formatDeadline(deadline)),
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          children: [
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
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingTask == null
                              ? 'Create ${widget.isPerformanceTask ? 'Performance Task' : 'Activity / Assignment'}'
                              : 'Edit ${widget.isPerformanceTask ? 'Performance Task' : 'Activity / Assignment'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.existingTask == null
                              ? 'Assign ${widget.isPerformanceTask ? 'graded performance task' : 'an activity or assignment'} to a Senior High School section'
                              : 'Update the ${widget.isPerformanceTask ? 'performance task' : 'activity / assignment'} details and deadlines',
                          style: TextStyle(
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: widget.isPerformanceTask
                          ? 'Performance Task Title'
                          : 'Activity / Assignment Title',
                      hint: widget.isPerformanceTask
                          ? 'e.g. Mathematical Modeling Portfolio'
                          : 'e.g. Rational Functions Problem Set',
                      controller: _titleCtrl,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Section & Due Date / Time',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildSectionDeadlineRow('Section A'),
                        _buildSectionDeadlineRow('Section B'),
                        if (_selectedSections.isEmpty)
                          const Text(
                            'Select at least one section',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 280,
                          child: AppTextField(
                            label: 'Total Points',
                            hint: '10-100',
                            controller: _maxScoreCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: widget.isPerformanceTask
                          ? 'Detailed Instructions & Rubrics'
                          : 'Detailed Instructions',
                      hint: 'Provide step-by-step instructions for students...',
                      controller: _instructionsCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _attachmentName =
                                  '${widget.isPerformanceTask ? 'Performance_Task' : 'Activity'}_Instructions.pdf',
                            ),
                            icon: const Icon(Icons.attach_file, size: 18),
                            label: const Text('Attach PDF/DOCX'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _attachmentName ?? 'No file attached',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                mainAxisAlignment: MainAxisAlignment.end,
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
                  AppPrimaryButton(
                    label: widget.existingTask == null
                        ? 'Publish ${widget.isPerformanceTask ? 'Performance Task' : 'Activity / Assignment'}'
                        : 'Save ${widget.isPerformanceTask ? 'Performance Task' : 'Activity / Assignment'}',
                    icon: Icons.publish,
                    height: 40,
                    onPressed: _savePerformanceTask,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
