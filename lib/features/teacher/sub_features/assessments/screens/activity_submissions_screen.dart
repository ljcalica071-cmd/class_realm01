import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';

class ActivitySubmissionsScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool embedded;
  final VoidCallback? onBack;

  const ActivitySubmissionsScreen({
    super.key,
    required this.activity,
    this.embedded = false,
    this.onBack,
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
  static const int _pageSize = 20;

  List<UserModel> _enrolledStudents = [];
  Map<String, Map<String, dynamic>> _submissionsByStudent = {};
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, bool> _isSavingStudent = {};

  final SupabaseClient _client = Supabase.instance.client;

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
    for (final ctrl in _scoreControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final teacher = AuthRepository.instance.currentUser;
    if (teacher == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
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
            final lastA = a.lastName ?? a.fullName;
            final lastB = b.lastName ?? b.fullName;
            return lastA.toLowerCase().compareTo(lastB.toLowerCase());
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
      } catch (_) {
        final res = await _client
            .from('student_classwork_submissions')
            .select()
            .eq('classwork_id', _activity.id);
        submissionRows = res as List? ?? [];
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
            final catKey = _activity.isRequirement ? 'pt' : 'ww';
            final colKey = _activity.gradebookColumnIndex.toString();

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

  Future<void> _openStudentFile(Map<String, dynamic>? submission) async {
    final path = submission?['storage_path']?.toString();
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission file is not available.')),
      );
      return;
    }

    try {
      final url = _client.storage
          .from('classwork-materials')
          .getPublicUrl(path);
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open document.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    }
  }

  Future<void> _openTeacherAttachment() async {
    final path = _activity.storagePath;
    if (path == null || path.isEmpty) return;

    try {
      final url = _client.storage
          .from('classwork-materials')
          .getPublicUrl(path);
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open attached material.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening material: $e')));
      }
    }
  }

  Future<void> _saveScore(
    UserModel student,
    String scoreStr, {
    String? feedback,
  }) async {
    final cleanStr = scoreStr.trim();
    double? newScore;
    if (cleanStr.isNotEmpty) {
      newScore = double.tryParse(cleanStr);
      if (newScore == null || newScore < 0 || newScore > _activity.maxScore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid score for ${student.fullName}. Must be 0 to ${_activity.maxScore.toInt()}.',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    setState(() => _isSavingStudent[student.id] = true);

    try {
      final currentSub =
          _submissionsByStudent[student.id] ?? <String, dynamic>{};
      final newStatus = newScore != null
          ? 'graded'
          : (_isInPerson
                ? (currentSub['status'] ?? 'submitted')
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
      if (currentSub['submitted_at'] != null) {
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
          final catKey = _activity.isRequirement ? 'pt' : 'ww';
          final catScores = Map<String, dynamic>.from(
            studentScores[catKey] as Map? ?? {},
          );
          final colKey = _activity.gradebookColumnIndex.toString();

          if (newScore != null) {
            catScores[colKey] = newScore;
          } else {
            catScores.remove(colKey);
          }
          studentScores[catKey] = catScores;
          scores[student.id] = studentScores;
          termSheet['scores'] = scores;

          await SubjectRepository.instance.saveGradebookTermSheet(
            _activity.subjectOfferingId!,
            _activity.termNumber,
            termSheet,
          );
        } catch (gbSyncErr) {
          debugPrint('Gradebook term sheet sync notice: $gbSyncErr');
        }
      }

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
                  ? 'Score saved for ${student.fullName}: ${newScore.toInt()} / ${_activity.maxScore.toInt()} pts'
                  : 'Score cleared for ${student.fullName}.',
            ),
            backgroundColor: const Color(0xFF0F8A48),
            duration: const Duration(seconds: 1),
          ),
        );
      }
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
    }
  }

  Future<void> _updateInPersonStatus(UserModel student, String status) async {
    setState(() => _isSavingStudent[student.id] = true);
    try {
      final currentSub =
          _submissionsByStudent[student.id] ?? <String, dynamic>{};
      final upsertData = <String, dynamic>{
        'classwork_id': _activity.id,
        'student_id': student.id,
        'status': status,
        'score': currentSub['score'],
        'submitted_at':
            currentSub['submitted_at'] ??
            DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _client
          .from('student_classwork_submissions')
          .upsert(upsertData, onConflict: 'classwork_id,student_id');

      setState(() {
        final updated = Map<String, dynamic>.from(currentSub);
        updated['status'] = status;
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
    DateTime selectedDate = _currentDeadline;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(_currentDeadline);
    bool isSavingDeadline = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
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
                const Text(
                  'Update Deadline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    'Set a new submission deadline for "${_activity.title}". Extending the deadline dynamically re-opens submission for all enrolled students.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: isSavingDeadline
                        ? null
                        : () async {
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null && ctx.mounted) {
                              final pickedTime = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime,
                              );
                              if (pickedTime != null) {
                                setModalState(() {
                                  selectedDate = pickedDate;
                                  selectedTime = pickedTime;
                                });
                              }
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.month}/${selectedDate.day}/${selectedDate.year} at ${selectedTime.format(context)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 12),
                  Text(
                    'Current Deadline: ${_formatDateTime(_currentDeadline)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingDeadline ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSavingDeadline
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() => isSavingDeadline = true);
                        final newCombined = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        try {
                          await _client
                              .from('classwork_items')
                              .update({
                                'deadline': newCombined
                                    .toUtc()
                                    .toIso8601String(),
                              })
                              .eq('id', _activity.id);

                          AppDataCache.instance.invalidatePrefix(
                            'teacher_activities_',
                          );
                          AppDataCache.instance.invalidatePrefix(
                            'student_dashboard_',
                          );

                          if (mounted) {
                            setState(() {
                              _currentDeadline = newCombined;
                              _activity = _activity.copyWith(
                                deadline: newCombined,
                              );
                            });
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Deadline updated to ${_formatDateTime(newCombined)}. Submissions window synchronized.',
                              ),
                              backgroundColor: const Color(0xFF0F8A48),
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSavingDeadline = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to update deadline: $e'),
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
                    : const Text('Save New Deadline'),
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

    showDialog(
      context: context,
      builder: (dialogCtx) {
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
                  student.fullName.isNotEmpty
                      ? student.fullName.trim()[0].toUpperCase()
                      : 'S',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      student.lrn?.isNotEmpty == true
                          ? 'LRN: ${student.lrn}'
                          : 'Student Submission Review',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                            isPdf ? Icons.picture_as_pdf : Icons.description,
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
                                                    ? const Color(0xFFDC2626)
                                                    : const Color(0xFF2563EB))
                                                .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
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
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Score (Max ${_activity.maxScore.toInt()} pts) *',
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
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Enter score',
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
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: OutlinedButton(
                          onPressed: () {
                            scoreCtrl.text = _activity.maxScore
                                .toInt()
                                .toString();
                          },
                          child: Text(
                            'Give Max (${_activity.maxScore.toInt()})',
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
                    decoration: InputDecoration(
                      hintText: 'Add constructive feedback for the student...',
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
                final text = scoreCtrl.text;
                Navigator.pop(dialogCtx);
                _scoreControllers[student.id]?.text = text;
                await _saveScore(student, text, feedback: feedbackCtrl.text);
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save Grade'),
            ),
          ],
        );
      },
    );
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
        final name = student.fullName.toLowerCase();
        final lrn = (student.lrn ?? '').toLowerCase();
        if (!name.contains(q) && !lrn.contains(q)) return false;
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
                      children: [
                        Text(
                          _activity.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
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
                      '${_activity.subject} • ${_activity.section} • Term ${_activity.termNumber} • Max ${_activity.maxScore.toInt()} pts${_activity.gradebookColumnIndex != null ? ' • ${_activity.isRequirement ? 'PT' : 'WW'} ${_activity.gradebookColumnIndex}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Teacher Attached Material Pill
              if (_activity.storagePath != null ||
                  _activity.attachmentName != null) ...[
                OutlinedButton.icon(
                  onPressed: _openTeacherAttachment,
                  icon: Icon(
                    (_activity.attachmentName ?? '').toLowerCase().endsWith(
                          '.pdf',
                        )
                        ? Icons.picture_as_pdf
                        : Icons.description,
                    size: 16,
                    color:
                        (_activity.attachmentName ?? '').toLowerCase().endsWith(
                          '.pdf',
                        )
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB),
                  ),
                  label: Text(
                    'Material: ${_activity.attachmentName ?? 'View File'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Deadline Pill & Update Button
              Container(
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
                      Icons.schedule,
                      size: 16,
                      color: _currentDeadline.isBefore(DateTime.now())
                          ? const Color(0xFFDC2626)
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Deadline: ${_formatDateTime(_currentDeadline)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _currentDeadline.isBefore(DateTime.now())
                            ? const Color(0xFFDC2626)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: _showUpdateDeadlineDialog,
                      icon: const Icon(Icons.edit_calendar, size: 15),
                      label: const Text('Update Deadline'),
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
              ),
            ],
          ),
        ],
      ),
    );

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      theme.colorScheme.primary,
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
                            DropdownMenuItem(
                              value: 'Late',
                              child: Text('Late Submissions'),
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
                        width: 120,
                        child: Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'SUBMITTED WORK (PDF / DOC)',
                          style: TextStyle(
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

                // Pagination Controls (20 per page)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      totalStudents == 0
                          ? 'Showing 0 students'
                          : 'Showing ${startIndex + 1}–${startIndex + pageStudents.length} of $totalStudents learners (20 per page)',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text('Previous'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'Page $_currentPage of $totalPages',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _currentPage < totalPages
                              ? () => setState(() => _currentPage++)
                              : null,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: const Text('Next'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
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
      case 'Graded':
        badgeBg = AppTheme.catGreen.withValues(alpha: 0.12);
        badgeText = AppTheme.catGreen;
        break;
      case 'Submitted':
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
              student.fullName.isNotEmpty
                  ? student.fullName.trim()[0].toUpperCase()
                  : 'S',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Name & LRN
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  student.lrn?.isNotEmpty == true
                      ? 'LRN: ${student.lrn}'
                      : 'Student',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Status Badge / In-Person Selector
          SizedBox(
            width: 120,
            child: _isInPerson
                ? Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: (status == 'Graded' || status == 'Submitted')
                          ? AppTheme.catGreen.withValues(alpha: 0.12)
                          : const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (status == 'Graded' || status == 'Submitted')
                            ? AppTheme.catGreen.withValues(alpha: 0.3)
                            : const Color(0xFFDC2626).withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (status == 'Graded' || status == 'Submitted')
                            ? 'Submitted'
                            : 'Missing',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (status == 'Graded' || status == 'Submitted')
                              ? AppTheme.catGreen
                              : const Color(0xFFDC2626),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Submitted',
                            child: Text('Submitted'),
                          ),
                          DropdownMenuItem(
                            value: 'Missing',
                            child: Text('Missing'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _updateInPersonStatus(
                              student,
                              val == 'Submitted' ? 'submitted' : 'missing',
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
          const SizedBox(width: 16),

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
            child: Row(
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: '/ ${_activity.maxScore.toInt()}',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
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
          ),
        ],
      ),
    );
  }
}
