import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/data/repositories/supabase_teacher_classwork_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';

class CreateRequirementFlowDialog extends StatefulWidget {
  final VoidCallback onRequirementCreated;
  final String initialSection;
  final String? initialSubject;
  final String? initialOfferingId;
  final ActivityModel? existingTask;
  final bool isPerformanceTask;
  final TeacherClassworkRepository? repository;
  final List<Map<String, dynamic>>? initialOfferings;

  const CreateRequirementFlowDialog({
    super.key,
    required this.onRequirementCreated,
    this.initialSection = '',
    this.initialSubject,
    this.initialOfferingId,
    this.existingTask,
    this.isPerformanceTask = true,
    this.repository,
    this.initialOfferings,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRequirementCreated,
    String? initialSection,
    String? initialSubject,
    String? initialOfferingId,
    ActivityModel? existingTask,
    bool isPerformanceTask = true,
    TeacherClassworkRepository? repository,
    List<Map<String, dynamic>>? initialOfferings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateRequirementFlowDialog(
        onRequirementCreated: onRequirementCreated,
        initialSection: initialSection ?? '',
        initialSubject: initialSubject,
        initialOfferingId: initialOfferingId,
        existingTask: existingTask,
        isPerformanceTask: isPerformanceTask,
        repository: repository,
        initialOfferings: initialOfferings,
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
  DateTime? _deadline;
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

  // Gradebook columns already used by another active classwork for the
  // selected subject offering + category + term. These are disabled in the
  // column dropdown so the teacher cannot pick an occupied slot by mistake.
  Set<int> _occupiedColumns = <int>{};
  bool _isLoadingOccupied = false;
  int _occupiedRequestId = 0;

  bool get _isInPerson => _completionMode == 'in_person';

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
    } else {
      _deadline = null;
    }

    if (widget.initialOfferings != null) {
      _offerings = List<Map<String, dynamic>>.from(widget.initialOfferings!);
      _isLoadingOfferings = false;
      _initializeSelectedOffering();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadOccupiedColumns(),
      );
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
      final matchesGrade =
          _selectedGrade == null || gradeLabel == _selectedGrade;
      final matchesSub =
          _selectedSubject == null ||
          o['subject_name']?.toString().trim() == _selectedSubject;
      return matchesGrade && matchesSub;
    }).toList();
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
        if (upper.contains('3') || upper.contains('2ND & 3RD'))
          return const [2, 3];
        return const [1, 2];
      }
    }
    return const [1, 2, 3];
  }

  void _initializeSelectedOffering() {
    if (_offerings.isEmpty) return;

    Map<String, dynamic> match = _offerings.first;
    if (_selectedOfferingId != null) {
      match = _offerings.firstWhere(
        (o) => o['id']?.toString() == _selectedOfferingId,
        orElse: () => _offerings.first,
      );
    } else if (widget.initialOfferingId != null &&
        widget.initialOfferingId!.isNotEmpty) {
      match = _offerings.firstWhere(
        (o) => o['id']?.toString() == widget.initialOfferingId,
        orElse: () => _offerings.first,
      );
    } else if (widget.initialSection.isNotEmpty ||
        (widget.initialSubject != null && widget.initialSubject!.isNotEmpty)) {
      try {
        match = _offerings.firstWhere(
          (o) {
            final secMatch =
                widget.initialSection.isEmpty ||
                o['section_name']?.toString().trim() ==
                    widget.initialSection.trim();
            final subMatch =
                widget.initialSubject == null ||
                widget.initialSubject!.isEmpty ||
                o['subject_name']?.toString().trim() ==
                    widget.initialSubject!.trim();
            return secMatch && subMatch;
          },
          orElse: () => _offerings.firstWhere(
            (o) =>
                widget.initialSection.isNotEmpty &&
                o['section_name']?.toString().trim() ==
                    widget.initialSection.trim(),
            orElse: () => _offerings.first,
          ),
        );
      } catch (_) {}
    }

    final g = match['grade_level']?.toString().trim();
    _selectedGrade = g != null && g.startsWith('Grade') ? g : 'Grade $g';
    _selectedSubject = match['subject_name']?.toString().trim();
    _selectedOfferingId = match['id']?.toString();

    final availableTerms = _getAvailableTermsForOffering(match);
    if (!availableTerms.contains(_termNumber)) {
      _termNumber = availableTerms.isNotEmpty ? availableTerms.first : 1;
    }
  }

  Future<void> _loadTeacherOfferings() async {
    try {
      final teacherId = AuthRepository.instance.currentUser?.id;
      if (teacherId == null) {
        if (mounted) setState(() => _isLoadingOfferings = false);
        return;
      }
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
      if (!mounted) return;
      setState(() {
        _offerings = subjects;
        _isLoadingOfferings = false;
        _initializeSelectedOffering();
      });
      _loadOccupiedColumns();
    } catch (_) {
      if (mounted) setState(() => _isLoadingOfferings = false);
    }
  }

  /// Loads which gradebook columns are already taken for the selected
  /// subject offering (subject + section), category (WW / PT) and term.
  Future<void> _loadOccupiedColumns() async {
    final offeringId = _selectedOfferingId;
    if (offeringId == null || offeringId.trim().isEmpty) return;

    final requestId = ++_occupiedRequestId;
    final term = _termNumber;
    if (mounted) setState(() => _isLoadingOccupied = true);

    try {
      final repo =
          widget.repository ?? SupabaseTeacherClassworkRepository.instance;
      final items = await repo.getActivities(subjectOfferingId: offeringId);
      if (!mounted || requestId != _occupiedRequestId) return;

      final excludeId = widget.existingTask?.id;
      final occupied = <int>{};
      for (final item in items) {
        if (item.isArchived) continue;
        if (item.isRequirement != widget.isPerformanceTask) continue;
        if (item.termNumber != term) continue;
        final col = item.gradebookColumnIndex;
        if (col == null) continue;
        if (excludeId != null && excludeId.isNotEmpty && item.id == excludeId) {
          continue;
        }
        occupied.add(col);
      }

      setState(() {
        _occupiedColumns = occupied;
        _isLoadingOccupied = false;
        // Clear a previously chosen column if it turned out to be taken.
        if (_gradebookColumnIndex != null &&
            occupied.contains(_gradebookColumnIndex)) {
          _gradebookColumnIndex = null;
        }
      });
    } catch (_) {
      if (mounted && requestId == _occupiedRequestId) {
        setState(() => _isLoadingOccupied = false);
      }
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
        mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
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
    final today = DateTime(now.year, now.month, now.day);

    // In-Person: the teacher records the date the work was handed in,
    // so past dates are allowed and no time is needed.
    if (_isInPerson) {
      final initial = _deadline ?? today;
      final date = await showAppDatePickerDialog(
        context,
        initialDate: initial,
        firstDate: DateTime(today.year - 1, 1, 1),
        lastDate: DateTime(2100),
        title: 'Select Date Submitted',
      );
      if (!mounted || date == null) return;
      setState(() {
        _deadline = DateTime(date.year, date.month, date.day, 23, 59);
        _deadlineError = null;
      });
      return;
    }

    final initial = _deadline != null && _deadline!.isAfter(now)
        ? _deadline!
        : now.add(const Duration(days: 1));
    final date = await showAppDatePickerDialog(
      context,
      initialDate: initial,
      firstDate: today,
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
      if (_deadline!.isAfter(DateTime.now())) {
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
    if (_isInPerson) return '$day/$month/${date.year}';
    return '$day/$month/${date.year} ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  void _setCompletionMode(String mode) {
    if (_completionMode == mode) return;
    setState(() {
      _completionMode = mode;
      _deadlineError = null;
      // An online deadline in the past is not valid; make the teacher re-pick.
      if (mode == 'online' &&
          _deadline != null &&
          widget.existingTask == null &&
          _deadline!.isBefore(DateTime.now())) {
        _deadline = null;
      }
    });
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
    final offeringValid =
        _selectedOfferingId != null && _selectedOfferingId!.trim().isNotEmpty;
    final columnValid =
        _gradebookColumnIndex != null &&
        !_occupiedColumns.contains(_gradebookColumnIndex);

    if (!offeringValid) {
      setState(() => _offeringError = 'Select a subject offering.');
    } else {
      setState(() => _offeringError = null);
    }

    // The column error is shown inline by the dropdown's own validator,
    // so no second message is rendered under the Term field.
    setState(() => _columnError = columnValid ? null : 'column');

    if (_deadline == null) {
      setState(
        () => _deadlineError = _isInPerson
            ? 'Please select the date submitted.'
            : 'Please select a submission deadline.',
      );
    } else if (!_isInPerson &&
        widget.existingTask == null &&
        _deadline!.isBefore(DateTime.now())) {
      setState(() => _deadlineError = 'Due date must be in the future.');
    } else {
      setState(() => _deadlineError = null);
    }

    if (!formValid ||
        !offeringValid ||
        !columnValid ||
        _fileError != null ||
        _deadlineError != null ||
        _deadline == null) {
      return;
    }

    final selectedOffering = _offerings.firstWhere(
      (o) => o['id']?.toString() == _selectedOfferingId,
      orElse: () => <String, dynamic>{},
    );

    final maxScore = int.parse(_maxScoreCtrl.text.trim()).toDouble();
    final subjectName =
        selectedOffering['subject_name']?.toString() ?? 'General Subject';
    final sectionName =
        selectedOffering['section_name']?.toString() ?? 'General Section';
    final gradeLevel =
        selectedOffering['grade_level']?.toString() ?? 'Grade 11';

    final categoryKey = widget.isPerformanceTask ? 'pt' : 'ww';
    final categoryLabel = widget.isPerformanceTask ? 'PT' : 'WW';

    setState(() => _isSubmitting = true);

    try {
      final repo =
          widget.repository ?? SupabaseTeacherClassworkRepository.instance;

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
        deadline: _deadline!,
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
        final termSheet =
            await SubjectRepository.instance.getGradebookTermSheet(
              _selectedOfferingId!,
              _termNumber,
            ) ??
            {};
        final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
        final catMap = Map<String, dynamic>.from(
          hps[categoryKey] as Map? ?? {},
        );

        catMap[_gradebookColumnIndex.toString()] = maxScore;
        hps[categoryKey] = catMap;
        termSheet['hps'] = hps;
        await SubjectRepository.instance.saveGradebookTermSheet(
          _selectedOfferingId!,
          _termNumber,
          termSheet,
        );
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                          color: const Color(
                            0xFFF1F5F9,
                          ), // 60-30-10: 30% background for field
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _setCompletionMode('online'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _completionMode == 'online'
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _completionMode == 'online'
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
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
                                        Icons.computer,
                                        size: 16,
                                        color: _completionMode == 'online'
                                            ? const Color(0xFF0F8A48)
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Online (Submit via App)',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                _completionMode == 'online'
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _completionMode == 'online'
                                                ? const Color(0xFF0F8A48)
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _setCompletionMode('in_person'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _completionMode == 'in_person'
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _completionMode == 'in_person'
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
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
                                            ? const Color(0xFF0F8A48)
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'In-Person (Manual Record)',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                _completionMode == 'in_person'
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color:
                                                _completionMode == 'in_person'
                                                ? const Color(0xFF0F8A48)
                                                : Colors.grey.shade600,
                                          ),
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
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9), // Light Emerald
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF0F8A48)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$_selectedGrade • $_selectedSubject • ${_offerings.firstWhere((o) => o['id'].toString() == _selectedOfferingId, orElse: () => {'section_name': ''})['section_name']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F8A48),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // C. Title
                      AppTextField(
                        label: widget.isPerformanceTask
                            ? 'Performance Task Title *'
                            : 'Activity / Assignment Title *',
                        hint: widget.isPerformanceTask
                            ? 'e.g. Stage Play Performance'
                            : 'e.g. Chapter 1 Reading Reflection',
                        controller: _titleCtrl,
                        maxLength: 50,
                        showCounter: true,
                        inputFormatters: [LengthLimitingTextInputFormatter(50)],
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return 'Title is required.';
                          if (text.length > 50)
                            return 'Title must not exceed 50 characters.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // D. Grid Row 1 (Term & Column)
                      Builder(
                        builder: (context) {
                          final selectedOffering = _offerings.firstWhere(
                            (o) => o['id']?.toString() == _selectedOfferingId,
                            orElse: () => <String, dynamic>{},
                          );
                          final availableTerms = _getAvailableTermsForOffering(
                            selectedOffering,
                          );
                          final currentTerm =
                              availableTerms.contains(_termNumber)
                              ? _termNumber
                              : (availableTerms.isNotEmpty
                                    ? availableTerms.first
                                    : 1);

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gradebook Term *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (availableTerms.length <= 1)
                                      Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        alignment: Alignment.centerLeft,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        child: Text(
                                          _termLabel(
                                            availableTerms.isNotEmpty
                                                ? availableTerms.first
                                                : 1,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      )
                                    else
                                      DropdownButtonFormField<int>(
                                        initialValue: currentTerm,
                                        decoration: InputDecoration(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        items: availableTerms.map((term) {
                                          return DropdownMenuItem<int>(
                                            value: term,
                                            child: Text(
                                              _termLabel(term),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null &&
                                              val != _termNumber) {
                                            setState(() => _termNumber = val);
                                            _loadOccupiedColumns();
                                          }
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<int?>(
                                      key: ValueKey(
                                        'column-$_termNumber-${_occupiedColumns.join(',')}',
                                      ),
                                      initialValue:
                                          _occupiedColumns.contains(
                                            _gradebookColumnIndex,
                                          )
                                          ? null
                                          : _gradebookColumnIndex,
                                      isExpanded: true,
                                      hint: Text(
                                        _isLoadingOccupied
                                            ? 'Checking used slots...'
                                            : 'Select ${widget.isPerformanceTask ? 'PT' : 'WW'} Slot',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      items: List.generate(10, (i) {
                                        final col = i + 1;
                                        final prefix = widget.isPerformanceTask
                                            ? 'PT'
                                            : 'WW';
                                        final isUsed = _occupiedColumns
                                            .contains(col);
                                        return DropdownMenuItem<int?>(
                                          value: col,
                                          enabled: !isUsed,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '$prefix $col',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isUsed
                                                        ? Colors.grey.shade400
                                                        : null,
                                                    decoration: isUsed
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              if (isUsed)
                                                Text(
                                                  'Used',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                      onChanged: (val) {
                                        if (val != null &&
                                            !_occupiedColumns.contains(val)) {
                                          setState(() {
                                            _gradebookColumnIndex = val;
                                            _columnError = null;
                                          });
                                        }
                                      },
                                      validator: (val) {
                                        if (val == null)
                                          return 'Please select a gradebook column.';
                                        if (_occupiedColumns.contains(val)) {
                                          return 'This column is already used.';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_occupiedColumns.length >= 10)
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          top: 6,
                                          left: 4,
                                        ),
                                        child: Text(
                                          'All columns for this term are already used.',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
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
                                  _isInPerson
                                      ? 'Date Submitted *'
                                      : 'Submission Deadline *',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _selectDeadline,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _deadlineError != null
                                            ? const Color(0xFFEF4444)
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: Color(0xFF0F8A48),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _deadline != null
                                                ? _formatDeadline(_deadline!)
                                                : (_isInPerson
                                                      ? 'Select date submitted'
                                                      : 'Select deadline'),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: _deadline != null
                                                  ? FontWeight.w500
                                                  : FontWeight.normal,
                                              color: _deadline != null
                                                  ? theme.colorScheme.onSurface
                                                  : theme.colorScheme.onSurface
                                                        .withValues(
                                                          alpha: 0.38,
                                                        ),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_deadlineError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      left: 4,
                                    ),
                                    child: Text(
                                      _deadlineError!,
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppTextField(
                              label: 'Total Points (HPS) *',
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // F. Detailed Instructions
                      AppTextField(
                        label: 'Detailed Instructions & Rubrics *',
                        hint:
                            'Provide step-by-step instructions for students...',
                        controller: _instructionsCtrl,
                        maxLines: 4,
                        maxLength: 1000,
                        showCounter: true,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1000),
                        ],
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty)
                            return 'Detailed instructions are required.';
                          if (text.length > 1000)
                            return 'Must not exceed 1,000 characters.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // G. Optional Attachment (Online Mode Only)
                      if (_completionMode == 'online') ...[
                        const Text(
                          'Classwork Attachment (Optional - PDF, DOC, DOCX up to 5 MiB)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _fileError != null
                                  ? const Color(0xFFEF4444)
                                  : Colors.grey.shade400,
                            ),
                          ),
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isSubmitting ? null : _pickFile,
                                icon: const Icon(Icons.attach_file, size: 16),
                                label: Text(
                                  _attachmentName == null
                                      ? 'Attach File'
                                      : 'Replace File',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
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
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Color(0xFFEF4444),
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: _isSubmitting
                                                ? null
                                                : _removeAttachment,
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'No file attached',
                                        style: TextStyle(
                                          color: Colors.grey,
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
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
