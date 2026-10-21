import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/data/repositories/supabase_teacher_classwork_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';

class CreateRequirementFlowDialog extends StatefulWidget {
  final VoidCallback onRequirementCreated;
  final String initialSection;
  final ActivityModel? existingTask;
  final bool isPerformanceTask;
  final TeacherClassworkRepository? repository;
  final List<Map<String, dynamic>>? initialOfferings;

  const CreateRequirementFlowDialog({
    super.key,
    required this.onRequirementCreated,
    this.initialSection = '',
    this.existingTask,
    this.isPerformanceTask = true,
    this.repository,
    this.initialOfferings,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRequirementCreated,
    String initialSection = '',
    ActivityModel? existingTask,
    bool isPerformanceTask = true,
    TeacherClassworkRepository? repository,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateRequirementFlowDialog(
        onRequirementCreated: onRequirementCreated,
        initialSection: initialSection,
        existingTask: existingTask,
        isPerformanceTask: isPerformanceTask,
        repository: repository,
      ),
    );
  }

  @override
  State<CreateRequirementFlowDialog> createState() =>
      _CreateRequirementFlowDialogState();
}

class _CreateRequirementFlowDialogState
    extends State<CreateRequirementFlowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _maxScoreCtrl = TextEditingController(text: '100');

  String? _selectedOfferingId;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  List<Map<String, dynamic>> _offerings = [];
  bool _isLoadingOfferings = true;

  // Attachment state
  String? _attachmentName;
  Uint8List? _pickedFileBytes;
  String? _pickedFileName;
  String? _pickedFileMimeType;
  int? _pickedFileSizeBytes;
  bool _removeExistingAttachment = false;

  // Inline error state
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  String? _fileError;
  String? _offeringError;
  String? _formSubmitError;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleCtrl.text = task?.title ?? '';
    _instructionsCtrl.text = task?.instructions ?? '';
    _maxScoreCtrl.text = task?.maxScore.toInt().toString() ?? '100';
    _attachmentName = task?.attachmentName;
    _pickedFileSizeBytes = task?.fileSizeBytes;
    if (task != null) {
      _deadline = task.deadline;
      _selectedOfferingId = task.subjectOfferingId;
    }

    if (widget.initialOfferings != null) {
      _offerings = List<Map<String, dynamic>>.from(widget.initialOfferings!);
      _isLoadingOfferings = false;
      _initializeSelectedOffering();
    } else {
      _loadTeacherOfferings();
    }
  }

  void _initializeSelectedOffering() {
    if (_selectedOfferingId == null && _offerings.isNotEmpty) {
      if (widget.initialSection.isNotEmpty) {
        final match = _offerings.firstWhere(
          (o) => o['section_name']?.toString() == widget.initialSection,
          orElse: () => _offerings.first,
        );
        _selectedOfferingId = match['id']?.toString();
      } else {
        _selectedOfferingId = _offerings.first['id']?.toString();
      }
    }
  }

  Future<void> _loadTeacherOfferings() async {
    try {
      final teacherId = AuthRepository.instance.currentUser?.id;
      if (teacherId == null) {
        if (mounted) setState(() => _isLoadingOfferings = false);
        return;
      }
      final subjects =
          await SubjectRepository.instance.getTeacherSubjects(teacherId);
      if (!mounted) return;
      setState(() {
        _offerings = subjects;
        _isLoadingOfferings = false;
        _initializeSelectedOffering();
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingOfferings = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    _maxScoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _fileError = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // Picker cancelled; leave state unchanged
      }

      final file = result.files.first;
      final ext = (file.extension ?? '').toLowerCase();
      if (!['pdf', 'doc', 'docx'].contains(ext)) {
        setState(() {
          _fileError =
              "Unsupported file format '.$ext'. Only PDF, DOC, and DOCX are allowed.";
        });
        return;
      }

      if (file.size > 5 * 1024 * 1024) {
        setState(() {
          _fileError =
              'File size exceeds the 5 MiB limit (${(file.size / (1024 * 1024)).toStringAsFixed(2)} MiB > 5 MiB).';
        });
        return;
      }

      if (file.bytes == null) {
        setState(() {
          _fileError = 'Unable to read file bytes. Please try another file.';
        });
        return;
      }

      String mime = 'application/octet-stream';
      if (ext == 'pdf') {
        mime = 'application/pdf';
      } else if (ext == 'doc') {
        mime = 'application/msword';
      } else if (ext == 'docx') {
        mime =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }

      setState(() {
        _pickedFileBytes = file.bytes;
        _pickedFileName = file.name;
        _pickedFileMimeType = mime;
        _pickedFileSizeBytes = file.size;
        _attachmentName = file.name;
        _removeExistingAttachment = false;
        _fileError = null;
      });
    } catch (e) {
      setState(() {
        _fileError = 'Error selecting file: $e';
      });
    }
  }

  void _removeAttachment() {
    setState(() {
      _pickedFileBytes = null;
      _pickedFileName = null;
      _pickedFileMimeType = null;
      _pickedFileSizeBytes = null;
      _attachmentName = null;
      _removeExistingAttachment = true;
      _fileError = null;
    });
  }

  Future<void> _selectDeadline() async {
    final date = await showAppDatePickerDialog(
      context,
      initialDate: _deadline,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      title: 'Select Due Date',
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (!mounted || time == null) return;

    setState(() {
      _deadline = DateTime(
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';
  }

  Future<void> _submitForm() async {
    setState(() {
      _hasSubmitted = true;
      _formSubmitError = null;
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    final offeringValid = _selectedOfferingId != null &&
        _selectedOfferingId!.trim().isNotEmpty;

    if (!offeringValid) {
      setState(() => _offeringError = 'Select a subject offering.');
    } else {
      setState(() => _offeringError = null);
    }

    if (!formValid || !offeringValid || _fileError != null) {
      return;
    }

    final selectedOffering = _offerings.firstWhere(
      (o) => o['id']?.toString() == _selectedOfferingId,
      orElse: () => <String, dynamic>{},
    );

    final maxScore = int.parse(_maxScoreCtrl.text.trim()).toDouble();
    final subjectName = selectedOffering['subject_name']?.toString() ?? 'General Subject';
    final sectionName = selectedOffering['section_name']?.toString() ?? 'General Section';
    final gradeLevel = selectedOffering['grade_level']?.toString() ?? 'Grade 11';

    final task = ActivityModel(
      id: widget.existingTask?.id ?? '',
      title: _titleCtrl.text.trim(),
      description: '',
      instructions: _instructionsCtrl.text.trim(),
      subject: subjectName,
      gradeLevel: gradeLevel,
      section: sectionName,
      deadline: _deadline,
      maxScore: maxScore,
      isPublished: true,
      isRequirement: widget.isPerformanceTask,
      subjectOfferingId: _selectedOfferingId,
      attachmentName: _attachmentName,
      storagePath: widget.existingTask?.storagePath,
      mimeType: widget.existingTask?.mimeType,
      fileSizeBytes: widget.existingTask?.fileSizeBytes,
    );

    setState(() => _isSubmitting = true);

    final repo = widget.repository ?? SupabaseTeacherClassworkRepository.instance;
    try {
      await repo.saveActivity(
        activity: task,
        subjectOfferingId: _selectedOfferingId!,
        fileBytes: _pickedFileBytes,
        fileName: _pickedFileName,
        mimeType: _pickedFileMimeType,
        removeExistingAttachment: _removeExistingAttachment,
      );

      widget.onRequirementCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _formSubmitError = err.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existingTask != null;
    final typeName = widget.isPerformanceTask
        ? 'Performance Task'
        : 'Activity / Assignment';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.1)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_turned_in_outlined,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit $typeName' : 'Create $typeName',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          isEdit
                              ? 'Update the $typeName details, deadline, and attachment'
                              : 'Assign $typeName to a specific subject offering',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode: _hasSubmitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Title *
                      AppTextField(
                        label: widget.isPerformanceTask
                            ? 'Performance Task Title *'
                            : 'Activity / Assignment Title *',
                        hint: widget.isPerformanceTask
                            ? 'e.g. Mathematical Modeling Portfolio'
                            : 'e.g. Rational Functions Problem Set',
                        controller: _titleCtrl,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return 'Title is required.';
                          }
                          if (text.length > 100) {
                            return 'Title must not exceed 100 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Subject Offering & Due Date Selector
                      Text(
                        'Assigned Subject Offering & Due Date / Time *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),

                      if (_isLoadingOfferings)
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
                      else if (_offerings.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: const Text(
                            'No active subject offerings available. Please set up your classes first.',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Offering Dropdown
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedOfferingId,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    items: _offerings.map((offering) {
                                      final id = offering['id']?.toString() ?? '';
                                      final sub = offering['subject_name'] ?? '';
                                      final sec = offering['section_name'] ?? '';
                                      final grade = offering['grade_level'] != null
                                          ? ' (Grade ${offering['grade_level']})'
                                          : '';
                                      return DropdownMenuItem<String>(
                                        value: id,
                                        child: Text(
                                          '$sub - $sec$grade',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedOfferingId = val;
                                        _offeringError = null;
                                      });
                                    },
                                  ),
                                  if (_offeringError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        left: 12,
                                      ),
                                      child: Text(
                                        _offeringError!,
                                        style: const TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Due Date Button
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: _selectDeadline,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDeadline(_deadline),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_month_outlined,
                                        size: 18,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // 3. Total Points *
                      SizedBox(
                        width: 280,
                        child: AppTextField(
                          label: 'Total Points *',
                          hint: '10-100',
                          controller: _maxScoreCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return 'Total points is required.';
                            }
                            final score = int.tryParse(text);
                            if (score == null || score < 10 || score > 100) {
                              return 'Total points must be a whole number from 10 to 100.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Detailed Instructions *
                      AppTextField(
                        label: widget.isPerformanceTask
                            ? 'Detailed Instructions & Rubrics *'
                            : 'Detailed Instructions *',
                        hint: 'Provide step-by-step instructions for students...',
                        controller: _instructionsCtrl,
                        maxLines: 4,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return 'Detailed instructions are required.';
                          }
                          if (text.length > 1000) {
                            return 'Instructions must not exceed 1,000 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 5. Attachment Box (Optional, PDF, DOC, DOCX up to 5 MiB)
                      Text(
                        'Classwork Attachment (Optional - PDF, DOC, DOCX up to 5 MiB)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _fileError != null
                                ? const Color(0xFFEF4444)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.12),
                            width: _fileError != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _pickFile,
                              icon: const Icon(Icons.attach_file, size: 18),
                              label: Text(
                                _attachmentName == null
                                    ? 'Attach PDF/DOCX'
                                    : 'Replace File',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _attachmentName != null
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _pickedFileSizeBytes != null
                                                ? '$_attachmentName (${_formatFileSize(_pickedFileSizeBytes!)})'
                                                : _attachmentName!,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Color(0xFFEF4444),
                                          ),
                                          tooltip: 'Remove Attachment',
                                          onPressed: _isSubmitting
                                              ? null
                                              : _removeAttachment,
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'No file attached',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      if (_fileError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            _fileError!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                            ),
                          ),
                        ),

                      if (_formSubmitError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formSubmitError!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isSubmitting)
                    const SizedBox(
                      width: 120,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    AppPrimaryButton(
                      label: isEdit ? 'Save $typeName' : 'Publish $typeName',
                      icon: Icons.publish,
                      height: 40,
                      onPressed: _submitForm,
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
