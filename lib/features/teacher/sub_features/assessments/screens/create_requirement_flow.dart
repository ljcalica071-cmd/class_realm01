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
    String? initialSection,
    ActivityModel? existingTask,
    bool isPerformanceTask = true,
    TeacherClassworkRepository? repository,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateRequirementFlowDialog(
        onRequirementCreated: onRequirementCreated,
        initialSection: initialSection ?? '',
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
  String? _selectedGrade;
  String? _selectedSubject;
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
  String? _deadlineError;
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

  int _parseGrade(dynamic g) {
    if (g is int) return g;
    return int.tryParse(g?.toString() ?? '') ?? 11;
  }

  List<String> get _availableGrades {
    if (_offerings.isEmpty) return [];
    final set = <String>{};
    for (final o in _offerings) {
      final g = o['grade_level']?.toString().trim();
      if (g != null && g.isNotEmpty) {
        set.add(g.startsWith('Grade') ? g : 'Grade $g');
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableSubjects {
    if (_offerings.isEmpty) return [];
    final set = <String>{};
    for (final o in _offerings) {
      final g = o['grade_level']?.toString().trim();
      final gradeLabel = g != null && g.startsWith('Grade') ? g : 'Grade $g';
      if (_selectedGrade == null || gradeLabel == _selectedGrade) {
        final sub = o['subject_name']?.toString().trim();
        if (sub != null && sub.isNotEmpty) {
          set.add(sub);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _availableSections {
    if (_offerings.isEmpty) return [];
    return _offerings.where((o) {
      final g = o['grade_level']?.toString().trim();
      final gradeLabel = g != null && g.startsWith('Grade') ? g : 'Grade $g';
      final matchesGrade = _selectedGrade == null || gradeLabel == _selectedGrade;
      final matchesSub = _selectedSubject == null || o['subject_name']?.toString().trim() == _selectedSubject;
      return matchesGrade && matchesSub;
    }).toList();
  }

  void _initializeSelectedOffering() {
    if (_offerings.isEmpty) return;

    if (_selectedOfferingId != null) {
      final match = _offerings.firstWhere(
        (o) => o['id']?.toString() == _selectedOfferingId,
        orElse: () => _offerings.first,
      );
      final g = match['grade_level']?.toString().trim();
      _selectedGrade = g != null && g.startsWith('Grade') ? g : 'Grade $g';
      _selectedSubject = match['subject_name']?.toString().trim();
      _selectedOfferingId = match['id']?.toString();
    } else {
      Map<String, dynamic> match = _offerings.first;
      if (widget.initialSection.isNotEmpty) {
        match = _offerings.firstWhere(
          (o) => o['section_name']?.toString() == widget.initialSection,
          orElse: () => _offerings.first,
        );
      }
      final g = match['grade_level']?.toString().trim();
      _selectedGrade = g != null && g.startsWith('Grade') ? g : 'Grade $g';
      _selectedSubject = match['subject_name']?.toString().trim();
      _selectedOfferingId = match['id']?.toString();
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

      if (file.size > 10 * 1024 * 1024) {
        setState(() {
          _fileError =
              'File size exceeds the 10 MiB limit (${(file.size / (1024 * 1024)).toStringAsFixed(2)} MiB > 10 MiB).';
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
    final now = DateTime.now();
    final initial = _deadline.isBefore(now) ? now.add(const Duration(days: 1)) : _deadline;
    final date = await showAppDatePickerDialog(
      context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
      title: 'Select Due Date',
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
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
      if (_deadline.isAfter(DateTime.now())) {
        _deadlineError = null;
      }
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

    if (widget.existingTask == null && _deadline.isBefore(DateTime.now())) {
      setState(() => _deadlineError = 'Due date must be in the future.');
    } else {
      setState(() => _deadlineError = null);
    }

    if (!formValid || !offeringValid || _fileError != null || _deadlineError != null) {
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

    final categoryKey = widget.isPerformanceTask ? 'pt' : 'ww';
    final categoryLabel = widget.isPerformanceTask ? 'PT' : 'WW';

    setState(() => _isSubmitting = true);

    try {
      // 1. Gradebook 10-column ceiling check
      if (widget.existingTask == null) {
        final termSheet = await SubjectRepository.instance.getGradebookTermSheet(_selectedOfferingId!, 1);
        final hpsMap = (termSheet?['hps'] as Map<String, dynamic>?)?[categoryKey] as Map<String, dynamic>? ?? {};
        
        if (hpsMap.length >= 10) {
          throw Exception(
            'Maximum limit reached: You have already assigned all 10 $categoryLabel columns for this Term.',
          );
        }
      }

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

      final repo = widget.repository ?? SupabaseTeacherClassworkRepository.instance;
      final savedActivity = await repo.saveActivity(
        activity: task,
        subjectOfferingId: _selectedOfferingId!,
        fileBytes: _pickedFileBytes,
        fileName: _pickedFileName,
        mimeType: _pickedFileMimeType,
        removeExistingAttachment: _removeExistingAttachment,
      );

      // 2. Synchronize HPS into Gradebook column for this offering
      try {
        final termSheet = await SubjectRepository.instance.getGradebookTermSheet(_selectedOfferingId!, 1) ?? {};
        final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
        final catMap = Map<String, dynamic>.from(hps[categoryKey] as Map? ?? {});

        // Find existing column key or assign next available 1..10
        String? targetKey;
        for (int i = 1; i <= 10; i++) {
          final k = i.toString();
          if (!catMap.containsKey(k)) {
            targetKey = k;
            break;
          }
        }

        if (targetKey != null) {
          catMap[targetKey] = maxScore;
          hps[categoryKey] = catMap;
          termSheet['hps'] = hps;
          await SubjectRepository.instance.saveGradebookTermSheet(_selectedOfferingId!, 1, termSheet);
        }
      } catch (gbErr) {
        debugPrint('Gradebook HPS sync notice: $gbErr');
      }

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

                      // 2. ENROLLMENT TARGET Card (Grade Level, Subject, Section)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _offeringError != null
                                ? const Color(0xFFEF4444)
                                : theme.colorScheme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ENROLLMENT TARGET',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
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
                              const Text(
                                'No active subject offerings available. Please set up your classes first.',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              Row(
                                children: [
                                  // Grade Level Dropdown
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Grade Level',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _availableGrades.contains(_selectedGrade)
                                              ? _selectedGrade
                                              : (_availableGrades.isNotEmpty ? _availableGrades.first : null),
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: _availableGrades.map((g) {
                                            return DropdownMenuItem(
                                              value: g,
                                              child: Text(g, style: const TextStyle(fontSize: 12)),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _selectedGrade = val;
                                                final subs = _availableSubjects;
                                                _selectedSubject = subs.isNotEmpty ? subs.first : null;
                                                final secs = _availableSections;
                                                _selectedOfferingId = secs.isNotEmpty
                                                    ? secs.first['id']?.toString()
                                                    : null;
                                                _offeringError = null;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Subject Dropdown
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Subject',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _availableSubjects.contains(_selectedSubject)
                                              ? _selectedSubject
                                              : (_availableSubjects.isNotEmpty ? _availableSubjects.first : null),
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: _availableSubjects.map((sub) {
                                            return DropdownMenuItem(
                                              value: sub,
                                              child: Text(
                                                sub,
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _selectedSubject = val;
                                                final secs = _availableSections;
                                                _selectedOfferingId = secs.isNotEmpty
                                                    ? secs.first['id']?.toString()
                                                    : null;
                                                _offeringError = null;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Section Dropdown
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Section',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _availableSections.any((s) => s['id']?.toString() == _selectedOfferingId)
                                              ? _selectedOfferingId
                                              : (_availableSections.isNotEmpty ? _availableSections.first['id']?.toString() : null),
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: _availableSections.map((sec) {
                                            final id = sec['id']?.toString() ?? '';
                                            final secName = sec['section_name']?.toString() ?? 'Section';
                                            return DropdownMenuItem(
                                              value: id,
                                              child: Text(
                                                secName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _selectedOfferingId = val;
                                                _offeringError = null;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            if (_offeringError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Text(
                                  _offeringError!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Due Date & Time Picker
                      Text(
                        'Submission Deadline / Due Date *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _selectDeadline,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _deadlineError != null
                                  ? const Color(0xFFEF4444)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDeadline(_deadline),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Change Deadline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_deadlineError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            _deadlineError!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                            ),
                          ),
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
