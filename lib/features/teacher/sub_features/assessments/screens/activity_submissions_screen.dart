import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';

class ActivitySubmissionsScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool embedded;
  final VoidCallback? onBack;
  final SupabaseClient? supabaseClient;

  const ActivitySubmissionsScreen({
    super.key,
    required this.activity,
    this.embedded = false,
    this.onBack,
    this.supabaseClient,
  });

  static Future<void> show(BuildContext context, ActivityModel activity) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivitySubmissionsScreen(activity: activity),
      ),
    );
  }

  @override
  State<ActivitySubmissionsScreen> createState() =>
      _ActivitySubmissionsScreenState();
}

class _ActivitySubmissionsScreenState extends State<ActivitySubmissionsScreen> {
  late ActivityModel _activity;
  late DateTime _currentDeadline;

  bool _isLoading = true;
  String _selectedStatus = 'All';
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 15;

  bool _isInstructionsExpanded = false;
  final ScrollController _instructionsScrollController = ScrollController();

  List<UserModel> _enrolledStudents = [];
  Map<String, Map<String, dynamic>> _submissionsByStudent = {};
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, bool> _isSavingStudent = {};
  final Map<String, String?> _scoreErrors = {};

  SupabaseClient get _client =>
      widget.supabaseClient ?? Supabase.instance.client;

