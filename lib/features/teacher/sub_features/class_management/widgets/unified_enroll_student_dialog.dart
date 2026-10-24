import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/core/utils/validators.dart';

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

  int? get _calculatedAge {
    if (_birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - _birthday!.year;
    if (now.month < _birthday!.month ||
        (now.month == _birthday!.month && now.day < _birthday!.day)) {
      age--;
    }
    return age;
  }

  Widget _buildAgeField(ThemeData theme) {
    final age = _calculatedAge;
    final text = age != null ? '$age yrs old' : 'Auto';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Age',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.calendarCheck,
                size: 15,
                color: age != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: age != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          return;
        }
      }
    } catch (_) {}
    if (_resumableBatch != null && mounted) {
      setState(() => _resumableBatch = null);
    }
  }

  Future<void> _discardResumableBatch() async {
    if (_selectedOfferingId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('batch_enroll_session_$_selectedOfferingId');
    } catch (_) {}
    if (mounted) setState(() => _resumableBatch = null);
  }

  Future<void> _resumeBatchEnrollment() async {
    if (_resumableBatch == null) return;
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

    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso;

    final slashYmd = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$').firstMatch(clean);
    if (slashYmd != null) {
      final y = int.parse(slashYmd.group(1)!);
      final m = int.parse(slashYmd.group(2)!);
      final d = int.parse(slashYmd.group(3)!);
      return DateTime(y, m, d);
    }

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
    if (clean == 'male' || clean == 'm' || clean == 'lalaki') {
      return 'Male';
    }
    if (clean == 'female' || clean == 'f' || clean == 'babae') {
      return 'Female';
    }
    return null;
  }

  String _generateTemplateCsv() {
    final headers = [
      'LRN',
      'Email',
      'Last Name',
      'First Name',
      'Middle Name',
      'Gender',
      'Birthday',
    ];
    final sampleRows = [
      [
        '101234567890',
        'juan.delacruz@example.com',
        'Dela Cruz',
        'Juan',
        'Protacio',
        'Male',
        '2007-06-19',
      ],
      [
        '101234567891',
        'maria.santos@example.com',
        'Santos',
        'Maria',
        'Clara',
        'Female',
        '2007-11-03',
      ],
    ];

    return const ListToCsvConverter().convert([
      headers,
      ...sampleRows,
    ]);
  }

  Future<void> _downloadOfficialTemplate() async {
    try {
      final csvData = _generateTemplateCsv();
      final bytes = utf8.encode(csvData);

      String? selectedPath;

      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          dialogTitle: 'Save Student Enrollment Template',
          fileName: 'classrealm_student_template.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: Uint8List.fromList(bytes),
        );
        selectedPath = 'Downloads / classrealm_student_template.csv';
      } else {
        try {
          selectedPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Student Enrollment Template',
            fileName: 'classrealm_student_template.csv',
            type: FileType.custom,
            allowedExtensions: ['csv'],
            bytes: Uint8List.fromList(bytes),
          );
        } catch (_) {
          selectedPath = null;
        }

        if (selectedPath != null && selectedPath.isNotEmpty) {
          final file = File(selectedPath);
          await file.writeAsString(csvData);
        } else {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            final downloadsDir = Directory('$userProfile\\Downloads');
            if (downloadsDir.existsSync()) {
              final target = File('${downloadsDir.path}\\classrealm_student_template.csv');
              await target.writeAsString(csvData);
              selectedPath = target.path;
            }
          }
        }
      }

      if (!mounted) return;

      if (selectedPath != null && selectedPath.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F8A48).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.fileSpreadsheet, color: Color(0xFF0F8A48), size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Template Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kIsWeb
                      ? 'The official Student Enrollment Template has been downloaded to your browser\'s Downloads:'
                      : 'The official Student Enrollment Template has been saved successfully:',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SelectableText(
                    selectedPath!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Required Columns in Template:\n'
                  '• LRN: 12-digit DepEd Student Learner Reference Number\n'
                  '• First Name & Last Name (at least 2 letters)\n'
                  '• Middle Name (optional)\n'
                  '• Gender: Male or Female\n'
                  '• Birthday: YYYY-MM-DD (e.g., 2007-06-19)\n'
                  '• Email: valid student email address',
                  style: TextStyle(fontSize: 12, height: 1.45),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F8A48)),
                child: const Text('OK'),
              ),
            ],
          ),
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
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.single;
      final ext = (pickedFile.extension ?? '').toLowerCase();

      // Format validation: CSV and Excel only
      if (ext != 'csv' && ext != 'xlsx' && ext != 'xls') {
        throw Exception(
          'Unsupported file format (.${pickedFile.extension}). Please upload a valid CSV or Excel spreadsheet (.csv, .xlsx).'
        );
      }

      // File size validation: max 5 MB
      const maxBytes = 5 * 1024 * 1024;
      if (pickedFile.size > maxBytes) {
        final mb = (pickedFile.size / (1024 * 1024)).toStringAsFixed(1);
        throw Exception(
          'The selected file is $mb MB, which exceeds the 5 MB maximum limit. Please ensure your file is within 5 MB.'
        );
      }

      final Uint8List fileBytes;
      if (pickedFile.bytes != null) {
        fileBytes = pickedFile.bytes!;
      } else if (!kIsWeb && pickedFile.path != null) {
        final file = File(pickedFile.path!);
        fileBytes = await file.readAsBytes();
      } else {
        throw Exception('Unable to read selected file contents.');
      }

      final List<List<dynamic>> rows;
      if (ext == 'csv') {
        final csvString = utf8.decode(fileBytes);
        rows = const CsvToListConverter(shouldParseNumbers: false).convert(csvString);
      } else if (ext == 'xlsx') {
        rows = _parseXlsxBytes(fileBytes);
      } else {
        throw Exception('Excel 97-2003 (.xls) format is deprecated. Please save your file as modern Excel (.xlsx) or CSV (.csv).');
      }

      if (rows.isEmpty || rows.length <= 1) {
        throw Exception('The spreadsheet file is empty or does not contain any student rows.');
      }

      final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final lrnIndex = header.indexWhere((h) => h == 'lrn' || h.contains('lrn') || h.contains('student id'));
      final emailIndex = header.indexWhere((h) => h == 'email' || h.contains('email'));
      final lastNameIndex = header.indexWhere((h) => h == 'last name' || h == 'lastname' || h == 'last_name' || h == 'surname');
      final firstNameIndex = header.indexWhere((h) => h == 'first name' || h == 'firstname' || h == 'first_name');
      final middleNameIndex = header.indexWhere((h) => h == 'middle name' || h == 'middlename' || h == 'middle_name');
      final genderIndex = header.indexWhere((h) => h == 'gender' || h == 'sex');
      final birthdayIndex = header.indexWhere((h) => h == 'birthday' || h == 'birthdate' || h == 'birth date' || h == 'dob');

      final missingHeaders = <String>[];
      if (lrnIndex == -1) missingHeaders.add('LRN');
      if (emailIndex == -1) missingHeaders.add('Email');
      if (lastNameIndex == -1) missingHeaders.add('Last Name');
      if (firstNameIndex == -1) missingHeaders.add('First Name');
      if (genderIndex == -1) missingHeaders.add('Gender');
      if (birthdayIndex == -1) missingHeaders.add('Birthday');

      if (missingHeaders.isNotEmpty) {
        throw Exception(
          'Missing required column headers: ${missingHeaders.join(', ')}.\n\n'
          'Please ensure your file has: LRN, Email, Last Name, First Name, Gender, and Birthday. '
          'Use "Download Official Template" to see the correct format.',
        );
      }

      final validStudents = <_ParsedStudentRow>[];
      final duplicateLrnsInFile = <String>[];
      final invalidRows = <_InvalidStudentRow>[];
      final seenLrns = <String>{};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
          continue;
        }

        final rowNum = i + 1;
        final rawLrn = (lrnIndex < row.length ? row[lrnIndex] : '').toString().trim();
        final rawFirst = (firstNameIndex < row.length ? row[firstNameIndex] : '').toString().trim();
        final rawMiddle = (middleNameIndex != -1 && middleNameIndex < row.length ? row[middleNameIndex] : '').toString().trim();
        final rawLast = (lastNameIndex < row.length ? row[lastNameIndex] : '').toString().trim();
        final rawGender = (genderIndex < row.length ? row[genderIndex] : '').toString().trim();
        final rawBday = (birthdayIndex < row.length ? row[birthdayIndex] : '').toString().trim();
        final rawEmail = (emailIndex < row.length ? row[emailIndex] : '').toString().trim().toLowerCase();

        final cleanLrn = rawLrn.replaceAll(RegExp(r'\D'), '');
        final studentLabel = rawFirst.isNotEmpty ? '$rawFirst $rawLast' : (rawLrn.isNotEmpty ? 'LRN $rawLrn' : 'Row $rowNum');

        if (cleanLrn.length != 12) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            identifier: studentLabel,
            reason: 'LRN must be exactly 12 digits (found: "${rawLrn.isEmpty ? "empty" : rawLrn}")',
          ));
          continue;
        }

        if (seenLrns.contains(cleanLrn)) {
          duplicateLrnsInFile.add(cleanLrn);
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            identifier: '$studentLabel (LRN $cleanLrn)',
            reason: 'Duplicate LRN in this import file',
          ));
          continue;
        }

        if (rawFirst.length < 2) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            identifier: cleanLrn,
            reason: 'First name must be at least 2 characters',
          ));
          continue;
        }

        if (rawLast.length < 2) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            identifier: '$rawFirst (LRN $cleanLrn)',
            reason: 'Last name must be at least 2 characters',
          ));
          continue;
        }

        final parsedGender = _parseGender(rawGender);
        if (parsedGender == null) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            identifier: studentLabel,
            reason: 'Gender must be "Male" or "Female" (found: "$rawGender")',
          ));
          continue;
        }

        final parsedBday = _parseBirthday(rawBday);
        if (parsedBday == null) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            identifier: studentLabel,
            reason: 'Invalid birthday format. Use YYYY-MM-DD (found: "$rawBday")',
          ));
          continue;
        }

        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(rawEmail)) {
          invalidRows.add(_InvalidStudentRow(
            rowNumber: rowNum,
            identifier: studentLabel,
            reason: 'Invalid email address ("$rawEmail")',
          ));
          continue;
        }

        seenLrns.add(cleanLrn);
        validStudents.add(_ParsedStudentRow(
          rowNumber: rowNum,
          lrn: cleanLrn,
          firstName: rawFirst,
          middleName: rawMiddle,
          lastName: rawLast,
          gender: parsedGender,
          birthday: parsedBday,
          email: rawEmail,
        ));
      }

      if (!mounted) return;

      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.listChecks, color: Colors.blue),
              const SizedBox(width: 10),
              const Text('Import Pre-Flight Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.graduationCap, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
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
                Row(
                  children: [
                    _buildStatPill('Valid Students', validStudents.length, const Color(0xFF0F8A48)),
                    const SizedBox(width: 8),
                    _buildStatPill('Duplicates', duplicateLrnsInFile.length, Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatPill('Invalid Rows', invalidRows.length, Colors.red),
                  ],
                ),
                if (invalidRows.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Issues Detected:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: invalidRows.length,
                      itemBuilder: (_, idx) {
                        final item = invalidRows[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• Row ${item.rowNumber} (${item.identifier}): ${item.reason}',
                            style: const TextStyle(fontSize: 11, color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  validStudents.isNotEmpty
                      ? 'Do you want to proceed and enroll the ${validStudents.length} valid students now?'
                      : 'No valid students found to enroll. Please check the issues above.',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            if (validStudents.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Enroll ${validStudents.length} Students'),
              ),
          ],
        ),
      );

      if (shouldProceed != true || !mounted) return;

      await _executeBatchEnrollment(
        validStudents,
        fileName: pickedFile.name,
      );
    } catch (e) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Import Error',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  List<List<dynamic>> _parseXlsxBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStrings = <String>[];
      final ssFile = archive.findFile('xl/sharedStrings.xml');
      if (ssFile != null) {
        final ssXml = utf8.decode(ssFile.content as List<int>);
        final tMatches = RegExp(r'<t(?:\s[^>]*)?>([^<]*)<\/t>').allMatches(ssXml);
        for (final m in tMatches) {
          sharedStrings.add(m.group(1) ?? '');
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
      final rowMatches = RegExp(r'<row[^>]*>(.*?)<\/row>').allMatches(sheetXml);

      final allRows = <List<dynamic>>[];
      for (final rm in rowMatches) {
        final rowXml = rm.group(1) ?? '';
        final cellMatches = RegExp(r'<c\s+r="([A-Z]+)(\d+)"(?:\s+t="([a-z]+)")?[^>]*>(?:<v>([^<]*)<\/v>)?<\/c>').allMatches(rowXml);

        final rowData = <dynamic>[];
        for (final cm in cellMatches) {
          final type = cm.group(3);
          final rawVal = cm.group(4) ?? '';
          if (type == 's' && int.tryParse(rawVal) != null) {
            final sIdx = int.parse(rawVal);
            rowData.add(sIdx < sharedStrings.length ? sharedStrings[sIdx] : rawVal);
          } else {
            rowData.add(rawVal);
          }
        }
        if (rowData.isNotEmpty) {
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

  Future<void> _executeBatchEnrollment(
    List<_ParsedStudentRow> students, {
    bool isResumed = false,
    String fileName = 'Spreadsheet',
  }) async {
    final repo = SupabaseStudentRepository();
    final successful = <_ParsedStudentRow>[];
    final failed = <Map<String, dynamic>>[];

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
      }).toList();

      await prefs.setString(sessionKey, jsonEncode({
        'fileName': fileName,
        'offeringId': _selectedOfferingId,
        'total': students.length,
        'pending': pendingJson,
      }));
    } catch (_) {}

    int currentIdx = 0;
    String currentStudentName = '';
    late StateSetter setProgressState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            setProgressState = setState;
            final progress = students.isEmpty ? 0.0 : (currentIdx / students.length);
            final percent = (progress * 100).toInt();
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
                          'Student $currentIdx of ${students.length}',
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
                      currentStudentName.isNotEmpty ? currentStudentName : 'Preparing student accounts...',
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
        );
      },
    );

    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      if (mounted) {
        setProgressState(() {
          currentIdx = i + 1;
          currentStudentName = '${s.firstName} ${s.lastName} (LRN: ${s.lrn})';
        });
      }

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
        );
        if (result.studentId.isNotEmpty) successful.add(s);
      } catch (e) {
        failed.add({
          'student': s,
          'error': e.toString().replaceAll('Exception: ', '').trim(),
        });
      }

      // Update persisted pending batch
      if (prefs != null && sessionKey != null) {
        pendingJson.removeWhere((item) => item['lrn'] == s.lrn);
        if (pendingJson.isNotEmpty) {
          await prefs.setString(sessionKey, jsonEncode({
            'fileName': fileName,
            'offeringId': _selectedOfferingId,
            'total': students.length,
            'pending': pendingJson,
          }));
        }
      }
    }

    if (prefs != null && sessionKey != null) {
      await prefs.remove(sessionKey);
      if (mounted) setState(() => _resumableBatch = null);
    }

    if (mounted) {
      Navigator.of(context).pop(); // dismiss progress dialog
      Navigator.of(context).pop(); // dismiss unified dialog
      widget.onStudentCreated(); // refresh dashboard roster

      _showBatchResultDialog(successful: successful, failed: failed);
    }
  }

  void _showBatchResultDialog({
    required List<_ParsedStudentRow> successful,
    required List<Map<String, dynamic>> failed,
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
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatPill('Enrolled', successful.length, const Color(0xFF0F8A48)),
                  const SizedBox(width: 10),
                  _buildStatPill('Failed / Skipped', failed.length, failed.isEmpty ? Colors.grey : Colors.red),
                ],
              ),
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Students Not Enrolled:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '• ${s.firstName} ${s.lastName} (${s.lrn}): $err',
                          style: const TextStyle(fontSize: 12, color: Colors.red),
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
                            Text('Import File (CSV/Excel)'),
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
                    label: 'Middle Name',
                    controller: _middleNameCtrl,
                    inputFormatters: [
                      ...AppValidators.nameFormatters,
                      LengthLimitingTextInputFormatter(30),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: AppTextField(
                    label: 'Last Name *',
                    controller: _lastNameCtrl,
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
                  flex: 3,
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
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 12 || int.tryParse(v) == null) {
                        return 'Invalid length';
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
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                AppPrimaryButton(
                  label: _isSubmitting ? 'Enrolling...' : 'Enroll Student',
                  icon: LucideIcons.userPlus,
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
                          'Interrupted Session Found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_resumableBatch!['pendingCount']} student(s) from "${_resumableBatch!['fileName']}" were not finished.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
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
                    icon: const Icon(LucideIcons.play, size: 14),
                    label: const Text('Resume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _resumeBatchEnrollment,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Animated Marching Ants Drag & Drop / File Click Area ──
          _AnimatedMarchingAntsBox(
            onTap: _processBatchImport,
            isDark: isDark,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.fileSpreadsheet,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Click to upload or drag & drop Excel / CSV file',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Supports Excel (.xlsx) and standard CSV (.csv) files up to 5 MB',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
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
                      const Icon(LucideIcons.info, size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Required: LRN • Email • Last Name • First Name • Gender • Birthday (YYYY-MM-DD)',
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
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.lightbulb, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Click "Download Official Template" below to get the pre-formatted Excel or CSV template. Keep the column headers unchanged when entering student details.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: const Color(0xFF0F8A48).withValues(alpha: 0.6),
                  ),
                  foregroundColor: const Color(0xFF0F8A48),
                ),
                icon: const Icon(LucideIcons.download, size: 16),
                label: const Text('Download Official Template (Excel / CSV)'),
                onPressed: _downloadOfficialTemplate,
              ),
              Text(
                'Max file size: 5 MB',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
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

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;

  const _CredentialRow({
    required this.label,
    required this.value,
  }) : isCode = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCode
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCode
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: SelectableText(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: isCode ? 'monospace' : null,
                  letterSpacing: isCode ? 1.0 : null,
                  color: isCode
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
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

  _ParsedStudentRow({
    required this.rowNumber,
    required this.lrn,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.gender,
    required this.birthday,
    required this.email,
  });
}

class _InvalidStudentRow {
  final int rowNumber;
  final String identifier;
  final String reason;

  _InvalidStudentRow({
    required this.rowNumber,
    required this.identifier,
    required this.reason,
  });
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

