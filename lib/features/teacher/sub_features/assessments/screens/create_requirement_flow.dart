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

  // New Fields for Database Modifications
  String _completionMode = 'online'; // 'online' or 'in_person'
  int _termNumber = 1;
  int? _gradebookColumnIndex;

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
  String? _columnError;

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
      _termNumber = task.termNumber;
      _gradebookColumnIndex = task.gradebookColumnIndex;
      _completionMode = task.completionMode;
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
        try {
          match = _offerings.firstWhere(
            (o) => o['section_name']?.toString().trim() == widget.initialSection,
          );
        } catch (_) {}
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
    final columnValid = _gradebookColumnIndex != null;

    if (!offeringValid) {
      setState(() => _offeringError = 'Select a subject offering.');
    } else {
      setState(() => _offeringError = null);
    }

    if (!columnValid) {
      setState(() => _columnError = 'Select a gradebook column.');
    } else {
      setState(() => _columnError = null);
    }

    if (_completionMode == 'online' && widget.existingTask == null && _deadline.isBefore(DateTime.now())) {
      setState(() => _deadlineError = 'Due date must be in the future.');
    } else {
      setState(() => _deadlineError = null);
    }

    if (!formValid || !offeringValid || !columnValid || _fileError != null || _deadlineError != null) {
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
      final repo = widget.repository ?? SupabaseTeacherClassworkRepository.instance;
      
      // Gradebook Slot Conflict Check
      final isOccupied = await repo.isGradebookSlotOccupied(
        subjectOfferingId: _selectedOfferingId!,
        gradingCategory: categoryKey,
        termNumber: _termNumber,
        gradebookColumnIndex: _gradebookColumnIndex!,
        excludeClassworkId: widget.existingTask?.id,
      );
      
      if (isOccupied) {
        throw Exception(
          'Slot Occupied: Gradebook column $categoryLabel $_gradebookColumnIndex is already in use for Term $_termNumber. Please select an empty slot.',
        );
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
        completionMode: _completionMode,
        termNumber: _termNumber,
        gradebookColumnIndex: _gradebookColumnIndex,
      );

      final savedActivity = await repo.saveActivity(
        activity: task,
        subjectOfferingId: _selectedOfferingId!,
        fileBytes: _pickedFileBytes,
        fileName: _pickedFileName,
        mimeType: _pickedFileMimeType,
        removeExistingAttachment: _removeExistingAttachment,
      );

      // We skip the legacy gradebook HPS sync for this phase, since 
      // the new gradebook will fetch HPS directly from classwork_items!
      // But just to keep old UI from crashing if it reads HPS:
      try {
        final termSheet = await SubjectRepository.instance.getGradebookTermSheet(_selectedOfferingId!, _termNumber) ?? {};
        final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
        final catMap = Map<String, dynamic>.from(hps[categoryKey] as Map? ?? {});

        catMap[_gradebookColumnIndex.toString()] = maxScore;
        hps[categoryKey] = catMap;
        termSheet['hps'] = hps;
        await SubjectRepository.instance.saveGradebookTermSheet(_selectedOfferingId!, _termNumber, termSheet);
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
                      // A. Mode Slider (Top Navigation)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // 60-30-10: 30% background for field
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(4),
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
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] 
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.computer, size: 16, color: _completionMode == 'online' ? const Color(0xFF0F8A48) : Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Online (Submit via App)',
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
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] 
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.group, size: 16, color: _completionMode == 'in_person' ? const Color(0xFF0F8A48) : Colors.grey),
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
                      const SizedBox(height: 20),

                      // B. Context Badge
                      if (_selectedOfferingId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9), // Light Emerald
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF0F8A48).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.school, size: 16, color: Color(0xFF0F8A48)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '🎯 $_selectedGrade • $_selectedSubject • ${_offerings.firstWhere((o) => o['id'].toString() == _selectedOfferingId, orElse: () => {'section_name': ''})['section_name']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F8A48),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // C. Title
                      AppTextField(
                        label: widget.isPerformanceTask ? 'Performance Task Title *' : 'Activity / Assignment Title *',
                        hint: widget.isPerformanceTask ? 'e.g. Stage Play Performance' : 'e.g. Chapter 1 Reading Reflection',
                        controller: _titleCtrl,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return 'Title is required.';
                          if (text.length > 100) return 'Title must not exceed 100 characters.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // D. Grid Row 1 (Term & Column)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gradebook Term *',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  initialValue: _termNumber,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 1, child: Text('1st Term', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 2, child: Text('2nd Term', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 3, child: Text('3rd Term', style: TextStyle(fontSize: 13))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _termNumber = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gradebook Column *',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int?>(
                                  initialValue: _gradebookColumnIndex,
                                  hint: Text('Select ${widget.isPerformanceTask ? 'PT' : 'WW'} Slot', style: const TextStyle(fontSize: 13)),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: _columnError != null ? const BorderSide(color: Color(0xFFEF4444)) : const BorderSide(),
                                    ),
                                  ),
                                  items: List.generate(10, (i) {
                                    final col = i + 1;
                                    return DropdownMenuItem(
                                      value: col,
                                      child: Text('${widget.isPerformanceTask ? 'PT' : 'WW'} $col', style: const TextStyle(fontSize: 13)),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                      _gradebookColumnIndex = val;
                                      _columnError = null;
                                    });
                                    }
                                  },
                                  validator: (val) => val == null ? 'Column slot required.' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_columnError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            _columnError!,
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // E. Grid Row 2 (Deadline & HPS)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _completionMode == 'online' ? 'Submission Deadline *' : 'Target Date (Optional)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _selectDeadline,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _deadlineError != null ? const Color(0xFFEF4444) : Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0F8A48)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _formatDeadline(_deadline),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
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
                                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Points (HPS) *',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                AppTextField(
                                  label: 'HPS',
                                  hint: '1 to 100',
                                  controller: _maxScoreCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.isEmpty) return 'Required.';
                                    final score = int.tryParse(text);
                                    if (score == null || score < 1 || score > 100) {
                                      return 'Must be 1 to 100.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // F. Detailed Instructions
                      AppTextField(
                        label: 'Detailed Instructions & Rubrics *',
                        hint: 'Provide step-by-step instructions for students...',
                        controller: _instructionsCtrl,
                        maxLines: 4,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return 'Detailed instructions are required.';
                          if (text.length > 1000) return 'Must not exceed 1,000 characters.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // G. Optional Attachment (Online Mode Only)
                      if (_completionMode == 'online') ...[
                        const Text(
                          'Classwork Attachment (Optional - PDF, DOC, DOCX up to 5 MiB)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _fileError != null ? const Color(0xFFEF4444) : Colors.grey.shade400,
                            ),
                          ),
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isSubmitting ? null : _pickFile,
                                icon: const Icon(Icons.attach_file, size: 16),
                                label: Text(_attachmentName == null ? 'Attach File' : 'Replace File', style: const TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _attachmentName != null
                                    ? Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _pickedFileSizeBytes != null ? '$_attachmentName (${_formatFileSize(_pickedFileSizeBytes!)})' : _attachmentName!,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: _isSubmitting ? null : _removeAttachment,
                                          ),
                                        ],
                                      )
                                    : const Text('No file attached', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                        if (_fileError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              _fileError!,
                              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                            ),
                          ),
                      ],

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
                              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_formSubmitError!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
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