  bool get _isInPerson => _activity.completionMode == 'in_person';

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _currentDeadline = widget.activity.deadline;
    _loadData();
  }

  @override
  void dispose() {
    _instructionsScrollController.dispose();
    for (final ctrl in _scoreControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _formatStudentName(UserModel s) {
    final last = s.lastName?.trim() ?? '';
    final first = s.firstName?.trim() ?? '';
    final mid = s.middleName?.trim() ?? '';

    if (last.isNotEmpty && first.isNotEmpty) {
      final mi = mid.isNotEmpty ? ' ${AppValidators.formatMiddleInitial(mid)}' : '';
      return '$last, $first$mi';
    }

    final full = s.fullName.trim();
    if (full.contains(',')) return full;

    final parts = full.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final parsedLast = parts.last;
      final parsedFirstMid = parts.sublist(0, parts.length - 1).join(' ');
      return '$parsedLast, $parsedFirstMid';
    }
    return full;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final teacher = AuthRepository.instance.currentUser;
    if (teacher == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Re-hydrate activity details to ensure attachment and instructions are always fresh
      try {
        final freshRow = await _client
            .from('classwork_items')
            .select()
            .eq('id', _activity.id)
            .maybeSingle();
        if (freshRow != null) {
          _activity = _activity.copyWith(
            title: freshRow['title']?.toString(),
            instructions: freshRow['instructions']?.toString(),
            storagePath: freshRow['storage_path']?.toString(),
            attachmentName: freshRow['file_name']?.toString() ??
                freshRow['attachment_name']?.toString(),
            mimeType: freshRow['mime_type']?.toString(),
            fileSizeBytes: (freshRow['file_size_bytes'] as num?)?.toInt(),
          );
        }
      } catch (err) {
        debugPrint('Notice refreshing activity details in submissions: $err');
      }

      // 1. Load enrolled students for this offering
      final studentRepo = SupabaseStudentRepository();
      final students = await studentRepo.getStudentsForTeacher(
        teacher.id,
        subjectId: _activity.subjectOfferingId,
      );

      final filtered =
          students.where((u) {
            if (u.role != UserRole.student || u.isArchived) return false;
            if (_activity.section.isNotEmpty &&
                _activity.section != 'All Sections' &&
                u.departmentOrSection != null &&
                u.departmentOrSection!.isNotEmpty &&
                u.departmentOrSection != _activity.section) {
              return false;
            }
            return true;
          }).toList()..sort((a, b) {
            final nameA = _formatStudentName(a);
            final nameB = _formatStudentName(b);
            return nameA.toLowerCase().compareTo(nameB.toLowerCase());
          });

      // 2. Load submissions from student_classwork_submissions with attachments
      List<dynamic> submissionRows = [];
      try {
        final res = await _client
            .from('student_classwork_submissions')
            .select('''
              *,
              submission_attachments (
                file_name,
                storage_url,
                mime_type,
                file_size_bytes
              )
            ''')
            .eq('classwork_id', _activity.id);
        submissionRows = res as List? ?? [];
      } catch (e) {
        debugPrint('Notice join on submission_attachments: $e');
        try {
          final res = await _client
              .from('student_classwork_submissions')
              .select()
              .eq('classwork_id', _activity.id);
          submissionRows = res as List? ?? [];
        } catch (_) {}
      }

      // Populate attachments reliably from submission_attachments table
      final subIds = submissionRows
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toList();
      if (subIds.isNotEmpty) {
        try {
          final attRes = await SupabaseService().adminClient
              .from('submission_attachments')
              .select('submission_id, file_name, storage_url, mime_type, file_size_bytes')
              .inFilter('submission_id', subIds);
          final attList = attRes as List? ?? [];
          final attBySubId = <String, Map<String, dynamic>>{};
          for (final a in attList) {
            final m = Map<String, dynamic>.from(a as Map);
            final sId = m['submission_id']?.toString();
            if (sId != null && !attBySubId.containsKey(sId)) {
              attBySubId[sId] = m;
            }
          }
          for (final row in submissionRows) {
            final sId = row['id']?.toString();
            if (sId != null && attBySubId.containsKey(sId)) {
              final att = attBySubId[sId]!;
              row['storage_path'] = att['storage_url'] ?? row['storage_path'];
              row['file_name'] = att['file_name'] ?? row['file_name'];
            }
          }
        } catch (attErr) {
          debugPrint('Notice querying submission_attachments directly: $attErr');
        }
      }

      final subMap = <String, Map<String, dynamic>>{};
      for (final row in submissionRows) {
        final item = Map<String, dynamic>.from(row as Map);
        final studentId = item['student_id']?.toString();
        if (studentId != null) {
          final attachments = item['submission_attachments'] as List? ?? [];
          if (attachments.isNotEmpty) {
            final att = Map<String, dynamic>.from(attachments.first as Map);
            item['storage_path'] = att['storage_url'] ?? item['storage_path'];
            item['file_name'] = att['file_name'] ?? item['file_name'];
          }
          subMap[studentId] = item;
        }
      }

      // 3. Check Gradebook Term Sheet fallback for two-way sync
      if (_activity.subjectOfferingId != null &&
          _activity.gradebookColumnIndex != null) {
        try {
          final termSheet = await SubjectRepository.instance
              .getGradebookTermSheet(
                _activity.subjectOfferingId!,
                _activity.termNumber,
              );
          if (termSheet != null) {
            final scores = Map<String, dynamic>.from(
              termSheet['scores'] as Map? ?? {},
            );
            final catKey = _activity.effectiveGradingCategory;
            final colKey = catKey == 'ex'
                ? (_activity.gradebookColumnIndex == 1
                      ? 'st1'
                      : (_activity.gradebookColumnIndex == 2 ? 'st2' : 'te'))
                : _activity.gradebookColumnIndex.toString();

            for (final student in filtered) {
              final studentScores = scores[student.id];
              if (studentScores is Map && studentScores.containsKey(catKey)) {
                final catScores = studentScores[catKey];
                if (catScores is Map && catScores.containsKey(colKey)) {
                  final gbScore = catScores[colKey];
                  if (gbScore != null && gbScore is num) {
                    final existing =
                        subMap[student.id] ??
                        <String, dynamic>{
                          'classwork_id': _activity.id,
                          'student_id': student.id,
                          'status': 'graded',
                        };
                    existing['score'] = gbScore.toDouble();
                    if (existing['status'] == null ||
                        existing['status'] == 'pending') {
                      existing['status'] = 'graded';
                    }
                    subMap[student.id] = existing;
                  }
                }
              }
            }
          }
        } catch (gbErr) {
          debugPrint('Gradebook sheet fallback notice: $gbErr');
        }
      }

      // Initialize score text controllers
      for (final s in filtered) {
        final sub = subMap[s.id];
        final score = sub?['score'];
        final scoreText = score != null
            ? (score is num && score == score.roundToDouble()
                  ? score.toInt().toString()
                  : score.toString())
            : '';
        _scoreControllers
                .putIfAbsent(s.id, () => TextEditingController())
                .text =
            scoreText;
      }

      if (mounted) {
        setState(() {
          _enrolledStudents = filtered;
          _submissionsByStudent = subMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading submissions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  
  bool _isOpeningFile = false;

  Future<String> _sanitizeAndSignClassworkUrl(String rawPath) async {
    var cleanPath = rawPath.trim();
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      if (cleanPath.contains('token=') || cleanPath.contains('Signature=')) {
        return cleanPath;
      }
    }
    if (cleanPath.contains('/classwork-materials/')) {
      cleanPath = cleanPath.split('/classwork-materials/').last;
    } else if (cleanPath.contains('/classwork%20materials/')) {
      cleanPath = cleanPath.split('/classwork%20materials/').last;
    } else if (cleanPath.contains('/learning_materials/')) {
      cleanPath = cleanPath.split('/learning_materials/').last;
    }
    if (cleanPath.contains('?')) {
      cleanPath = cleanPath.split('?').first;
    }
    cleanPath = Uri.decodeComponent(cleanPath);
    try {
      return await SupabaseService().adminClient.storage
          .from('classwork-materials')
          .createSignedUrl(cleanPath, 60 * 60);
    } catch (_) {
      // Bucket classwork-materials is public, fallback to public URL
      return Supabase.instance.client.storage
          .from('classwork-materials')
          .getPublicUrl(cleanPath);
    }
  }

  Future<void> _openStudentFile(Map<String, dynamic>? submission) async {
    if (_isOpeningFile) return;
    final path = submission?['storage_path']?.toString();
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission file is not available.')),
        );
      }
      return;
    }

    _isOpeningFile = true;
    try {
      final url = await _sanitizeAndSignClassworkUrl(path); // 1 hour expiry
      final lower = path.toLowerCase();
      final isOfficeDoc = lower.endsWith('.doc') || lower.endsWith('.docx');
      Uri launchUri = Uri.parse(url);
      if (kIsWeb && isOfficeDoc) {
        // In Web browsers, doc/docx cannot be natively viewed without downloading.
        // Google Docs Viewer renders it inline in a new tab without downloading.
        launchUri = Uri.parse(
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true',
        );
      }

      bool launched = false;
      if (kIsWeb) {
        launched = await launchUrl(launchUri, webOnlyWindowName: '_blank');
      } else {
        // Native App (Android / iOS):
        // 1. Try launching in external application (e.g. Word, Drive, Acrobat Reader)
        try {
          launched = await launchUrl(
            launchUri,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}

        // 2. Fallback: If no app is installed or handler fails, open via in-app browser overlay
        if (!launched) {
          try {
            final inAppUri = isOfficeDoc
                ? Uri.parse(
                    'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true',
                  )
                : launchUri;
            launched = await launchUrl(inAppUri, mode: LaunchMode.inAppBrowserView);
          } catch (_) {}
        }

        // 3. Last-resort fallback to platform default
        if (!launched) {
          launched = await launchUrl(launchUri, mode: LaunchMode.platformDefault);
        }
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open document.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        final errStr = e.toString().toLowerCase();
        final isNotFound = errStr.contains('404') ||
            errStr.contains('not_found') ||
            errStr.contains('object not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNotFound
                  ? 'The submission file was not found in cloud storage. The student may need to re-submit.'
                  : 'Unable to open file: $e',
            ),
          ),
        );
      }
    } finally {
      _isOpeningFile = false;
    }
  }

  Future<void> _openTeacherAttachment() async {
    if (_isOpeningFile) return;
    final path = _activity.storagePath;
    if (path == null || path.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attached file available.')),
        );
      }
      return;
    }

    _isOpeningFile = true;
    try {
      final url = await _sanitizeAndSignClassworkUrl(path); // 1 hour expiry
      final lower = path.toLowerCase();
      final isOfficeDoc = lower.endsWith('.doc') || lower.endsWith('.docx');
      Uri launchUri = Uri.parse(url);
      if (kIsWeb && isOfficeDoc) {
        // In Web browsers, doc/docx cannot be natively viewed without downloading.
        // Google Docs Viewer renders it inline in a new tab without downloading.
        launchUri = Uri.parse(
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true',
        );
      }

      bool launched = false;
      if (kIsWeb) {
        launched = await launchUrl(launchUri, webOnlyWindowName: '_blank');
      } else {
        // Native App (Android / iOS):
        // 1. Try launching in external application (e.g. Word, Drive, Acrobat Reader)
        try {
          launched = await launchUrl(
            launchUri,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}

        // 2. Fallback: If no app is installed or handler fails, open via in-app browser overlay
        if (!launched) {
          try {
            final inAppUri = isOfficeDoc
                ? Uri.parse(
                    'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true',
                  )
                : launchUri;
            launched = await launchUrl(inAppUri, mode: LaunchMode.inAppBrowserView);
          } catch (_) {}
        }

        // 3. Last-resort fallback to platform default
        if (!launched) {
          launched = await launchUrl(launchUri, mode: LaunchMode.platformDefault);
        }
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open attached material.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        final errStr = e.toString().toLowerCase();
        final isNotFound = errStr.contains('404') ||
            errStr.contains('not_found') ||
            errStr.contains('object not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNotFound
                  ? 'The attached file is no longer available in cloud storage. Please re-upload it.'
                  : 'Unable to open material: $e',
            ),
          ),
        );
      }
    } finally {
      _isOpeningFile = false;
    }
  }

  Future<bool> _saveScore(
    UserModel student,
    String scoreStr, {
    String? feedback,
  }) async {
    final cleanStr = scoreStr.trim();
    final validationError = AppValidators.validateClassworkStudentScore(
      cleanStr,
      maxScore: _activity.maxScore,
    );
    if (validationError != null) {
      if (mounted) {
        setState(() => _scoreErrors[student.id] = validationError);
      }
      return false;
    }

    final double? newScore = cleanStr.isNotEmpty
        ? double.tryParse(cleanStr)
        : null;

    setState(() {
      _scoreErrors.remove(student.id);
      _isSavingStudent[student.id] = true;
    });

    try {
      // Check if item still exists in database
      final existingItem = await _client
          .from('classwork_items')
          .select('id')
          .eq('id', _activity.id)
          .maybeSingle();

      if (existingItem == null) {
        setState(() => _isSavingStudent[student.id] = false);
        if (mounted) {
          AppModals.showWarningDialog(
            context: context,
            title: 'Classwork Removed',
            message:
                'This classwork item has already been deleted in the database. Scores can no longer be recorded.',
          );
        }
        return false;
      }

      final currentSub =
          _submissionsByStudent[student.id] ?? <String, dynamic>{};
      final newStatus = newScore != null
          ? 'graded'
          : (_isInPerson
                ? ((currentSub['submitted_at'] != null ||
                        currentSub['status'] == 'submitted')
                    ? 'submitted'
                    : 'pending')
                : (currentSub['status'] ?? 'submitted'));

      // 1. Upsert to student_classwork_submissions
      final upsertData = <String, dynamic>{
        'classwork_id': _activity.id,
        'student_id': student.id,
        'score': newScore,
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (feedback != null) {
        upsertData['feedback'] = feedback.trim().isNotEmpty
            ? feedback.trim()
            : null;
      }
      if (newStatus == 'pending') {
        upsertData['submitted_at'] = null;
      } else if (currentSub['submitted_at'] != null) {
        upsertData['submitted_at'] = currentSub['submitted_at'];
      } else {
        upsertData['submitted_at'] = DateTime.now().toUtc().toIso8601String();
      }

      await _client
          .from('student_classwork_submissions')
          .upsert(upsertData, onConflict: 'classwork_id,student_id');

      // 2. Synchronize to Gradebook Term Sheet
      if (_activity.subjectOfferingId != null &&
          _activity.gradebookColumnIndex != null) {
        try {
          final termSheet =
              await SubjectRepository.instance.getGradebookTermSheet(
                _activity.subjectOfferingId!,
                _activity.termNumber,
              ) ??
              {};
          final scores = Map<String, dynamic>.from(
            termSheet['scores'] as Map? ?? {},
          );
          final studentScores = Map<String, dynamic>.from(
            scores[student.id] as Map? ?? {},
          );
          final catKey = _activity.effectiveGradingCategory;
          final catScores = Map<String, dynamic>.from(
            studentScores[catKey] as Map? ?? {},
          );
          final colKey = catKey == 'ex'
              ? (_activity.gradebookColumnIndex == 1
                    ? 'st1'
                    : (_activity.gradebookColumnIndex == 2 ? 'st2' : 'te'))
              : _activity.gradebookColumnIndex.toString();

          final hps = Map<String, dynamic>.from(termSheet['hps'] as Map? ?? {});
          final catHps = Map<String, dynamic>.from(hps[catKey] as Map? ?? {});
          catHps[colKey] = _activity.maxScore.toInt();
          if (catKey == 'ex') {
            catHps.remove(_activity.gradebookColumnIndex.toString());
          }
          hps[catKey] = catHps;
          termSheet['hps'] = hps;

          if (newScore != null) {
            catScores[colKey] = newScore;
            if (catKey == 'ex') {
              catScores.remove(_activity.gradebookColumnIndex.toString());
            }
          } else {
            catScores.remove(colKey);
            if (catKey == 'ex') {
              catScores.remove(_activity.gradebookColumnIndex.toString());
            }
          }
          studentScores[catKey] = catScores;
          scores[student.id] = studentScores;
          termSheet['scores'] = scores;

          await SubjectRepository.instance.saveGradebookTermSheet(
            _activity.subjectOfferingId!,
            _activity.termNumber,
            termSheet,
          );
          TeacherGradebookTab.gradebookRefreshNotifier.value++;
        } catch (gbSyncErr) {
          debugPrint('Gradebook term sheet sync notice: $gbSyncErr');
        }
      }

      AppDataCache.instance.invalidatePrefix('student_dashboard_');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('gradebook_');

      // 3. Update local state
      setState(() {
        final updated = Map<String, dynamic>.from(currentSub);
        updated['score'] = newScore;
        updated['status'] = newStatus;
        if (feedback != null) updated['feedback'] = feedback;
        _submissionsByStudent[student.id] = updated;
        _isSavingStudent[student.id] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newScore != null
                  ? 'Score saved for ${student.fullName}: ${newScore == newScore.roundToDouble() ? newScore.toInt() : newScore} / ${_activity.maxScore.toInt()} pts'
                  : 'Score cleared for ${student.fullName}.',
            ),
            backgroundColor: const Color(0xFF0F8A48),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingStudent[student.id] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save score: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _updateInPersonStatus(UserModel student, String status) async {
    setState(() => _isSavingStudent[student.id] = true);
    try {
      // Check if item still exists in database
      final existingItem = await _client
          .from('classwork_items')
          .select('id')
          .eq('id', _activity.id)
          .maybeSingle();

      if (existingItem == null) {
        setState(() => _isSavingStudent[student.id] = false);
        if (mounted) {
          AppModals.showWarningDialog(
            context: context,
            title: 'Classwork Removed',
            message:
                'This classwork item has already been deleted in the database. Scores can no longer be recorded.',
          );
        }
        return;
      }

      final dbStatus =
          status.toLowerCase() == 'missing' ? 'pending' : 'submitted';
      final currentSub =
          _submissionsByStudent[student.id] ?? <String, dynamic>{};
      final upsertData = <String, dynamic>{
        'classwork_id': _activity.id,
        'student_id': student.id,
        'status': dbStatus,
        'score': currentSub['score'],
        'submitted_at': dbStatus == 'submitted'
            ? (currentSub['submitted_at'] ??
                DateTime.now().toUtc().toIso8601String())
            : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _client
          .from('student_classwork_submissions')
          .upsert(upsertData, onConflict: 'classwork_id,student_id');

      setState(() {
        final updated = Map<String, dynamic>.from(currentSub);
        updated['status'] = dbStatus;
        if (dbStatus == 'submitted') {
          updated['submitted_at'] = upsertData['submitted_at'];
        } else {
          updated.remove('submitted_at');
        }
        _submissionsByStudent[student.id] = updated;
        _isSavingStudent[student.id] = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingStudent[student.id] = false);
      }
    }
  }

  Future<void> _showUpdateDeadlineDialog() async {
    final localDl = _currentDeadline.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime selectedDate = DateTime(localDl.year, localDl.month, localDl.day);
    if (!_isInPerson && selectedDate.isBefore(today)) {
      selectedDate = today;
    }
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(localDl);
    bool isSavingDeadline = false;

    String? computeTimeError(DateTime date, TimeOfDay time) {
      if (_isInPerson) return null;
      final candidate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!candidate.isAfter(DateTime.now())) {
        return 'Updated deadline must be in the future.';
      }
      return null;
    }

    String? deadlineTimeError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final candidateCombined = _isInPerson
              ? DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  23,
                  59,
                )
              : DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
          final isUnchanged = isSameClassworkSchedule(
            _currentDeadline,
            candidateCombined,
            isInPerson: _isInPerson,
          );
          final isSelectedToday =
              selectedDate.year == today.year &&
              selectedDate.month == today.month &&
              selectedDate.day == today.day;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_repeat,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isInPerson ? 'Update Date' : 'Update Deadline',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isInPerson
                        ? 'Update the scheduled date for "${_activity.title}".'
                        : 'Set a new submission deadline for "${_activity.title}". Extending the deadline dynamically re-opens submission for all enrolled students.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8A48).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0F8A48).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: Color(0xFF0F8A48),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isInPerson
                                ? 'Current Date: ${_formatDateOnly(_currentDeadline)}'
                                : 'Current Deadline: ${_formatDateTime(_currentDeadline)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F8A48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isInPerson ? 'Update Date *' : 'Update Deadline Date *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isSavingDeadline
                        ? null
                        : () async {
                            final tNow = DateTime.now();
                            final tToday = DateTime(
                              tNow.year,
                              tNow.month,
                              tNow.day,
                            );
                            final pickedDate = await showAppDatePickerDialog(
                              ctx,
                              initialDate: selectedDate,
                              firstDate: _isInPerson
                                  ? DateTime(tToday.year - 1, 1, 1)
                                  : tToday,
                              lastDate: DateTime(tToday.year + 5, 12, 31),
                              title: _isInPerson
                                  ? 'Update Date'
                                  : 'Update Deadline',
                              icon: Icons.event_available_outlined,
                              highlightDate: localDl,
                              highlightLabel: _isInPerson
                                  ? 'Current Date'
                                  : 'Current Deadline',
                            );
                            if (pickedDate != null && ctx.mounted) {
                              setModalState(() {
                                selectedDate = pickedDate;
                                deadlineTimeError = computeTimeError(
                                  selectedDate,
                                  selectedTime,
                                );
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: const Color(0xFF0F8A48),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  if (!_isInPerson) ...[
                    const SizedBox(height: 14),
                    AppTimePickerField(
                      key: ValueKey(
                        '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}-${selectedTime.hour}-${selectedTime.minute}',
                      ),
                      label: 'Submission Time *',
                      initialTime: selectedTime,
                      minTime: isSelectedToday
                          ? TimeOfDay.fromDateTime(
                              DateTime.now().add(const Duration(minutes: 1)),
                            )
                          : null,
                      onTimeSelected: (pickedTime) {
                        setModalState(() {
                          selectedTime = pickedTime;
                          deadlineTimeError = computeTimeError(
                            selectedDate,
                            selectedTime,
                          );
                        });
                      },
                    ),
                  ],
                  if (deadlineTimeError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      deadlineTimeError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (isUnchanged) ...[
                    const SizedBox(height: 8),
                    Text(
                      _isInPerson
                          ? 'Select a different date to update.'
                          : 'Select a different date or time to update the deadline.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingDeadline ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    (isSavingDeadline ||
                        isUnchanged ||
                        deadlineTimeError != null)
                    ? null
                    : () async {
                        final recheckErr = computeTimeError(
                          selectedDate,
                          selectedTime,
                        );
                        if (recheckErr != null) {
                          setModalState(() => deadlineTimeError = recheckErr);
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(this.context);
                        setModalState(() => isSavingDeadline = true);

                        try {
                          final existing = await _client
                              .from('classwork_items')
                              .select('id')
                              .eq('id', _activity.id)
                              .eq('is_archived', false)
                              .maybeSingle();

                          if (existing == null) {
                            AppDataCache.instance.invalidatePrefix(
                              'teacher_activities_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'teacher_assessments_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'student_dashboard_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'gradebook_',
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              await AppModals.showWarningDialog(
                                context: this.context,
                                title: 'Classwork Removed',
                                message:
                                    'This classwork item has already been deleted from the database and can no longer be updated.',
                              );
                            }
                            return;
                          }

                          await _client
                              .from('classwork_items')
                              .update({
                                'deadline': candidateCombined
                                    .toUtc()
                                    .toIso8601String(),
                              })
                              .eq('id', _activity.id);

                          AppDataCache.instance.invalidatePrefix(
                            'teacher_activities_',
                          );
                          AppDataCache.instance.invalidatePrefix(
                            'teacher_assessments_',
                          );
                          AppDataCache.instance.invalidatePrefix(
                            'student_dashboard_',
                          );
                          AppDataCache.instance.invalidatePrefix('gradebook_');
                          TeacherGradebookTab.gradebookRefreshNotifier.value++;

                          if (mounted) {
                            setState(() {
                              _currentDeadline = candidateCombined;
                              _activity = _activity.copyWith(
                                deadline: candidateCombined,
                              );
                            });
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                _isInPerson
                                    ? 'Scheduled date updated to ${_formatDateOnly(candidateCombined)}.'
                                    : 'Deadline updated to ${_formatDateTime(candidateCombined)}. Submissions window synchronized.',
                              ),
                              backgroundColor: const Color(0xFF0F8A48),
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSavingDeadline = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                _isInPerson
                                    ? 'Failed to update date: $e'
                                    : 'Failed to update deadline: $e',
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                child: isSavingDeadline
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isInPerson ? 'Save New Date' : 'Save New Deadline',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSubmissionDetailDialog(
    UserModel student,
    Map<String, dynamic>? submission,
  ) {
    final status = _computeStudentStatus(student);
    final scoreCtrl = TextEditingController(
      text: _scoreControllers[student.id]?.text ?? '',
    );
    final feedbackCtrl = TextEditingController(
      text: submission?['feedback']?.toString() ?? '',
    );

    final fileName = submission?['file_name']?.toString() ?? '';
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final hasFile = submission?['storage_path'] != null;
    final submittedAtStr = submission?['submitted_at']?.toString();
    final submittedAt = submittedAtStr != null
        ? DateTime.tryParse(submittedAtStr)
        : null;

    String? dialogScoreError;
    String? dialogFeedbackError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final theme = Theme.of(dialogCtx);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Text(
                      _formatStudentName(student).isNotEmpty
                          ? _formatStudentName(student).trim()[0].toUpperCase()
                          : 'S',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatStudentName(student),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadgeWidget(status, isDark),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (submittedAt != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 15,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Submitted on ${_formatDateTime(submittedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Online Submitted Document Card (PDF or DOC)
                      if (!_isInPerson && hasFile) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (isPdf
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF2563EB))
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  (isPdf
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF2563EB))
                                      .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPdf
                                    ? Icons.picture_as_pdf
                                    : Icons.description,
                                size: 28,
                                color: isPdf
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (isPdf
                                                        ? const Color(
                                                            0xFFDC2626,
                                                          )
                                                        : const Color(
                                                            0xFF2563EB,
                                                          ))
                                                    .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            isPdf ? 'PDF' : 'DOC',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isPdf
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Submitted File',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fileName.isNotEmpty
                                          ? fileName
                                          : 'Submitted Output',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () => _openStudentFile(submission),
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text('Open File'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isPdf
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (_isInPerson) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.handshake_outlined,
                                size: 20,
                                color: Color(0xFF8B5CF6),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'In-Person Activity: Student turns in their physical work directly in class.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Student Comments / Remarks (if any)
                      if (submission?['feedback'] != null &&
                          submission!['feedback'].toString().isNotEmpty) ...[
                        Text(
                          'Student Remarks:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            submission['feedback'].toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Scoring Input
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Score (0 to ${_activity.maxScore.toInt()} pts) *',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: scoreCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  onChanged: (_) {
                                    if (dialogScoreError != null) {
                                      setModalState(
                                        () => dialogScoreError = null,
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                        '0 - ${_activity.maxScore.toInt()}',
                                    errorText: dialogScoreError,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 25),
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      theme.brightness == Brightness.dark
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : const Color(0xFFFEF2F2),
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: BorderSide(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.red.withValues(alpha: 0.4)
                                        : const Color(0xFFFCA5A5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                onPressed: () {
                                  scoreCtrl.text = '0';
                                  if (dialogScoreError != null) {
                                    setModalState(
                                      () => dialogScoreError = null,
                                    );
                                  }
                                },
                                child: const Text(
                                  'Give 0',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 25),
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      theme.brightness == Brightness.dark
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : const Color(0xFFF0FDF4),
                                  foregroundColor: const Color(0xFF16A34A),
                                  side: BorderSide(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.green.withValues(alpha: 0.4)
                                        : const Color(0xFF86EFAC),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                onPressed: () {
                                  scoreCtrl.text = _activity.maxScore
                                      .toInt()
                                      .toString();
                                  if (dialogScoreError != null) {
                                    setModalState(
                                      () => dialogScoreError = null,
                                    );
                                  }
                                },
                                child: Text(
                                  'Give Max (${_activity.maxScore.toInt()})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Teacher Feedback
                      Text(
                        'Teacher Feedback / Notes:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: feedbackCtrl,
                        maxLines: 2,
                        maxLength: 100,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        onChanged: (_) {
                          if (dialogFeedbackError != null) {
                            setModalState(() => dialogFeedbackError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Add constructive feedback for the student...',
                          errorText: dialogFeedbackError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final text = scoreCtrl.text.trim();
                    final err = AppValidators.validateClassworkStudentScore(
                      text,
                      maxScore: _activity.maxScore,
                      allowEmpty: false,
                    );
                    if (err != null) {
                      setModalState(() => dialogScoreError = err);
                      return;
                    }

                    final fbRaw = feedbackCtrl.text;
                    if (fbRaw.isNotEmpty && fbRaw.trim().isEmpty) {
                      setModalState(
                        () => dialogFeedbackError =
                            'Feedback cannot consist of only spaces.',
                      );
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    _scoreControllers[student.id]?.text = text;
                    await _saveScore(
                      student,
                      text,
                      feedback: fbRaw.trim().isNotEmpty ? fbRaw.trim() : null,
                    );
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save Grade'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDateOnly(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
  }

  String _formatSlotBadge() {
    final col = _activity.gradebookColumnIndex;
    if (col == null) return '';
    final cat = _activity.effectiveGradingCategory;
    if (cat == 'ex') {
      if (col == 1) return ' • ST1';
      if (col == 2) return ' • ST2';
      return ' • TE';
    }
    return ' • ${cat == 'pt' ? 'PT' : 'WW'} $col';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} $hour:$minute $ampm';
  }

  String _formatSubmissionDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final date =
          '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$date $hour:$minute $period';
    } catch (_) {
      return '--';
    }
  }

  String _computeStudentStatus(UserModel student) {
    final sub = _submissionsByStudent[student.id];
    if (sub == null) {
      return 'Missing';
    }

    if (sub['score'] != null) return 'Graded';
    final st = sub['status']?.toString().toLowerCase();
    if (st == 'graded') return 'Graded';
    if (st == 'submitted') {
      final submittedAt = sub['submitted_at'] != null
          ? DateTime.tryParse(sub['submitted_at'].toString())
          : null;
      if (submittedAt != null && submittedAt.isAfter(_currentDeadline)) {
        return 'Late';
      }
      return 'Submitted';
    }
    return 'Missing';
  }

  List<UserModel> get _filteredStudents {
    return _enrolledStudents.where((student) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = _formatStudentName(student).toLowerCase();
        final rawName = student.fullName.toLowerCase();
        if (!name.contains(q) && !rawName.contains(q)) return false;
      }

      if (_selectedStatus != 'All') {
        final status = _computeStudentStatus(student);
        if (_selectedStatus == 'Submitted' &&
            status != 'Submitted' &&
            status != 'Late') {
          return false;
        }
        if (_selectedStatus == 'Graded' && status != 'Graded') return false;
        if (_selectedStatus == 'Missing' && status != 'Missing') {
          return false;
        }
        if (_selectedStatus == 'Late' && status != 'Late') return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _filteredStudents;
    final totalStudents = filtered.length;
    final totalPages = (totalStudents == 0)
        ? 1
        : ((totalStudents - 1) / _pageSize).floor() + 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    final startIndex = (_currentPage - 1) * _pageSize;
    final pageStudents = filtered.skip(startIndex).take(_pageSize).toList();

    int submittedCount = 0;
    int gradedCount = 0;
    int missingCount = 0;
    for (final s in _enrolledStudents) {
      final st = _computeStudentStatus(s);
      if (st == 'Graded') gradedCount++;
      if (st == 'Submitted' || st == 'Late') submittedCount++;
      if (st == 'Missing') missingCount++;
    }

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _activity.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _isInPerson
                                ? AppTheme.catPurple.withValues(alpha: 0.12)
                                : AppTheme.catBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isInPerson ? 'In-Person' : 'Online Submission',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isInPerson
                                  ? AppTheme.catPurple
                                  : AppTheme.catBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_activity.subject} • ${_activity.section} • Term ${_activity.termNumber} • Max ${_activity.maxScore.toInt()} pts${_formatSlotBadge()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Teacher Attached Material Box (Rectangular, matches Deadline Box)
              _buildAttachmentBox(isDark, theme),
              const SizedBox(width: 10),
              // Deadline Box & Update Button
              _buildDeadlineContainer(isDark, theme),
            ],
          ),
        ],
      ),
    );

    final rawInstructions = _activity.instructions.trim().isNotEmpty
        ? _activity.instructions.trim()
        : _activity.description.trim();

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rawInstructions.isNotEmpty) ...[
                  _buildInstructionsSection(rawInstructions, isDark, theme),
                ],
                // Top Filter & Search Bar (60-30-10 styling)
                Row(
                  children: [
                    _statBadge(
                      'All Enrolled: ${_enrolledStudents.length}',
                      Colors.grey.shade600,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _statBadge(
                      'Submitted: $submittedCount',
                      AppTheme.catGreen,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _statBadge(
                      'Graded: $gradedCount',
                      AppTheme.catBlue,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _statBadge(
                      'Missing: $missingCount',
                      const Color(0xFFDC2626),
                      isDark,
                    ),
                    const Spacer(),

                    // Search Input
                    SizedBox(
                      width: 220,
                      height: 38,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search student...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                            _currentPage = 1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter Status Dropdown
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Text('All Statuses'),
                            ),
                            DropdownMenuItem(
                              value: 'Submitted',
                              child: Text('Submitted'),
                            ),
                            DropdownMenuItem(
                              value: 'Graded',
                              child: Text('Graded'),
                            ),
                            DropdownMenuItem(
                              value: 'Missing',
                              child: Text('Missing'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStatus = val;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table Header row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 32,
                        child: Text(
                          '#',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Avatar spacer
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'STUDENT NAME',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 100,
                        child: Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 150,
                        child: Text(
                          'DATE SUBMITTED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _isInPerson
                              ? 'SUBMISSION'
                              : 'SUBMITTED WORK (PDF / DOC)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const SizedBox(
                        width: 170,
                        child: Text(
                          'SCORE / ACTION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Fast Scoring Table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border(
                        left: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        right: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        bottom: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                    ),
                    child: totalStudents == 0
                        ? Center(
                            child: Text(
                              'No learners found matching filter.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: pageStudents.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final student = pageStudents[idx];
                              final sub = _submissionsByStudent[student.id];
                              final status = _computeStudentStatus(student);
                              final ctrl = _scoreControllers[student.id]!;
                              final isSaving =
                                  _isSavingStudent[student.id] == true;

                              return _buildStudentRow(
                                student: student,
                                submission: sub,
                                status: status,
                                controller: ctrl,
                                isSaving: isSaving,
                                rowNumber: startIndex + idx + 1,
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Pagination Controls (15 per page)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      totalStudents == 0
                          ? 'Showing 0 students'
                          : 'Showing ${startIndex + 1}–${startIndex + pageStudents.length} of $totalStudents learners (15 per page)',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage = 1)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'First',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage--)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.chevron_left, size: 16),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$_currentPage',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: _currentPage < totalPages
                              ? () => setState(() => _currentPage++)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.chevron_right, size: 16),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: _currentPage < totalPages
                              ? () => setState(() => _currentPage = totalPages)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'Last',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Column(
        children: [
          header,
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildAttachmentBox(bool isDark, ThemeData theme) {
    final hasAttachment = (_activity.storagePath != null &&
            _activity.storagePath!.trim().isNotEmpty) ||
        (_activity.attachmentName != null &&
            _activity.attachmentName!.trim().isNotEmpty);

    if (hasAttachment) {
      final fileName = _activity.attachmentName?.trim() ?? '';
      final isPdf = fileName.toLowerCase().endsWith('.pdf');

      return Tooltip(
        message: fileName.isNotEmpty ? fileName : 'View Attached File',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openTeacherAttachment,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 38),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPdf
                      ? const Color(0xFFDC2626).withValues(alpha: 0.28)
                      : theme.colorScheme.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.description,
                    size: 16,
                    color: isPdf
                        ? const Color(0xFFDC2626)
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View Attached File',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attachment_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 8),
          Text(
            'No Attached File',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineContainer(bool isDark, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isInPerson ? Icons.event_outlined : Icons.schedule,
            size: 16,
            color: (!_isInPerson && _currentDeadline.isBefore(DateTime.now()))
                ? const Color(0xFFDC2626)
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            _isInPerson
                ? 'Set Date: ${_formatDateOnly(_currentDeadline)}'
                : 'Deadline: ${_formatDateTime(_currentDeadline)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (!_isInPerson && _currentDeadline.isBefore(DateTime.now()))
                  ? const Color(0xFFDC2626)
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: _showUpdateDeadlineDialog,
            icon: const Icon(Icons.edit_calendar, size: 15),
            label: Text(
              _isInPerson ? 'Update Date' : 'Update Deadline',
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection(
    String instructions,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isInstructionsExpanded = !_isInstructionsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!_isInstructionsExpanded)
                    Expanded(
                      child: Text(
                        instructions.replaceAll(RegExp(r'\s+'), ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isInstructionsExpanded ? 'Hide' : 'Show More',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isInstructionsExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isInstructionsExpanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Scrollbar(
                  controller: _instructionsScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _instructionsScrollController,
                    child: SelectableText(
                      instructions,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadgeWidget(String status, bool isDark) {
    Color badgeBg;
    Color badgeText;
    switch (status) {
      case 'Submitted':
        badgeBg = AppTheme.catGreen.withValues(alpha: 0.12);
        badgeText = AppTheme.catGreen;
        break;
      case 'Graded':
        badgeBg = AppTheme.catBlue.withValues(alpha: 0.12);
        badgeText = AppTheme.catBlue;
        break;
      case 'Late':
        badgeBg = const Color(0xFFD97706).withValues(alpha: 0.15);
        badgeText = const Color(0xFFD97706);
        break;
      case 'Missing':
        badgeBg = const Color(0xFFDC2626).withValues(alpha: 0.12);
        badgeText = const Color(0xFFDC2626);
        break;
      default:
        badgeBg = isDark ? Colors.white10 : Colors.grey.shade200;
        badgeText = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: badgeText,
        ),
      ),
    );
  }

  Widget _buildStudentRow({
    required UserModel student,
    required Map<String, dynamic>? submission,
    required String status,
    required TextEditingController controller,
    required bool isSaving,
    required int rowNumber,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fileName = submission?['file_name']?.toString() ?? '';
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final hasFile =
        submission?['storage_path'] != null || submission?['file_name'] != null;

    final accentDocColor = isPdf
        ? const Color(0xFFDC2626) // Red for PDF
        : const Color(0xFF2563EB); // Blue for Word/Doc

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Row index
          SizedBox(
            width: 32,
            child: Text(
              '$rowNumber',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Student Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              _formatStudentName(student).isNotEmpty
                  ? _formatStudentName(student).trim()[0].toUpperCase()
                  : 'S',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Name (Lastname, Firstname M.I.)
          Expanded(
            flex: 3,
            child: Text(
              _formatStudentName(student),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          // Status Badge / In-Person Selector
          SizedBox(
            width: 100,
            child: (_isInPerson && status != 'Graded')
                ? Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: (status == 'Submitted' || status == 'Late')
                          ? AppTheme.catGreen.withValues(alpha: 0.12)
                          : const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (status == 'Submitted' || status == 'Late')
                            ? AppTheme.catGreen.withValues(alpha: 0.3)
                            : const Color(0xFFDC2626).withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (status == 'Submitted' || status == 'Late')
                            ? 'Submitted'
                            : 'Missing',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (status == 'Submitted' || status == 'Late')
                              ? AppTheme.catGreen
                              : const Color(0xFFDC2626),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Submitted',
                            child: Text(
                              'Submitted',
                              style: TextStyle(
                                color: AppTheme.catGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Missing',
                            child: Text(
                              'Missing',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _updateInPersonStatus(
                              student,
                              val.toLowerCase(),
                            );
                          }
                        },
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadgeWidget(status, isDark),
                  ),
          ),
          const SizedBox(width: 8),

          // Date Column
          SizedBox(
            width: 150,
            child: Text(
              _formatSubmissionDate(submission?['submitted_at']?.toString()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const SizedBox(width: 8),

          // Online Work Attachment Viewer Badge (PDF / DOC)
          Expanded(
            flex: 3,
            child: !_isInPerson && hasFile
                ? InkWell(
                    onTap: () => _openStudentFile(submission),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accentDocColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentDocColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.description,
                            size: 16,
                            color: accentDocColor,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: accentDocColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              isPdf ? 'PDF' : 'DOC',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: accentDocColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              fileName.isNotEmpty ? fileName : 'View Work',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: accentDocColor,
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    _isInPerson ? 'Physical Submission' : 'No attachment',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
          const SizedBox(width: 16),

          // FAST INLINE SCORE INPUT + REVIEW DETAILS BUTTON
          SizedBox(
            width: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Review details modal button
                    IconButton(
                      icon: const Icon(Icons.rate_review_outlined, size: 19),
                      tooltip: 'Review Details & Feedback',
                      onPressed: () =>
                          _showSubmissionDetailDialog(student, submission),
                    ),
                    const SizedBox(width: 4),
                    // Inline Numeric Input
                    SizedBox(
                      width: 76,
                      height: 36,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: false,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        onChanged: (_) {
                          if (_scoreErrors[student.id] != null) {
                            setState(() => _scoreErrors.remove(student.id));
                          }
                        },
                        decoration: InputDecoration(
                          hintText: '/ ${_activity.maxScore.toInt()}',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white10
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _scoreErrors[student.id] != null
                                  ? theme.colorScheme.error
                                  : (isDark
                                        ? Colors.white24
                                        : Colors.grey.shade300),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _scoreErrors[student.id] != null
                                  ? theme.colorScheme.error
                                  : (isDark
                                        ? Colors.white24
                                        : Colors.grey.shade300),
                              width: _scoreErrors[student.id] != null ? 1.5 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _scoreErrors[student.id] != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (val) => _saveScore(student, val),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isSaving)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF0F8A48),
                          size: 20,
                        ),
                        tooltip: 'Save Score',
                        onPressed: () => _saveScore(student, controller.text),
                      ),
                  ],
                ),
                if (_scoreErrors[student.id] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 6),
                    child: Text(
                      _scoreErrors[student.id]!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
