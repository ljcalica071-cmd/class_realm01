import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/core/utils/excel_template_generator.dart';

/// Unified dialog that enables teachers to enroll students either one-by-one or via Excel/CSV import.
/// Allows selecting Grade Level -> Subject -> Section, and supports pre-selection when triggered
/// directly from Classroom Setup or Manage Students.
class UnifiedEnrollStudentDialog extends StatefulWidget {
  final VoidCallback onStudentCreated;
  final List<Map<String, dynamic>> teacherSubjects;
  final String? initialSubjectId;
  final String? initialSectionName;
  final int initialTabIndex; // 0 for Manual Add, 1 for Import File

  const UnifiedEnrollStudentDialog({
    super.key,
    required this.onStudentCreated,
    required this.teacherSubjects,
    this.initialSubjectId,
    this.initialSectionName,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onStudentCreated,
    required List<Map<String, dynamic>> teacherSubjects,
    String? initialSubjectId,
    String? initialSectionName,
    int initialTabIndex = 0,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UnifiedEnrollStudentDialog(
        onStudentCreated: onStudentCreated,
        teacherSubjects: teacherSubjects,
        initialSubjectId: initialSubjectId,
        initialSectionName: initialSectionName,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<UnifiedEnrollStudentDialog> createState() =>
      _UnifiedEnrollStudentDialogState();
}

class _UnifiedEnrollStudentDialogState extends State<UnifiedEnrollStudentDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();

  String? _gender;
  DateTime? _birthday;

  // Cascading Selection: Grade Level -> Subject -> Section
  String? _selectedGradeLevel;
  String? _selectedSubjectName;
  String? _selectedOfferingId; // This is the subject_offerings.id

  bool _isSubmitting = false;

  // Resumable Batch Import Session State
  Map<String, dynamic>? _resumableBatch;

  // Batch In-Box Progress & Preview State
  String? _batchFileName;
  int? _batchFileSize;
  bool _isProcessingBatch = false;
  double _batchProgress = 0.0;
  String _batchPhase = '';
  String _batchActiveRecord = '';
  String? _batchWarningTitle;
  String? _batchWarningMessage;
  List<_ParsedStudentRow> _eligibleNewStudents = [];
  List<_ParsedStudentRow> _eligibleExistingStudents = [];
  List<_ParsedStudentRow> _alreadyEnrolledStudents = [];
  List<_InvalidStudentRow> _detectedInvalidRows = [];

  Timer? _autoResumeTimer;

  void _startAutoResumeListener() {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _resumableBatch == null || _isSubmitting || _isProcessingBatch) return;
      try {
        await Supabase.instance.client.from('users').select('id').limit(1);
        if (mounted && _resumableBatch != null && !_isSubmitting && !_isProcessingBatch) {
          _autoResumeTimer?.cancel();
          _autoResumeTimer = null;
          await _resumeBatchEnrollment();
        }
      } catch (_) {}
    });
  }

  Future<void> _checkResumableBatch() async {
    if (_selectedOfferingId == null) {
      if (_resumableBatch != null && mounted) {
        setState(() => _resumableBatch = null);
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('batch_enroll_session_$_selectedOfferingId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final pending = decoded['pending'] as List<dynamic>?;
        if (pending != null && pending.isNotEmpty && mounted) {
          setState(() => _resumableBatch = decoded);
          _startAutoResumeListener();
          return;
        }
      }
    } catch (_) {}
    if (_resumableBatch != null && mounted) {
      setState(() => _resumableBatch = null);
    }
  }

  Future<void> _discardResumableBatch() async {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = null;
    if (_selectedOfferingId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('batch_enroll_session_$_selectedOfferingId');
    } catch (_) {}
    if (mounted) setState(() => _resumableBatch = null);
  }

  Future<void> _resumeBatchEnrollment() async {
    if (_resumableBatch == null) return;
    _autoResumeTimer?.cancel();
    _autoResumeTimer = null;
    final pendingList = _resumableBatch!['pending'] as List<dynamic>;
    final fileName = _resumableBatch!['fileName']?.toString() ?? 'Spreadsheet';
    final students = pendingList.map((m) {
      final map = m as Map<String, dynamic>;
      return _ParsedStudentRow(
        rowNumber: map['rowNumber'] as int? ?? 1,
        lrn: map['lrn'] as String,
        firstName: map['firstName'] as String,
        middleName: map['middleName'] as String? ?? '',
        lastName: map['lastName'] as String,
        gender: map['gender'] as String,
        birthday: DateTime.parse(map['birthday'] as String),
        email: map['email'] as String,
        isExistingGlobalStudent: map['isExistingGlobalStudent'] as bool? ?? false,
        existingStudentId: map['existingStudentId'] as String?,
      );
    }).toList();

    await _executeBatchEnrollment(students, isResumed: true, fileName: fileName);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );

    _initCascadingSelections();
    _checkResumableBatch();

    if (kIsWeb) {
      registerWebDrop(
        onFileDropped: (bytes, fileName, size) {
          if (!mounted) return;
          final Uint8List u8 = bytes is Uint8List
              ? bytes
              : Uint8List.fromList(bytes as List<int>);
          if (_tabController.index != 1) {
            _tabController.animateTo(1);
          }
          _handleBatchFileBytes(u8, fileName, size);
        },
      );
    }
  }

  void _initCascadingSelections() {
    if (widget.teacherSubjects.isEmpty) return;

    // Check if initialSubjectId is provided
    if (widget.initialSubjectId != null) {
      final match = widget.teacherSubjects.firstWhere(
        (s) => s['id']?.toString() == widget.initialSubjectId,
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty) {
        final gl = match['grade_level'] != null
            ? 'Grade ${match['grade_level']}'
            : null;
        _selectedGradeLevel = gl;
        _selectedSubjectName = match['subject_name']?.toString();
        _selectedOfferingId = match['id']?.toString();
        return;
      }
    }

    // Default to the first grade and subject available
    final grades = _availableGradeLevels;
    if (grades.isNotEmpty) {
      _selectedGradeLevel = grades.first;
      final subjects = _getSubjectsForGrade(_selectedGradeLevel!);
      if (subjects.isNotEmpty) {
        _selectedSubjectName = subjects.first;
        final sections = _getSectionsForSubject(
          _selectedGradeLevel!,
          _selectedSubjectName!,
        );
        if (sections.isNotEmpty) {
          _selectedOfferingId = sections.first['id']?.toString();
        }
      }
    }
  }

  List<String> get _availableGradeLevels {
    final set = <String>{};
    for (final row in widget.teacherSubjects) {
      if (row['grade_level'] != null) {
        set.add('Grade ${row['grade_level']}');
      }
    }
    return set.toList()..sort();
  }

  List<String> _getSubjectsForGrade(String gradeLevel) {
    final gradeNum = gradeLevel.replaceAll(RegExp(r'[^0-9]'), '');
    final set = <String>{};
    for (final row in widget.teacherSubjects) {
      if (row['grade_level']?.toString() == gradeNum &&
          row['subject_name'] != null) {
        set.add(row['subject_name'].toString());
      }
    }
    return set.toList()..sort();
  }

  List<Map<String, dynamic>> _getSectionsForSubject(
    String gradeLevel,
    String subjectName,
  ) {
    final gradeNum = gradeLevel.replaceAll(RegExp(r'[^0-9]'), '');
    return widget.teacherSubjects.where((row) {
      final matchesGrade = row['grade_level']?.toString() == gradeNum;
      final matchesSub = row['subject_name']?.toString() == subjectName;
      return matchesGrade && matchesSub;
    }).toList();
  }

  @override
  void dispose() {
    _autoResumeTimer?.cancel();
    if (kIsWeb) {
      unregisterWebDrop();
    }
    _tabController.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  bool _hasCheckedTypo = false;

  Future<void> _submitSingleStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthday == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Birthday Required',
        message: 'Please select the student\'s birthday.',
      );
      return;
    }
    if (_gender == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Gender Required',
        message: 'Please select the student\'s gender.',
      );
      return;
    }
    if (_selectedOfferingId == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Section Required',
        message: 'Please select a specific section to enroll the student into.',
      );
      return;
    }

    final rawEmail = _emailCtrl.text.trim().toLowerCase();

    // 1. Email deliverability & DNS check (verifies valid domain / MX records)
    setState(() => _isSubmitting = true);
    final deliverability = await AppValidators.checkDomainDeliverability(rawEmail);
    if (!deliverability.isDeliverable) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Invalid Email Address',
          message: deliverability.error ?? 'The email domain is invalid or cannot receive emails.',
        );
      }
      return;
    }

    // 2. Email typo suggestion
    if (!_hasCheckedTypo) {
      final typoMatch = RegExp(r'@(gamil\.com|yaho\.com|gmail\.con|gmal\.com|yahoo\.con)$').firstMatch(rawEmail);
      if (typoMatch != null) {
        final typo = typoMatch.group(1);
        final isGmail = typo?.startsWith('g') == true;
        final suggestion = isGmail ? 'gmail.com' : 'yahoo.com';
        final suggestedEmail = rawEmail.replaceAll(typo!, suggestion);
        
        final useSuggestion = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Did you mean?'),
            content: Text('It looks like there might be a typo in the email address.\n\nDid you mean "$suggestedEmail"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep as is'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, change it'),
              ),
            ],
          ),
        );

        if (useSuggestion == true) {
          _emailCtrl.text = suggestedEmail;
        }
        _hasCheckedTypo = true;
      }
    }

    final emailToUse = _emailCtrl.text.trim().toLowerCase();

    try {
      final repo = SupabaseStudentRepository();
      final result = await repo.enrollStudent(
        lrn: _studentIdCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        birthday: _birthday!,
        email: emailToUse,
        gender: _gender!,
        subjectId: _selectedOfferingId!,
      );

      final fullName = [
        _firstNameCtrl.text.trim(),
        if (_middleNameCtrl.text.trim().isNotEmpty) _middleNameCtrl.text.trim(),
        _lastNameCtrl.text.trim(),
      ].join(' ');

      if (mounted) {
        Navigator.of(context).pop();
        widget.onStudentCreated();

        _showSuccessConfirmationDialog(
          context: context,
          fullName: fullName,
          email: emailToUse,
          tempPassword: result.tempPassword,
          createdAccount: result.createdAccount,
        );
      }
    } catch (e) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Enrollment Error',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  DateTime? _parseBirthday(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    if (RegExp(r'[a-zA-Z]').hasMatch(clean)) return null;

    // 1. Handle Excel serial date integers/floats (e.g. 40544 for 2011-01-01)
    final numVal = double.tryParse(clean);
    if (numVal != null && numVal >= 1000 && numVal <= 100000) {
      // Excel 1900 date system epoch base
      return DateTime(1899, 12, 30).add(Duration(days: numVal.floor()));
    }

    // 2. ISO-8601 (YYYY-MM-DD)
    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso;

    // 3. YYYY/MM/DD or YYYY-MM-DD
    final slashYmd = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$').firstMatch(clean);
    if (slashYmd != null) {
      final y = int.parse(slashYmd.group(1)!);
      final m = int.parse(slashYmd.group(2)!);
      final d = int.parse(slashYmd.group(3)!);
      return DateTime(y, m, d);
    }

    // 4. MM/DD/YYYY or DD/MM/YYYY
    final slashMdy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(clean);
    if (slashMdy != null) {
      final p1 = int.parse(slashMdy.group(1)!);
      final p2 = int.parse(slashMdy.group(2)!);
      final y = int.parse(slashMdy.group(3)!);
      if (p1 > 12) {
        return DateTime(y, p2, p1);
      }
      return DateTime(y, p1, p2);
    }

    return null;
  }

  String? _parseGender(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean == 'male' || clean == 'm') {
      return 'Male';
    }
    if (clean == 'female' || clean == 'f') {
      return 'Female';
    }
    return null;
  }

  String _toTitleCase(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '';
    return clean.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _downloadOfficialTemplate() async {
    try {
      final bytes = ExcelTemplateGenerator.generateStudentTemplateBytes();
      String? selectedPath;

      if (kIsWeb) {
        downloadFileBytes(
          bytes: bytes,
          fileName: 'classrealm_student_template.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        selectedPath = 'Downloaded via Browser (Downloads/classrealm_student_template.xlsx)';
      } else {
        try {
          selectedPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Student Enrollment Template',
            fileName: 'classrealm_student_template.xlsx',
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
            bytes: bytes,
          );
        } catch (_) {
          selectedPath = null;
        }

        if (selectedPath != null && selectedPath.isNotEmpty) {
          final file = File(selectedPath);
          await file.writeAsBytes(bytes);
        } else {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            final downloadsDir = Directory('$userProfile\\Downloads');
            if (downloadsDir.existsSync()) {
              final target = File('${downloadsDir.path}\\classrealm_student_template.xlsx');
              await target.writeAsBytes(bytes);
              selectedPath = target.path;
            }
          }
        }
      }

      if (!mounted) return;

      if (selectedPath != null && selectedPath.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(LucideIcons.fileSpreadsheet, color: theme.colorScheme.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Official Template Ready',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  kIsWeb ? 'Saved to Downloads folder' : 'Saved to computer successfully',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () => Navigator.pop(ctx),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Step-by-Step Instructions
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildTemplateStepItem(
                               stepNum: '1',
                               title: 'Download Template',
                               subtitle: 'classrealm_student_template.xlsx',
                               isDone: true,
                               theme: theme,
                             ),
                             const Divider(height: 14, thickness: 0.8),
                             _buildTemplateStepItem(
                               stepNum: '2',
                               title: 'Enter Students (Row 3 onwards)',
                               subtitle: 'Row 1 is headers; Row 2 sample is skipped',
                               isDone: false,
                               theme: theme,
                             ),
                             const Divider(height: 14, thickness: 0.8),
                             _buildTemplateStepItem(
                               stepNum: '3',
                               title: 'Upload File to ClassRealm',
                               subtitle: 'Instant validation with real-time feedback',
                               isDone: false,
                               theme: theme,
                             ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Column Requirements Quick Pill Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.shieldCheck, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                const Text(
                                  'Required Field Formats',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F8A48),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildFormatChip('LRN: 12 numeric digits'),
                                _buildFormatChip('Email: Valid address'),
                                _buildFormatChip('Name: Letters only'),
                                _buildFormatChip('M.I.: 1 char (optional)'),
                                _buildFormatChip('Gender: Male / Female'),
                                _buildFormatChip('Birthday: YYYY-MM-DD (Age 10-50)'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F8A48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Got It, Proceed to Upload', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Download Failed',
          message: 'Could not save the template: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildTemplateStepItem({
    required String stepNum,
    required String title,
    required String subtitle,
    required bool isDone,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF0F8A48)
                : theme.colorScheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: isDone
              ? const Icon(LucideIcons.check, size: 13, color: Colors.white)
              : Text(
                  stepNum,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF0F8A48).withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0F8A48)),
      ),
    );
  }

  Future<void> _processBatchImport() async {
    if (_selectedOfferingId == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Section Required',
        message: 'Please choose Grade Level, Subject, and Section target first before importing students.',
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.single;
      final Uint8List fileBytes;
      if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
        fileBytes = pickedFile.bytes!;
      } else if (!kIsWeb && pickedFile.path != null) {
        final file = File(pickedFile.path!);
        fileBytes = await file.readAsBytes();
      } else {
        throw Exception('Unable to read selected file contents.');
      }

      await _handleBatchFileBytes(fileBytes, pickedFile.name, pickedFile.size);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingBatch = false;
          _batchWarningMessage = e.toString().replaceAll('Exception: ', '');
        });
        AppModals.showErrorDialog(
          context: context,
          title: 'Import Error',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _handleBatchFileBytes(
    Uint8List fileBytes,
    String fileName,
    int fileSize,
  ) async {
    if (_selectedOfferingId == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Section Required',
        message: 'Please choose Grade Level, Subject, and Section target first before importing students.',
      );
      return;
    }

    String ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase().trim() : '';

    // File Format check
    if (ext != 'xlsx' && ext != 'xls' && ext != 'csv') {
      setState(() {
        _batchFileName = fileName;
        _batchFileSize = fileSize;
        _isProcessingBatch = false;
        _batchWarningTitle = 'Invalid File Format';
        _batchWarningMessage = 'Invalid file format. Please use the official downloaded template.';
      });
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid File Format',
        message: 'Invalid file format. Please use the official downloaded template.',
      );
      return;
    }

    if (ext == 'xls') {
      setState(() {
        _batchFileName = fileName;
        _batchFileSize = fileSize;
        _isProcessingBatch = false;
        _batchWarningTitle = 'Invalid File Format';
        _batchWarningMessage = 'Legacy Excel (.xls) is not supported. Please use the official .xlsx template.';
      });
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid File Format',
        message: 'Invalid file format. Please use the official downloaded template.',
      );
      return;
    }

    // File size validation: max 10 MB
    const maxBytes = 10 * 1024 * 1024;
    if (fileSize > maxBytes) {
      final mb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _batchFileName = fileName;
        _batchFileSize = fileSize;
        _isProcessingBatch = false;
        _batchWarningMessage = 'The selected file is $mb MB, which exceeds the 10 MB maximum limit.';
      });
      return;
    }

    setState(() {
      _batchFileName = fileName;
      _batchFileSize = fileSize;
      _isProcessingBatch = true;
      _batchProgress = 0.05;
      _batchPhase = 'Reading spreadsheet...';
      _batchActiveRecord = 'Extracting data from $fileName';
      _batchWarningTitle = null;
      _batchWarningMessage = null;
      _eligibleNewStudents = [];
      _eligibleExistingStudents = [];
      _alreadyEnrolledStudents = [];
      _detectedInvalidRows = [];
    });
    await Future.delayed(const Duration(milliseconds: 60));

    try {
      final List<List<dynamic>> rows;
      if (ext == 'csv') {
        final csvString = utf8.decode(fileBytes);
        rows = const CsvToListConverter().convert(csvString);
      } else {
        rows = _parseXlsxBytes(fileBytes);
      }

      // Check 2: Blank File / No Data (Empty file)
      if (rows.isEmpty || rows.length <= 1) {
        setState(() {
          _isProcessingBatch = false;
          _batchProgress = 0.0;
          _batchWarningTitle = 'Empty File';
          _batchWarningMessage = 'The uploaded file is empty. Please fill in the student data before uploading.';
        });
        AppModals.showErrorDialog(
          context: context,
          title: 'Empty File',
          message: 'The uploaded file is empty. Please fill in the student data before uploading.',
        );
        return;
      }

      final header = rows.first.map((e) => e.toString().replaceAll('\uFEFF', '').toLowerCase().trim()).toList();
      final lrnIndex = header.indexWhere((h) => h == 'lrn' || h.contains('lrn') || h.contains('student id'));
      final emailIndex = header.indexWhere((h) => h == 'email' || h.contains('email'));
      final lastNameIndex = header.indexWhere((h) => h == 'last name' || h == 'lastname' || h == 'last_name' || h == 'surname' || h.contains('last'));
      final firstNameIndex = header.indexWhere((h) => h == 'first name' || h == 'firstname' || h == 'first_name' || h.contains('first'));
      final middleNameIndex = header.indexWhere((h) => h == 'middle name' || h == 'middlename' || h == 'middle_name' || h.contains('middle') || h.contains('initial') || h == 'mi' || h == 'm.i.');
      final genderIndex = header.indexWhere((h) => h == 'gender' || h == 'sex');
      final birthdayIndex = header.indexWhere((h) => h == 'birthday' || h == 'birthdate' || h == 'birth date' || h == 'dob' || h.contains('birth'));

      // Check 1: Wrong File Uploaded (Required headers match)
      final hasRequiredHeaders = lrnIndex != -1 &&
          emailIndex != -1 &&
          lastNameIndex != -1 &&
          firstNameIndex != -1 &&
          genderIndex != -1 &&
          birthdayIndex != -1;

      if (!hasRequiredHeaders) {
        setState(() {
          _isProcessingBatch = false;
          _batchProgress = 0.0;
          _batchWarningTitle = 'Invalid File Format';
          _batchWarningMessage = 'Invalid file format. Please use the official downloaded template.';
        });
        AppModals.showErrorDialog(
          context: context,
          title: 'Invalid File Format',
          message: 'Invalid file format. Please use the official downloaded template.',
        );
        return;
      }

      final totalDataRows = rows.length - 1;
      if (mounted) {
        setState(() {
          _batchProgress = 0.10;
          _batchPhase = 'Found $totalDataRows records. Validating...';
        });
      }

      final candidateStudents = <_ParsedStudentRow>[];
      final invalidRows = <_InvalidStudentRow>[];
      final seenLrnsInFile = <String>{};
      final seenEmailsInFile = <String>{};
      final now = DateTime.now();

      // Allowed domains whitelist
      const allowedEmailDomains = [
        '@gmail.com',
        '@yahoo.com',
        '@outlook.com',
        '@hotmail.com',
        '@deped.gov.ph',
        '@lu.edu.ph',
      ];
      final emailStrictRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final rowNum = i + 1;

        if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
          continue;
        }

        final rawLrn = (lrnIndex < row.length ? row[lrnIndex] : '').toString().replaceAll('\uFEFF', '').trim();
        final rawFirst = (firstNameIndex < row.length ? row[firstNameIndex] : '').toString().replaceAll('\uFEFF', '').trim();
        final rawMiddle = (middleNameIndex != -1 && middleNameIndex < row.length ? row[middleNameIndex] : '').toString().replaceAll('\uFEFF', '').trim();
        final rawLast = (lastNameIndex < row.length ? row[lastNameIndex] : '').toString().replaceAll('\uFEFF', '').trim();
        final rawGender = (genderIndex < row.length ? row[genderIndex] : '').toString().replaceAll('\uFEFF', '').trim();
        final rawBday = (birthdayIndex < row.length ? row[birthdayIndex] : '').toString().replaceAll('\uFEFF', '').trim();
        final rawEmail = (emailIndex < row.length ? row[emailIndex] : '').toString().replaceAll('\uFEFF', '').trim().toLowerCase();

        final cleanLrn = rawLrn.replaceAll(RegExp(r'\D'), '');
        final studentLabel = rawFirst.isNotEmpty ? '$rawFirst $rawLast' : (rawLrn.isNotEmpty ? 'LRN $rawLrn' : 'Row $rowNum');

        // Live real-time in-card progress update
        if (mounted) {
          final rowProgress = ((i / totalDataRows) * 0.70).clamp(0.05, 0.70);
          setState(() {
            _batchProgress = rowProgress;
            _batchPhase = 'Validating records... ($i of $totalDataRows)';
            _batchActiveRecord = 'Row $rowNum: $studentLabel';
          });
        }

        // Micro-delay for visual responsiveness
        if (totalDataRows <= 40) {
          await Future.delayed(const Duration(milliseconds: 25));
        } else if (i % 2 == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Silently skip sample row (Row 2 in template)
        final isSampleRow = (cleanLrn == '123456789012' &&
                (rawFirst.toLowerCase() == 'juana' ||
                    rawFirst.toLowerCase() == 'rexsa' ||
                    rawLast.toLowerCase().contains('dela cruz') ||
                    rawEmail.contains('example@gmail.com') ||
                    rawEmail.contains('juana.rexsa@gmail.com'))) ||
            (rowNum == 2 && cleanLrn == '123456789012');

        if (isSampleRow) {
          continue;
        }

        // 3. LRN Format Check (Contains letters/symbols, length != 12, starts with 0, or repeating digits)
        final isPureDigits = RegExp(r'^\d+$').hasMatch(rawLrn);
        final startsWithZero = rawLrn.startsWith('0');
        final isRepeatingDigits = RegExp(r'^(\d)\1{11}$').hasMatch(rawLrn);
        if (rawLrn.isEmpty || !isPureDigits || rawLrn.length != 12 || startsWithZero || isRepeatingDigits) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'LRN',
            identifier: rawLrn.isEmpty ? 'Empty' : rawLrn,
            reason: 'Must be exactly 12 digits.',
          ));
          continue;
        }

        // 4. Duplicate LRN (In File)
        if (seenLrnsInFile.contains(cleanLrn)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'LRN',
            identifier: cleanLrn,
            reason: 'Duplicate LRN in file.',
          ));
          continue;
        }
        seenLrnsInFile.add(cleanLrn);

        // 5. Email Strict Format / Domain Check
        final hasAllowedDomain = allowedEmailDomains.any((d) => rawEmail.endsWith(d));
        final isTypoOrDummy = rawEmail == 'example@gmail.com' ||
            rawEmail == 'sample@gmail.com' ||
            rawEmail == 'test@test.com' ||
            rawEmail == 'none@gmail.com' ||
            rawEmail.contains('@gamil.') ||
            rawEmail.contains('@yaho.') ||
            rawEmail.contains('@gmal.') ||
            rawEmail.endsWith('.con') ||
            rawEmail.endsWith('.test');

        if (!emailStrictRegex.hasMatch(rawEmail) || !hasAllowedDomain || isTypoOrDummy) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Email',
            identifier: rawEmail.isEmpty ? 'Empty' : rawEmail,
            reason: 'Invalid email address.',
          ));
          continue;
        }

        // Duplicate Email within file
        if (seenEmailsInFile.contains(rawEmail)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Email',
            identifier: rawEmail,
            reason: 'Duplicate email in file.',
          ));
          continue;
        }
        seenEmailsInFile.add(rawEmail);

        // 7. Name Format (First, Middle, Last)
        // First Name
        if (rawFirst.isEmpty) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'First Name',
            identifier: 'Empty',
            reason: 'First name is required.',
          ));
          continue;
        }
        if (RegExp(r'[0-9]').hasMatch(rawFirst)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'First Name',
            identifier: rawFirst,
            reason: 'Cannot contain numbers.',
          ));
          continue;
        }
        if (!RegExp(r"^[a-zA-Z\s\-\.\'ñÑ]+$").hasMatch(rawFirst)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'First Name',
            identifier: rawFirst,
            reason: 'Invalid special characters.',
          ));
          continue;
        }
        if (rawFirst.length < 2 || rawFirst.length > 30) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'First Name',
            identifier: rawFirst,
            reason: 'First name must be between 2 and 30 characters.',
          ));
          continue;
        }

        // Last Name
        if (rawLast.isEmpty) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Last Name',
            identifier: 'Empty',
            reason: 'Last name is required.',
          ));
          continue;
        }
        if (RegExp(r'[0-9]').hasMatch(rawLast)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Last Name',
            identifier: rawLast,
            reason: 'Cannot contain numbers.',
          ));
          continue;
        }
        if (!RegExp(r"^[a-zA-Z\s\-\.\'ñÑ]+$").hasMatch(rawLast)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Last Name',
            identifier: rawLast,
            reason: 'Invalid special characters.',
          ));
          continue;
        }
        if (rawLast.length < 2 || rawLast.length > 30) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Last Name',
            identifier: rawLast,
            reason: 'Last name must be between 2 and 30 characters.',
          ));
          continue;
        }

        // Middle Initial (Optional, max 1 character, no numbers)
        String cleanMiddle = '';
        if (rawMiddle.isNotEmpty) {
          if (RegExp(r'[0-9]').hasMatch(rawMiddle)) {
            invalidRows.add(_InvalidStudentRow(
              rowNumber: rowNum,
              fieldTag: 'Middle Initial',
              identifier: rawMiddle,
              reason: 'Cannot contain numbers.',
            ));
            continue;
          }
          if (!RegExp(r"^[a-zA-Z\s\-\.\'ñÑ]+$").hasMatch(rawMiddle)) {
            invalidRows.add(_InvalidStudentRow(
              rowNumber: rowNum,
              fieldTag: 'Middle Initial',
              identifier: rawMiddle,
              reason: 'Invalid special characters.',
            ));
            continue;
          }
          if (rawMiddle.length > 1) {
            invalidRows.add(_InvalidStudentRow(
              rowNumber: rowNum,
              fieldTag: 'Middle Initial',
              identifier: rawMiddle,
              reason: 'Must be 1 letter only.',
            ));
            continue;
          }
          cleanMiddle = rawMiddle.toUpperCase();
        }

        // Gender Check
        final parsedGender = _parseGender(rawGender);
        if (parsedGender == null) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Gender',
            identifier: rawGender.isEmpty ? 'Empty' : rawGender,
            reason: 'Must be Male or Female.',
          ));
          continue;
        }

        // 8. Birthday Parsing (Handles YYYY-MM-DD and Excel serial date)
        final parsedBday = _parseBirthday(rawBday);
        if (parsedBday == null || RegExp(r'[a-zA-Z]').hasMatch(rawBday)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Birthday',
            identifier: rawBday.isEmpty ? 'Empty' : rawBday,
            reason: 'Use YYYY-MM-DD format.',
          ));
          continue;
        }

        // 9. Age Limits Check (10 - 50 years old)
        int age = now.year - parsedBday.year;
        if (now.month < parsedBday.month || (now.month == parsedBday.month && now.day < parsedBday.day)) {
          age--;
        }
        if (parsedBday.isAfter(now) || age < 10 || age > 50) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            fieldTag: 'Birthday',
            identifier: rawBday,
            reason: 'Must be 10-50 years old.',
          ));
          continue;
        }

        candidateStudents.add(_ParsedStudentRow(
          rowNumber: rowNum,
          lrn: cleanLrn,
          firstName: _toTitleCase(rawFirst),
          middleName: cleanMiddle,
          lastName: _toTitleCase(rawLast),
          gender: parsedGender,
          birthday: parsedBday,
          email: rawEmail,
        ));
      }

      // Check 2: Blank File / No Data (Valid headers, but 0 data rows found)
      if (candidateStudents.isEmpty && invalidRows.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessingBatch = false;
            _batchProgress = 0.0;
            _batchWarningTitle = 'Empty File';
            _batchWarningMessage = 'The uploaded file is empty. Please fill in the student data before uploading.';
          });
          AppModals.showErrorDialog(
            context: context,
            title: 'Empty File',
            message: 'The uploaded file is empty. Please fill in the student data before uploading.',
          );
        }
        return;
      }

      if (candidateStudents.isNotEmpty && mounted) {
        setState(() {
          _batchProgress = 0.85;
          _batchPhase = 'Verifying with database...';
          _batchActiveRecord = 'Checking accounts and enrollments in Supabase';
        });
        await Future.delayed(const Duration(milliseconds: 80));
      }

      // Supabase Database Checks (Checks 6, 10, 11, 12)
      final eligibleNewStudents = <_ParsedStudentRow>[];
      final eligibleExistingStudents = <_ParsedStudentRow>[];
      final alreadyEnrolledStudents = <_ParsedStudentRow>[];

      if (candidateStudents.isNotEmpty) {
        final client = Supabase.instance.client;
        final cleanLrns = candidateStudents.map((s) => s.lrn).toList();
        final cleanEmails = candidateStudents.map((s) => s.email).toList();

        // Fetch matching student profiles
        final List<dynamic> profilesRes = await client
            .from('student_profiles')
            .select('student_id, lrn, first_name, last_name')
            .filter('lrn', 'in', cleanLrns);

        final profileMap = <String, Map<String, dynamic>>{};
        final studentIds = <String>[];
        for (final p in profilesRes) {
          final lrn = (p['lrn'] ?? '').toString();
          if (lrn.isNotEmpty) {
            profileMap[lrn] = p as Map<String, dynamic>;
            final sId = (p['student_id'] ?? '').toString();
            if (sId.isNotEmpty) studentIds.add(sId);
          }
        }

        // Fetch users to detect email collisions
        final List<dynamic> usersRes = await client
            .from('users')
            .select('id, email, role')
            .filter('email', 'in', cleanEmails);

        final userEmailMap = <String, Map<String, dynamic>>{};
        for (final u in usersRes) {
          final em = (u['email'] ?? '').toString().toLowerCase();
          if (em.isNotEmpty) userEmailMap[em] = u as Map<String, dynamic>;
        }

        // Fetch existing enrollments for this class offering
        final enrollmentMap = <String, String>{};
        if (studentIds.isNotEmpty && _selectedOfferingId != null) {
          final List<dynamic> enrollRes = await client
              .from('student_enrollments')
              .select('student_id, status')
              .eq('subject_offering_id', _selectedOfferingId!)
              .filter('student_id', 'in', studentIds);

          for (final e in enrollRes) {
            final sId = (e['student_id'] ?? '').toString();
            final st = (e['status'] ?? '').toString();
            if (sId.isNotEmpty) {
              enrollmentMap[sId] = st;
            }
          }
        }

        // Fetch current enrolled counts by gender to enforce Section Capacity (Max 50 Male, Max 50 Female)
        int currentMaleEnrolled = 0;
        int currentFemaleEnrolled = 0;
        try {
          if (_selectedOfferingId != null) {
            final List<dynamic> currentSectionStudents = await client
                .from('student_enrollments')
                .select('student_profiles!inner(gender)')
                .eq('subject_offering_id', _selectedOfferingId!)
                .ilike('status', 'enrolled');

            for (final item in currentSectionStudents) {
              final profile = item['student_profiles'] as Map<String, dynamic>?;
              final g = profile?['gender']?.toString().toLowerCase();
              if (g == 'male') currentMaleEnrolled++;
              if (g == 'female') currentFemaleEnrolled++;
            }
          }
        } catch (_) {}

        // Evaluate candidate rows against DB records
        for (final s in candidateStudents) {
          final existingProfile = profileMap[s.lrn];

          // 6. Duplicate Email (In Database)
          final existingUser = userEmailMap[s.email];
          if (existingUser != null) {
            final existingUserId = existingUser['id']?.toString() ?? '';
            final expectedStudentId = existingProfile?['student_id']?.toString() ?? '';

            if (existingUserId != expectedStudentId) {
              invalidRows.add(_InvalidStudentRow(
                rowNumber: s.rowNumber,
                fieldTag: 'Email',
                identifier: s.email,
                reason: 'Email already in use.',
              ));
              continue;
            }
          }

          if (existingProfile == null) {
            // 12. Section Capacity Limit (New Student)
            if (s.gender.toLowerCase() == 'male') {
              if (currentMaleEnrolled >= 50) {
                invalidRows.add(_InvalidStudentRow(
                  rowNumber: s.rowNumber,
                  fieldTag: 'Capacity',
                  identifier: s.gender,
                  reason: 'Capacity exceeded. Max 50 per gender. (Found: Male (${currentMaleEnrolled + 1})).',
                ));
                continue;
              }
              currentMaleEnrolled++;
            } else if (s.gender.toLowerCase() == 'female') {
              if (currentFemaleEnrolled >= 50) {
                invalidRows.add(_InvalidStudentRow(
                  rowNumber: s.rowNumber,
                  fieldTag: 'Capacity',
                  identifier: s.gender,
                  reason: 'Capacity exceeded. Max 50 per gender. (Found: Female (${currentFemaleEnrolled + 1})).',
                ));
                continue;
              }
              currentFemaleEnrolled++;
            }

            // Eligible New Student
            eligibleNewStudents.add(s);
          } else {
            // 10. Duplicate LRN (In Database) - Check name match
            final dbFirst = (existingProfile['first_name'] ?? '').toString().trim().toLowerCase();
            final dbLast = (existingProfile['last_name'] ?? '').toString().trim().toLowerCase();
            final uploadFirst = s.firstName.trim().toLowerCase();
            final uploadLast = s.lastName.trim().toLowerCase();

            if (dbFirst != uploadFirst || dbLast != uploadLast) {
              invalidRows.add(_InvalidStudentRow(
                rowNumber: s.rowNumber,
                fieldTag: 'LRN',
                identifier: s.lrn,
                reason: 'LRN already registered.',
              ));
              continue;
            }

            // 11. Already Enrolled in class: Skip re-enrolling, but continue with remaining students!
            final existingStudentId = (existingProfile['student_id'] ?? '').toString();
            final enrollStatus = enrollmentMap[existingStudentId];

            if (enrollStatus == 'enrolled') {
              alreadyEnrolledStudents.add(s);
              // Safely skipped: student is already enrolled in this class, continue with remaining records
              continue;
            } else if (enrollStatus == 'archived') {
              invalidRows.add(_InvalidStudentRow(
                rowNumber: s.rowNumber,
                fieldTag: 'Class',
                identifier: s.lrn,
                reason: 'Archived in this class (use Restore in Manage Students).',
              ));
              continue;
            }

            // 12. Section Capacity Limit (Existing Student from another class)
            if (s.gender.toLowerCase() == 'male') {
              if (currentMaleEnrolled >= 50) {
                invalidRows.add(_InvalidStudentRow(
                  rowNumber: s.rowNumber,
                  fieldTag: 'Capacity',
                  identifier: s.gender,
                  reason: 'Capacity exceeded. Max 50 per gender. (Found: Male (${currentMaleEnrolled + 1})).',
                ));
                continue;
              }
              currentMaleEnrolled++;
            } else if (s.gender.toLowerCase() == 'female') {
              if (currentFemaleEnrolled >= 50) {
                invalidRows.add(_InvalidStudentRow(
                  rowNumber: s.rowNumber,
                  fieldTag: 'Capacity',
                  identifier: s.gender,
                  reason: 'Capacity exceeded. Max 50 per gender. (Found: Female (${currentFemaleEnrolled + 1})).',
                ));
                continue;
              }
              currentFemaleEnrolled++;
            }

            // Eligible Existing Student
            eligibleExistingStudents.add(_ParsedStudentRow(
              rowNumber: s.rowNumber,
              lrn: s.lrn,
              firstName: s.firstName,
              middleName: s.middleName,
              lastName: s.lastName,
              gender: s.gender,
              birthday: s.birthday,
              email: s.email,
              isExistingGlobalStudent: true,
              existingStudentId: existingStudentId,
            ));
          }
        }
      }

      final allEligible = [...eligibleNewStudents, ...eligibleExistingStudents];

      if (mounted) {
        setState(() {
          _batchProgress = 1.0;
          _isProcessingBatch = false;
          _eligibleNewStudents = eligibleNewStudents;
          _eligibleExistingStudents = eligibleExistingStudents;
          _alreadyEnrolledStudents = alreadyEnrolledStudents;
          _detectedInvalidRows = invalidRows;
        });
      }

      if (invalidRows.isNotEmpty) {
        // Errors detected: Show the Issues Error Modal
        if (mounted) {
          setState(() {
            _batchPhase = 'Validation Issues Found';
            _batchActiveRecord = '${invalidRows.length} issue${invalidRows.length > 1 ? "s" : ""} detected in spreadsheet';
          });
        }
        await _showIssuesErrorDialog();
      } else if (allEligible.isNotEmpty) {
        // Valid students ready for enrollment: Directly enroll into the database!
        if (mounted) {
          setState(() {
            _batchPhase = 'Enrolling in Database...';
            _batchActiveRecord = 'All ${allEligible.length} student${allEligible.length > 1 ? "s" : ""} valid. Writing to database...';
          });
        }
        await _executeBatchEnrollment(
          allEligible,
          fileName: _batchFileName ?? 'Spreadsheet',
        );
      } else if (alreadyEnrolledStudents.isNotEmpty) {
        // All students were already enrolled
        if (mounted) {
          setState(() {
            _batchPhase = 'Upload Complete';
            _batchActiveRecord = 'All ${alreadyEnrolledStudents.length} student(s) already enrolled.';
          });
          AppModals.showSuccessDialog(
            context: context,
            title: 'Already Enrolled',
            message: 'All ${alreadyEnrolledStudents.length} student(s) in this file are already enrolled in this class. No duplicate enrollments were made.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingBatch = false;
          _batchWarningMessage = e.toString().replaceAll('Exception: ', '');
        });
        AppModals.showErrorDialog(
          context: context,
          title: 'Import Error',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _showIssuesErrorDialog() async {
    if (_detectedInvalidRows.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Spreadsheet Issues Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.graduationCap, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Target: $_selectedGradeLevel • $_selectedSubjectName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 4 Metric Badges in exact order: Issues (X) | New Students (Y) | Existing (Z) | Enrolled (W)
              Row(
                children: [
                  _buildStatPill('Issues', _detectedInvalidRows.length, Colors.red),
                  const SizedBox(width: 6),
                  _buildStatPill('New Students', _eligibleNewStudents.length, const Color(0xFF0F8A48)),
                  const SizedBox(width: 6),
                  _buildStatPill('Existing', _eligibleExistingStudents.length, Colors.blue),
                  const SizedBox(width: 6),
                  _buildStatPill('Enrolled', _alreadyEnrolledStudents.length, Colors.grey),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Issues Detected (Upload Blocked):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                  ),
                  Text(
                    '${_detectedInvalidRows.length} error${_detectedInvalidRows.length > 1 ? "s" : ""}',
                    style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _detectedInvalidRows.length,
                  itemBuilder: (_, idx) {
                    final item = _detectedInvalidRows[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
                          children: [
                            TextSpan(
                              text: 'Row ${item.rowNumber} ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            TextSpan(
                              text: '(${item.fieldTag}: ${item.identifier}): ',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                            ),
                            TextSpan(
                              text: item.reason,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.alertCircle, size: 14, color: Colors.deepOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Strict Policy: All issues must be corrected in your spreadsheet before enrolling.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please fix all ${_detectedInvalidRows.length} issue${_detectedInvalidRows.length > 1 ? "s" : ""} in your spreadsheet and upload again to proceed.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(LucideIcons.folderOpen, size: 14),
            label: const Text('Upload Fixed File'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processBatchImport();
            },
          ),
        ],
      ),
    );
  }

  int _colLetterToIndex(String letters) {
    int col = 0;
    for (int i = 0; i < letters.length; i++) {
      col = col * 26 + (letters.codeUnitAt(i) - 64);
    }
    return col - 1;
  }

  String _decodeXmlEntities(String str) {
    return str
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  List<List<dynamic>> _parseXlsxBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStrings = <String>[];
      final ssFile = archive.findFile('xl/sharedStrings.xml');
      if (ssFile != null) {
        final ssXml = utf8.decode(ssFile.content as List<int>);
        // OpenXML shared strings are <si>...</si> entries with one or more <t> runs
        final siMatches = RegExp(r'<si\b[^>]*>(.*?)<\/si>', dotAll: true).allMatches(ssXml);
        for (final si in siMatches) {
          final siContent = si.group(1) ?? '';
          final tMatches = RegExp(r'<t(?:\s[^>]*)?>([^<]*)<\/t>').allMatches(siContent);
          final buffer = StringBuffer();
          for (final tm in tMatches) {
            buffer.write(tm.group(1) ?? '');
          }
          sharedStrings.add(_decodeXmlEntities(buffer.toString()));
        }
      }

      ArchiveFile? sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
      if (sheetFile == null) {
        for (final f in archive.files) {
          if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
            sheetFile = f;
            break;
          }
        }
      }

      if (sheetFile == null) {
        throw Exception('Could not locate worksheet in the Excel file.');
      }

      final sheetXml = utf8.decode(sheetFile.content as List<int>);
      final rowMatches = RegExp(r'<row\b[^>]*>(.*?)<\/row>', dotAll: true).allMatches(sheetXml);

      final allRows = <List<dynamic>>[];
      for (final rm in rowMatches) {
        final rowXml = rm.group(1) ?? '';
        final cellTagMatches = RegExp(r'<c\b([^>]*)(?:\/>|>(.*?)<\/c>)', dotAll: true).allMatches(rowXml);

        final rowMap = <int, dynamic>{};
        int maxCol = -1;

        for (final cm in cellTagMatches) {
          final attrs = cm.group(1) ?? '';
          final body = cm.group(2) ?? '';

          final rMatch = RegExp(r'\br="([A-Za-z]+)(\d+)"').firstMatch(attrs);
          if (rMatch == null) continue;

          final colLetters = rMatch.group(1)!.toUpperCase();
          final colIdx = _colLetterToIndex(colLetters);

          final tMatch = RegExp(r'\bt="([A-Za-z]+)"').firstMatch(attrs);
          final cellType = (tMatch?.group(1) ?? '').toLowerCase();

          String rawVal = '';
          final vMatch = RegExp(r'<v\b[^>]*>([^<]*)<\/v>').firstMatch(body);
          if (vMatch != null) {
            rawVal = vMatch.group(1) ?? '';
          } else {
            final tMatchInBody = RegExp(r'<t\b[^>]*>([^<]*)<\/t>').firstMatch(body);
            if (tMatchInBody != null) {
              rawVal = tMatchInBody.group(1) ?? '';
            }
          }

          dynamic finalVal = _decodeXmlEntities(rawVal);
          if (cellType == 's' && int.tryParse(rawVal) != null) {
            final sIdx = int.parse(rawVal);
            if (sIdx >= 0 && sIdx < sharedStrings.length) {
              finalVal = sharedStrings[sIdx];
            }
          }

          if (colIdx >= 0) {
            rowMap[colIdx] = finalVal;
            if (colIdx > maxCol) maxCol = colIdx;
          }
        }

        if (maxCol >= 0) {
          final rowData = List<dynamic>.filled(maxCol + 1, '');
          rowMap.forEach((idx, val) {
            rowData[idx] = val;
          });
          allRows.add(rowData);
        }
      }
      return allRows;
    } catch (e) {
      throw Exception('Failed to read Excel (.xlsx) file: ${e.toString().replaceAll('Exception: ', '')}. You can also save as .csv and upload.');
    }
  }

  Widget _buildStatPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _executeBatchEnrollment(
    List<_ParsedStudentRow> students, {
    bool isResumed = false,
    String fileName = 'Spreadsheet',
  }) async {
    final repo = SupabaseStudentRepository();
    final successful = <_ParsedStudentRow>[];
    final failed = <Map<String, dynamic>>[];
    final credentialsRoster = <Map<String, String>>[];
    final newlyCreatedStudents = <Map<String, dynamic>>[];

    SharedPreferences? prefs;
    String? sessionKey;
    List<Map<String, dynamic>> pendingJson = [];

    try {
      prefs = await SharedPreferences.getInstance();
      sessionKey = 'batch_enroll_session_$_selectedOfferingId';

      pendingJson = students.map((s) => {
        'rowNumber': s.rowNumber,
        'lrn': s.lrn,
        'firstName': s.firstName,
        'middleName': s.middleName,
        'lastName': s.lastName,
        'gender': s.gender,
        'birthday': s.birthday.toIso8601String(),
        'email': s.email,
        'isExistingGlobalStudent': s.isExistingGlobalStudent,
        'existingStudentId': s.existingStudentId,
      }).toList();

      await prefs.setString(sessionKey, jsonEncode({
        'fileName': fileName,
        'offeringId': _selectedOfferingId,
        'total': students.length,
        'pending': pendingJson,
      }));
    } catch (_) {}

    final enrollProgressNotifier = ValueNotifier<_EnrollmentProgressData>(
      _EnrollmentProgressData(
        phase: 'Writing to database...',
        currentIdx: 0,
        totalCount: students.length,
        currentStudentName: 'Preparing student accounts...',
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: ValueListenableBuilder<_EnrollmentProgressData>(
            valueListenable: enrollProgressNotifier,
            builder: (context, prog, _) {
              final progress = prog.progress;
              final percent = prog.percent;
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isResumed ? 'Resuming Enrollment...' : 'Enrolling Students in Bulk...',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${prog.phase} (${prog.currentIdx} of ${prog.totalCount})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        prog.currentStudentName.isNotEmpty ? prog.currentStudentName : 'Preparing student accounts...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    // Phase A: Fast Database Enrollment Loop (Decoupled, skipEmail: true)
    bool isNetworkLoss = false;

    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      enrollProgressNotifier.value = _EnrollmentProgressData(
        phase: 'Enrolling in database',
        currentIdx: i + 1,
        totalCount: students.length,
        currentStudentName: '${s.firstName} ${s.lastName} (LRN: ${s.lrn})',
      );

      try {
        final result = await repo.enrollStudent(
          lrn: s.lrn,
          firstName: s.firstName,
          middleName: s.middleName,
          lastName: s.lastName,
          birthday: s.birthday,
          email: s.email,
          gender: s.gender,
          subjectId: _selectedOfferingId!,
          skipEmail: true,
        );

        if (result.studentId.isNotEmpty) {
          successful.add(s);
          if (result.createdAccount && result.tempPassword != null) {
            newlyCreatedStudents.add({
              'email': s.email,
              'name': '${s.firstName} ${s.lastName}',
              'password': result.tempPassword!,
              'lrn': s.lrn,
            });
            credentialsRoster.add({
              'lrn': s.lrn,
              'name': '${s.firstName} ${s.lastName}',
              'email': s.email,
              'password': result.tempPassword!,
            });
          }
        }

        // Update persisted pending batch session on each successful row
        pendingJson.removeWhere((item) => item['lrn'] == s.lrn);
        if (prefs != null && sessionKey != null) {
          await prefs.setString(sessionKey, jsonEncode({
            'fileName': fileName,
            'offeringId': _selectedOfferingId,
            'total': students.length,
            'pending': pendingJson,
          }));
        }
      } catch (e) {
        final errLower = e.toString().toLowerCase();
        final isNet = errLower.contains('socketexception') ||
            errLower.contains('clientexception') ||
            errLower.contains('network') ||
            errLower.contains('failed host lookup') ||
            errLower.contains('connection refused') ||
            errLower.contains('connection timed out') ||
            errLower.contains('xmlhttprequest') ||
            errLower.contains('handshakeexception') ||
            errLower.contains('timeout');

        if (isNet) {
          isNetworkLoss = true;
          break; // Stop loop immediately to protect remaining un-enrolled students
        } else {
          failed.add({
            'student': s,
            'error': e.toString().replaceAll('Exception: ', '').trim(),
          });
          pendingJson.removeWhere((item) => item['lrn'] == s.lrn);
          if (prefs != null && sessionKey != null) {
            await prefs.setString(sessionKey, jsonEncode({
              'fileName': fileName,
              'offeringId': _selectedOfferingId,
              'total': students.length,
              'pending': pendingJson,
            }));
          }
        }
      }
    }

    if (isNetworkLoss) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        enrollProgressNotifier.dispose();
        await _checkResumableBatch();
        widget.onStudentCreated(); // refresh dashboard roster with whatever succeeded

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.wifiOff, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Network Disconnected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The internet connection was interrupted during the upload process.\n\n'
                  '• ${successful.length} student${successful.length != 1 ? "s were" : " was"} successfully enrolled.\n'
                  '• ${pendingJson.length} student${pendingJson.length != 1 ? "s remain" : " remains"} in your upload session.\n\n'
                  'ClassRealm saved your progress. When your internet is back, click "Resume Upload" to continue without starting over from the beginning.',
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                icon: const Icon(LucideIcons.refreshCw, size: 15),
                label: const Text('Resume Upload Now'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F8A48)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeBatchEnrollment();
                },
              ),
            ],
          ),
        );
      }
      return;
    }

    // Phase B: Throttled Credential Email Queue (Decoupled background dispatch)
    int emailSentCount = 0;
    int emailFailedCount = 0;

    if (newlyCreatedStudents.isNotEmpty) {
      enrollProgressNotifier.value = _EnrollmentProgressData(
        phase: 'Sending welcome emails',
        currentIdx: newlyCreatedStudents.length,
        totalCount: newlyCreatedStudents.length,
        currentStudentName: 'Dispatching credentials securely in background...',
      );

      const chunkSize = 4;
      for (int i = 0; i < newlyCreatedStudents.length; i += chunkSize) {
        final end = (i + chunkSize < newlyCreatedStudents.length) ? i + chunkSize : newlyCreatedStudents.length;
        final chunk = newlyCreatedStudents.sublist(i, end);

        await Future.wait(
          chunk.map((item) async {
            try {
              final ok = await EmailService.instance.sendStudentWelcomeEmail(
                recipientEmail: item['email'] as String,
                studentName: item['name'] as String,
                tempPassword: item['password'] as String,
              );
              if (ok) {
                emailSentCount++;
              } else {
                emailFailedCount++;
              }
            } catch (_) {
              emailFailedCount++;
            }
          }),
        );

        if (end < newlyCreatedStudents.length) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }

    if (prefs != null && sessionKey != null) {
      await prefs.remove(sessionKey);
      if (mounted) setState(() => _resumableBatch = null);
    }

    if (mounted) {
      Navigator.of(context).pop(); // dismiss progress dialog
      enrollProgressNotifier.dispose();
      Navigator.of(context).pop(); // dismiss unified dialog
      widget.onStudentCreated(); // refresh dashboard roster

      _showBatchResultDialog(
        successful: successful,
        failed: failed,
        credentialsRoster: credentialsRoster,
        emailSentCount: emailSentCount,
        emailFailedCount: emailFailedCount,
      );
    }
  }

  void _showBatchResultDialog({
    required List<_ParsedStudentRow> successful,
    required List<Map<String, dynamic>> failed,
    required List<Map<String, String>> credentialsRoster,
    required int emailSentCount,
    required int emailFailedCount,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (failed.isEmpty ? const Color(0xFF0F8A48) : Colors.orange).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                failed.isEmpty ? LucideIcons.checkCheck : LucideIcons.alertTriangle,
                color: failed.isEmpty ? const Color(0xFF0F8A48) : Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Batch Enrollment Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatPill('Enrolled', successful.length, const Color(0xFF0F8A48)),
                  const SizedBox(width: 8),
                  _buildStatPill('Emails Sent', emailSentCount, Colors.blue),
                  const SizedBox(width: 8),
                  _buildStatPill('Issues/Skipped', failed.length, failed.isEmpty ? Colors.grey : Colors.red),
                ],
              ),
              if (emailFailedCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        '$emailFailedCount email${emailFailedCount > 1 ? "s" : ""} could not be delivered. You can copy the credentials below.',
                        style: const TextStyle(fontSize: 11, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
              ],
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Students Not Enrolled:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 130),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: failed.length,
                    itemBuilder: (_, idx) {
                      final item = failed[idx];
                      final s = item['student'] as _ParsedStudentRow;
                      final err = item['error'] as String;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${s.firstName} ${s.lastName} (${s.lrn}): $err',
                          style: const TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                successful.isNotEmpty
                    ? 'The enrolled students are now active and visible in your class roster.'
                    : 'No students were enrolled due to the errors above.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          if (credentialsRoster.isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.copy, size: 15),
              label: const Text('Copy Credentials Roster'),
              onPressed: () {
                final buffer = StringBuffer();
                buffer.writeln('LRN\tStudent Name\tEmail\tTemporary Password');
                for (final c in credentialsRoster) {
                  buffer.writeln('${c['lrn']}\t${c['name']}\t${c['email']}\t${c['password']}');
                }
                Clipboard.setData(ClipboardData(text: buffer.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student credentials roster copied to clipboard!'),
                    backgroundColor: Color(0xFF0F8A48),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSuccessConfirmationDialog({
    required BuildContext context,
    required String fullName,
    required String email,
    String? tempPassword,
    required bool createdAccount,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon Animation / Graphic
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.catGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.catGreen.withValues(alpha: 0.2), width: 6),
                ),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  color: AppTheme.catGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                createdAccount ? 'Student Successfully Added' : 'Student Enrolled',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              Text(
                createdAccount
                    ? 'Login credentials were sent to the student\'s email address. They will be prompted to create a new password upon their first login.'
                    : 'The student was successfully enrolled into this subject and section.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Modern Details Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    _buildInfoRow('Student Name', fullName, theme),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    _buildInfoRow('Email Address', email, theme),
                    if (tempPassword != null && tempPassword.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow('Temporary Password', tempPassword, theme, isCode: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme, {bool isCode = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCode ? 10 : 0, vertical: isCode ? 4 : 0),
            decoration: isCode
                ? BoxDecoration(
                    color: AppTheme.catBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.catBlue.withValues(alpha: 0.2)),
                  )
                : null,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCode ? FontWeight.bold : FontWeight.w600,
                color: isCode ? AppTheme.catBlue : theme.colorScheme.onSurface,
                fontFamily: isCode ? 'monospace' : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Dialog(
          backgroundColor: theme.colorScheme.surface,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Modal Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.userPlus,
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
                            'Student Enrollment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enroll into subjects & sections or import in bulk',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Tab Bar (Add New vs Import File) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: theme.colorScheme.onSurface
                        .withValues(alpha: 0.7),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.userPlus, size: 16),
                            SizedBox(width: 8),
                            Text('Add Student'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.fileSpreadsheet, size: 16),
                            SizedBox(width: 8),
                            Text('Import Excel File'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Cascading Target Selection (Grade -> Subject -> Section) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildClassroomSelectionCard(theme, isDark),
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.2)),

              // ── Tab Views ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Single Student Form
                    _buildManualStudentForm(theme),
                    // Tab 2: Batch File Import
                    _buildBatchImportView(theme, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Target Classroom Cascading Selector
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildClassroomSelectionCard(ThemeData theme, bool isDark) {
    final gradeLevels = _availableGradeLevels;
    final subjects = _selectedGradeLevel != null
        ? _getSubjectsForGrade(_selectedGradeLevel!)
        : <String>[];
    final sections =
        (_selectedGradeLevel != null && _selectedSubjectName != null)
            ? _getSectionsForSubject(
                _selectedGradeLevel!,
                _selectedSubjectName!,
              )
            : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : theme.colorScheme.primary.withValues(alpha: 0.04),
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
              Icon(LucideIcons.graduationCap, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
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
          const SizedBox(height: 10),
          Row(
            children: [
              // Grade Level Dropdown
              Expanded(
                flex: 3,
                child: _buildSelectorField(
                  label: 'Grade Level',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGradeLevel,
                    isExpanded: true,
                    decoration: _inputDecoration(theme),
                    hint: const Text('Grade', style: TextStyle(fontSize: 12)),
                    items: gradeLevels.map((g) {
                      return DropdownMenuItem(
                        value: g,
                        child: Text(g, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGradeLevel = val;
                          final subs = _getSubjectsForGrade(val);
                          _selectedSubjectName = subs.isNotEmpty ? subs.first : null;
                          if (_selectedSubjectName != null) {
                            final secs = _getSectionsForSubject(val, _selectedSubjectName!);
                            _selectedOfferingId =
                                secs.isNotEmpty ? secs.first['id']?.toString() : null;
                          } else {
                            _selectedOfferingId = null;
                          }
                        });
                        _checkResumableBatch();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Subject Dropdown
              Expanded(
                flex: 5,
                child: _buildSelectorField(
                  label: 'Subject',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubjectName,
                    isExpanded: true,
                    decoration: _inputDecoration(theme),
                    hint: const Text('Select Subject', style: TextStyle(fontSize: 12)),
                    items: subjects.map((sub) {
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
                          _selectedSubjectName = val;
                          final secs = _getSectionsForSubject(
                            _selectedGradeLevel ?? '',
                            val,
                          );
                          _selectedOfferingId =
                              secs.isNotEmpty ? secs.first['id']?.toString() : null;
                        });
                        _checkResumableBatch();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Section Dropdown
              Expanded(
                flex: 4,
                child: _buildSelectorField(
                  label: 'Section',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedOfferingId,
                    isExpanded: true,
                    decoration: _inputDecoration(theme),
                    hint: const Text('Select Section', style: TextStyle(fontSize: 12)),
                    items: sections.map((sec) {
                      final id = sec['id']?.toString() ?? '';
                      final secName = sec['section_name']?.toString() ?? 'Section';
                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          secName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedOfferingId = val);
                      _checkResumableBatch();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(ThemeData theme) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 1: Single Student Manual Form
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildManualStudentForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Student Name'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: AppTextField(
                    label: 'First Name *',
                    controller: _firstNameCtrl,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    inputFormatters: [
                      ...AppValidators.nameFormatters,
                      LengthLimitingTextInputFormatter(30),
                    ],
                    validator: (v) =>
                        AppValidators.validateName(v, 'First name'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    label: 'Middle Initial',
                    controller: _middleNameCtrl,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z]")),
                      LengthLimitingTextInputFormatter(1),
                    ],
                    validator: (v) {
                      if (v != null && v.trim().length > 1) {
                        return 'Max 1 character';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: AppTextField(
                    label: 'Last Name *',
                    controller: _lastNameCtrl,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    inputFormatters: [
                      ...AppValidators.nameFormatters,
                      LengthLimitingTextInputFormatter(30),
                    ],
                    validator: (v) =>
                        AppValidators.validateName(v, 'Last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionLabel('Student Details'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: AppDatePickerField(
                    label: 'Birthday *',
                    initialDate: _birthday,
                    firstDate: BirthdayValidator.getMinDate('student'),
                    lastDate: BirthdayValidator.getMaxDate('student'),
                    onDateSelected: (d) => setState(() => _birthday = d),
                    validator: (d) => BirthdayValidator.validateBirthday(d, 'student'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _buildGenderField(theme),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: AppTextField(
                    label: 'LRN (12-digit ID) *',
                    controller: _studentIdCtrl,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'LRN is required';
                      if (v.length != 12 || int.tryParse(v) == null) {
                        return 'Must be exactly 12 digits';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: AppTextField(
                    label: 'Email Address *',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: AppValidators.emailFormatters,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: AppValidators.validateEmail,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppSecondaryButton(
                  label: 'Cancel',
                  width: 130,
                  height: 42,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                AppPrimaryButton(
                  label: _isSubmitting ? 'Enrolling...' : 'Enroll Student',
                  icon: LucideIcons.userPlus,
                  width: 160,
                  height: 42,
                  onPressed: _isSubmitting ? null : _submitSingleStudent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
          ),
          hint: const Text('Select Gender', style: TextStyle(fontSize: 13)),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Gender is required' : null,
          items: const [
            DropdownMenuItem(
              value: 'Male',
              child: Row(
                children: [
                  Icon(Icons.male, size: 18, color: Colors.blue),
                  SizedBox(width: 6),
                  Text('Male'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Female',
              child: Row(
                children: [
                  Icon(Icons.female, size: 18, color: Colors.pink),
                  SizedBox(width: 6),
                  Text('Female'),
                ],
              ),
            ),
          ],
          onChanged: (v) => setState(() => _gender = v),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 2: Batch File Import View (Excel / CSV)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBatchImportView(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        children: [
          // ── Resumable Interrupted Session Banner ──
          if (_resumableBatch != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.alertCircle, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upload Paused (Offline Resilience)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Connection lost. Upload paused (${(_resumableBatch!['pending'] as List?)?.length ?? 0} students remaining). Will resume automatically when online.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _discardResumableBatch,
                    child: const Text('Discard', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: const Text('Resume Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _resumeBatchEnrollment,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Step 1: Pre-download Banner Guide (Brand 60-30-10 Compliant) ──
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.fileSpreadsheet, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Official Excel Template',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enter student records starting on Row 3, then upload below.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.download, size: 14),
                  label: const Text('Download .xlsx', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _downloadOfficialTemplate,
                ),
              ],
            ),
          ),

          // ── Step 2 & 3: Animated Marching Ants Drag & Drop / File Click Area ──
          _AnimatedMarchingAntsBox(
            onTap: _isProcessingBatch ? () {} : _processBatchImport,
            isDark: isDark,
            child: _buildMarchingAntsContent(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMarchingAntsContent(ThemeData theme, bool isDark) {
    // State 1: Active Validation Scanning
    if (_isProcessingBatch) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.scanLine,
              size: 34,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _batchFileName ?? 'Validating Spreadsheet...',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_batchFileSize != null) ...[
            const SizedBox(height: 2),
            Text(
              '${(_batchFileSize! / 1024).toStringAsFixed(1)} KB • In Progress',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _batchProgress,
              minHeight: 10,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _batchPhase.isNotEmpty ? _batchPhase : 'Scanning rows...',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(_batchProgress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.userCheck, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _batchActiveRecord.isNotEmpty ? _batchActiveRecord : 'Scanning data rows...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // State 2: File Already Loaded / Scanned
    if (_batchFileName != null) {
      if (_batchWarningMessage != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.triangleAlert,
                size: 34,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _batchWarningTitle ?? 'Spreadsheet Needs Attention',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            Text(
              _batchWarningMessage!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.download, size: 14),
                  label: const Text('Download Template', style: TextStyle(fontSize: 12)),
                  onPressed: _downloadOfficialTemplate,
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.folderOpen, size: 14),
                  label: const Text('Choose Another File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _processBatchImport,
                ),
              ],
            ),
          ],
        );
      }

      final totalEligible = _eligibleNewStudents.length + _eligibleExistingStudents.length;

      // State 2A: Issues Detected
      if (_detectedInvalidRows.isNotEmpty) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertTriangle,
                size: 34,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Spreadsheet Has ${_detectedInvalidRows.length} Issue${_detectedInvalidRows.length > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 6),
            Text(
              'Please correct all detected errors in your spreadsheet and re-upload.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildCardBadge('Issues', _detectedInvalidRows.length, Colors.red),
                _buildCardBadge('New Students', _eligibleNewStudents.length, const Color(0xFF0F8A48)),
                _buildCardBadge('Existing', _eligibleExistingStudents.length, Colors.blue),
                _buildCardBadge('Enrolled', _alreadyEnrolledStudents.length, Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.listChecks, size: 14),
                  label: Text('View Issues (${_detectedInvalidRows.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showIssuesErrorDialog,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Upload Fixed File', style: TextStyle(fontSize: 12)),
                  onPressed: _processBatchImport,
                ),
              ],
            ),
          ],
        );
      }

      // State 2B: All Valid / Enrolled
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F8A48).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.checkCheck,
              size: 34,
              color: Color(0xFF0F8A48),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _batchFileName!,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_batchFileSize != null) ...[
            const SizedBox(height: 2),
            Text(
              '${(_batchFileSize! / 1024).toStringAsFixed(1)} KB • Enrollment Complete',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F8A48).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF0F8A48).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '✓ $totalEligible Student${totalEligible > 1 ? "s" : ""} Enrolled',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F8A48),
                  ),
                ),
              ),
              if (_alreadyEnrolledStudents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '• ${_alreadyEnrolledStudents.length} Already Enrolled (Skipped)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('Upload Another File', style: TextStyle(fontSize: 12)),
            onPressed: _processBatchImport,
          ),
        ],
      );
    }

    // State 3: Idle Default (No file selected yet)
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.uploadCloud,
            size: 36,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Click to upload or drag & drop completed file',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Supports official Excel spreadsheet (.xlsx) up to 10 MB',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(LucideIcons.folderOpen, size: 16),
          label: const Text('Browse Excel File', style: TextStyle(fontWeight: FontWeight.w600)),
          onPressed: _processBatchImport,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.shieldCheck, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Strict Validation: LRN (12 digits) • Email • Name (letters) • M.I. (optional) • Gender • Birthday (Age 10-50)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ParsedStudentRow {
  final int rowNumber;
  final String lrn;
  final String firstName;
  final String middleName;
  final String lastName;
  final String gender;
  final DateTime birthday;
  final String email;
  final bool isExistingGlobalStudent;
  final String? existingStudentId;

  _ParsedStudentRow({
    required this.rowNumber,
    required this.lrn,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.gender,
    required this.birthday,
    required this.email,
    this.isExistingGlobalStudent = false,
    this.existingStudentId,
  });
}

class _InvalidStudentRow {
  final int rowNumber;
  final String fieldTag;
  final String identifier;
  final String reason;

  _InvalidStudentRow({
    required this.rowNumber,
    required this.fieldTag,
    required this.identifier,
    required this.reason,
  });

  String get formattedMessage => 'Row $rowNumber ($fieldTag: $identifier): $reason';
}

class _EnrollmentProgressData {
  final String phase;
  final int currentIdx;
  final int totalCount;
  final String currentStudentName;

  const _EnrollmentProgressData({
    required this.phase,
    required this.currentIdx,
    required this.totalCount,
    required this.currentStudentName,
  });

  double get progress => totalCount <= 0 ? 0.0 : (currentIdx / totalCount).clamp(0.0, 1.0);
  int get percent => (progress * 100).toInt();
}

class _AnimatedMarchingAntsBox extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;
  final Widget child;

  const _AnimatedMarchingAntsBox({
    required this.onTap,
    required this.isDark,
    required this.child,
  });

  @override
  State<_AnimatedMarchingAntsBox> createState() => _AnimatedMarchingAntsBoxState();
}

class _AnimatedMarchingAntsBoxState extends State<_AnimatedMarchingAntsBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool hover) {
    setState(() => _isHovered = hover);
    if (hover) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _isHovered
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.4);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _MarchingAntsPainter(
                strokeColor: borderColor,
                phase: _controller.value * 20.0,
                radius: 14.0,
                strokeWidth: _isHovered ? 2.0 : 1.5,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.isDark
                      ? (_isHovered
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15))
                      : (_isHovered
                          ? theme.colorScheme.primary.withValues(alpha: 0.05)
                          : const Color(0xFFF8FAFC)),
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MarchingAntsPainter extends CustomPainter {
  final Color strokeColor;
  final double phase;
  final double radius;
  final double strokeWidth;

  _MarchingAntsPainter({
    required this.strokeColor,
    required this.phase,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);

    final dashedPath = _createDashedPath(path, 7.0, 5.0, phase);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashLength, double gapLength, double distanceOffset) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = distanceOffset % (dashLength + gapLength);
      while (distance < metric.length) {
        final length = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        dest.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashLength + gapLength;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_MarchingAntsPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
