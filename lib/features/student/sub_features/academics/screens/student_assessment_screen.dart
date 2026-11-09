import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';
import 'package:class_realm/features/student/sub_features/academics/widgets/student_exam_review_modal.dart';

class StudentAssessmentScreen extends StatefulWidget {
  final QuizOrExamModel assessment;

  const StudentAssessmentScreen({super.key, required this.assessment});

  static Future<void> start(BuildContext context, QuizOrExamModel assessment) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAssessmentScreen(assessment: assessment),
      ),
    );
  }

  static String vaultKeyFor(String assessmentId, String studentId) =>
      'exam_vault_${assessmentId}_$studentId';

  static String activePointerKeyFor(String studentId) =>
      'active_assessment_pointer_$studentId';

  /// Checks local persistent storage (and server fallback) for an in-progress
  /// quiz or examination so the student is automatically redirected back to
  /// where they left off upon reopening the app or logging back in.
  static Future<QuizOrExamModel?> getActiveAssessmentToResume(
    String studentId,
  ) async {
    if (studentId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pointerKey = activePointerKeyFor(studentId);
      final rawPointer =
          prefs.getString(pointerKey) ??
          AppDataCache.instance.get<String>(pointerKey);

      if (rawPointer != null && rawPointer.isNotEmpty) {
        final decoded = jsonDecode(rawPointer) as Map<String, dynamic>;
        final step = (decoded['currentStep'] as num?)?.toInt() ?? 0;
        final assessMap = decoded['assessmentJson'];
        if (step == 1 && assessMap is Map) {
          final model = QuizOrExamModel.fromJson(
            Map<String, dynamic>.from(assessMap),
          );
          if (model.id.isNotEmpty && model.questions.isNotEmpty) {
            // Ensure the per-assessment vault key is also hydrated in memory cache
            final vKey = vaultKeyFor(model.id, studentId);
            AppDataCache.instance.set<String>(vKey, rawPointer);
            return model;
          }
        }
      }

      // Fallback: Check server for an in_progress attempt in case local storage was cleared
      final client = SupabaseService().client;
      final activeAttempt = await client
          .from('assessment_attempts')
          .select('assessment_id, started_at, active_session_id')
          .eq('student_id', studentId)
          .eq('status', 'in_progress')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final assessId = activeAttempt?['assessment_id']?.toString();
      if (assessId != null && assessId.isNotEmpty) {
        final rawAssess = await client
            .from('digital_assessments')
            .select("""
              id,
              subject_offering_id,
              assessment_type,
              title,
              instructions,
              time_limit_minutes,
              available_from,
              deadline,
              results_released,
              is_archived,
              assessment_questions (
                id,
                position,
                question_type,
                question_text,
                points,
                assessment_question_options (
                  id,
                  position,
                  option_text,
                  is_correct
                )
              )
            """)
            .eq('id', assessId)
            .maybeSingle();

        if (rawAssess != null && rawAssess['is_archived'] != true) {
          final qRows = (rawAssess['assessment_questions'] as List? ?? [])
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList()
            ..sort(
              (a, b) => ((a['position'] as num?) ?? 0).compareTo(
                (b['position'] as num?) ?? 0,
              ),
            );
          final questions = qRows
              .map((q) => QuestionModel.fromSupabaseMap(q))
              .toList();
          if (questions.isNotEmpty) {
            final assessType = rawAssess['assessment_type']
                ?.toString()
                .toLowerCase();
            return QuizOrExamModel(
              id: rawAssess['id'].toString(),
              title: rawAssess['title']?.toString() ?? 'Assessment',
              description: rawAssess['instructions']?.toString() ?? '',
              subject: 'Assigned Subject',
              section: 'Assigned Section',
              isExam: assessType != 'quiz',
              examType: assessType,
              durationMinutes:
                  (rawAssess['time_limit_minutes'] as num?)?.toInt() ?? 60,
              scheduleDate: DateTime.now(),
              isPublished: true,
              resultsReleased: rawAssess['results_released'] == true,
              questions: questions,
              subjectOfferingId: rawAssess['subject_offering_id']?.toString(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Notice checking local active assessment pointer: $e');
    }
    return null;
  }

  @override
  State<StudentAssessmentScreen> createState() =>
      StudentAssessmentScreenState();
}

class StudentAssessmentScreenState extends State<StudentAssessmentScreen>
    with WidgetsBindingObserver {
  @visibleForTesting
  void handleTeacherResetForTesting(String reason) => _handleTeacherReset(reason);

  @visibleForTesting
  void handleTeacherForceSubmitForTesting(String reason) => _handleTeacherForceSubmit(reason);

  int _currentStep =
      0; // 0: Rules Acknowledgment, 1: Answering Questions, 2: Result Summary
  bool _rulesAccepted = false;
  int _currentQuestionIndex = 0;
  List<QuestionModel> _orderedQuestions = [];
  final Map<String, String> _studentAnswers = {};
  final Map<String, TextEditingController> _textControllers = {};
  int _violations = 0;
  final List<Map<String, dynamic>> _violationLog = [];
  bool _isSubmitting = false;
  bool _isOffline = false;
  bool _pendingOfflineSync = false;
  int _offlineSeconds = 0;
  bool _isConnectionFrozen = false;
  int _reconnectWindowSeconds = 60;
  bool _isReconnectTimedOut = false;

  Timer? _timer;
  Timer? _heartbeatTimer;
  Timer? _offlineRetryTimer;
  int _secondsRemaining = 0;
  DateTime? _startTime;
  AssessmentResultModel? _submittedResult;
  RealtimeChannel? _proctorChannel;
  String? _mySessionId;

  String get _assessmentLabel =>
      widget.assessment.isExam ? 'examination' : 'quiz';
  String get _assessmentTitleLabel =>
      widget.assessment.isExam ? 'Examination' : 'Quiz';

  TextEditingController _getTextController(String questionId) {
    return _textControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _studentAnswers[questionId] ?? ''),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Deterministically shuffle questions per student strictly within each category
    final studentId = AuthRepository.instance.currentUser?.id ?? 'student';
    final seed = studentId.hashCode ^ widget.assessment.id.hashCode;

    final mcQuestions =
        widget.assessment.questions
            .where((q) => q.type == QuestionType.multipleChoice)
            .toList()
          ..shuffle(Random(seed));

    final tfQuestions =
        widget.assessment.questions
            .where((q) => q.type == QuestionType.trueFalse)
            .toList()
          ..shuffle(Random(seed + 1));

    final idQuestions =
        widget.assessment.questions
            .where((q) => q.type == QuestionType.identification)
            .toList()
          ..shuffle(Random(seed + 2));

    final otherQuestions = widget.assessment.questions
        .where(
          (q) =>
              q.type != QuestionType.multipleChoice &&
              q.type != QuestionType.trueFalse &&
              q.type != QuestionType.identification,
        )
        .toList();

    _orderedQuestions = [
      ...mcQuestions,
      ...tfQuestions,
      ...idQuestions,
      ...otherQuestions,
    ];

    // Deterministically shuffle choices per Multiple Choice question (anti-collusion)
    for (var i = 0; i < _orderedQuestions.length; i++) {
      final q = _orderedQuestions[i];
      if (q.type == QuestionType.multipleChoice && q.choices.length > 1) {
        // Resolve original correct answer text before shuffling so scoring is rock-solid
        String resolvedCorrectText = q.correctAnswer;
        const letters = ['a', 'b', 'c', 'd'];
        final origIdx = letters.indexOf(q.correctAnswer.trim().toLowerCase());
        if (origIdx != -1 && origIdx < q.choices.length) {
          resolvedCorrectText = q.choices[origIdx];
        }

        final choiceSeed = seed ^ q.id.hashCode;
        final shuffledChoices = List<String>.from(q.choices)
          ..shuffle(Random(choiceSeed));
        _orderedQuestions[i] = QuestionModel(
          id: q.id,
          questionText: q.questionText,
          type: q.type,
          choices: shuffledChoices,
          correctAnswer: resolvedCorrectText,
          points: q.points,
          matchingPairs: q.matchingPairs,
        );
      }
    }

    for (var q in _orderedQuestions) {
      _studentAnswers[q.id] = '';
    }
    _secondsRemaining = widget.assessment.durationMinutes * 60;

    // Synchronously check in-memory vault first, then asynchronously check SharedPreferences
    final vaultKey = StudentAssessmentScreen.vaultKeyFor(
      widget.assessment.id,
      studentId,
    );
    final cachedVault = AppDataCache.instance.get<String>(vaultKey);
    if (cachedVault != null && cachedVault.isNotEmpty) {
      _applyDecodedVault(cachedVault, autoStartTimer: true);
    }
    _restorePersistedVault(studentId);

    _setupProctorChannel(studentId);
  }

  void _applyDecodedVault(String rawJson, {required bool autoStartTimer}) {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

      // Restore question ordering if saved
      final orderIds = (decoded['questionOrderIds'] as List?)
          ?.map((e) => e.toString())
          .toList();
      if (orderIds != null && orderIds.length == _orderedQuestions.length) {
        final byId = {for (final q in _orderedQuestions) q.id: q};
        final reordered = <QuestionModel>[];
        for (final id in orderIds) {
          final match = byId[id];
          if (match != null) reordered.add(match);
        }
        if (reordered.length == _orderedQuestions.length) {
          _orderedQuestions = reordered;
        }
      }

      final savedAnswers = Map<String, dynamic>.from(
        decoded['answers'] as Map? ?? {},
      );
      for (final entry in savedAnswers.entries) {
        final val = entry.value.toString();
        _studentAnswers[entry.key] = val;
        if (_textControllers.containsKey(entry.key)) {
          _textControllers[entry.key]!.text = val;
        }
      }

      final savedQuestionIdx = (decoded['currentQuestionIndex'] as num?)
          ?.toInt();
      if (savedQuestionIdx != null &&
          savedQuestionIdx >= 0 &&
          savedQuestionIdx < _orderedQuestions.length) {
        _currentQuestionIndex = savedQuestionIdx;
      }

      final savedViolations = (decoded['violations'] as num?)?.toInt();
      if (savedViolations != null && savedViolations > _violations) {
        _violations = savedViolations;
      }

      final savedSessionId = decoded['mySessionId']?.toString();
      if (savedSessionId != null && savedSessionId.isNotEmpty) {
        _mySessionId = savedSessionId;
      }

      _pendingOfflineSync = decoded['pendingOfflineSubmission'] == true;

      final totalAllowedSeconds = widget.assessment.durationMinutes * 60;
      final startedAtIso = decoded['startedAtIso']?.toString();
      final savedSeconds = (decoded['secondsRemaining'] as num?)?.toInt();

      if (startedAtIso != null && startedAtIso.isNotEmpty) {
        final parsedStart = DateTime.tryParse(startedAtIso);
        if (parsedStart != null) {
          _startTime = parsedStart.toLocal();
          final elapsed = DateTime.now()
              .toUtc()
              .difference(parsedStart.toUtc())
              .inSeconds;
          final computedRemaining = totalAllowedSeconds - elapsed;
          if (savedSeconds != null && savedSeconds < computedRemaining) {
            _secondsRemaining = savedSeconds.clamp(0, totalAllowedSeconds);
          } else {
            _secondsRemaining = computedRemaining.clamp(0, totalAllowedSeconds);
          }
        }
      } else if (savedSeconds != null &&
          savedSeconds >= 0 &&
          savedSeconds <= totalAllowedSeconds) {
        _secondsRemaining = savedSeconds;
      }

      final savedStep = (decoded['currentStep'] as num?)?.toInt() ?? 0;
      if (savedStep == 1 || decoded['rulesAccepted'] == true) {
        _rulesAccepted = true;
        _currentStep = 1;
        if (autoStartTimer) {
          _startTimer(preserveStartTime: true);
          _startHeartbeat();
          if (_secondsRemaining <= 0 || _pendingOfflineSync) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _submitAssessment(autoSubmit: true);
              }
            });
          }
        }
      }
    } catch (vaultErr) {
      debugPrint('Notice restoring vault state: $vaultErr');
    }
  }

  Future<void> _restorePersistedVault(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vaultKey = StudentAssessmentScreen.vaultKeyFor(
        widget.assessment.id,
        studentId,
      );
      final persisted = prefs.getString(vaultKey);
      if (persisted != null && persisted.isNotEmpty) {
        AppDataCache.instance.set<String>(vaultKey, persisted);
        if (mounted) {
          setState(() {
            _applyDecodedVault(persisted, autoStartTimer: _timer == null);
          });
        }
        return;
      }

      // Fallback: check if server has an in_progress attempt for this student & assessment
      if (!_isSupabaseReady) return;
      final prior = await SupabaseService().client
          .from('assessment_attempts')
          .select('status, started_at, active_session_id')
          .eq('assessment_id', widget.assessment.id)
          .eq('student_id', studentId)
          .maybeSingle();

      if (prior != null && prior['status'] == 'in_progress' && mounted) {
        final serverStartStr = prior['started_at']?.toString();
        final serverStart = serverStartStr != null
            ? DateTime.tryParse(serverStartStr)
            : null;
        setState(() {
          _rulesAccepted = true;
          _currentStep = 1;
          _mySessionId =
              prior['active_session_id']?.toString() ??
              'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
          if (serverStart != null) {
            _startTime = serverStart.toLocal();
            final elapsed = DateTime.now()
                .toUtc()
                .difference(serverStart.toUtc())
                .inSeconds;
            _secondsRemaining =
                ((widget.assessment.durationMinutes * 60) - elapsed).clamp(
                  0,
                  widget.assessment.durationMinutes * 60,
                );
          }
        });
        _saveVault();
        _startTimer(preserveStartTime: true);
        _startHeartbeat();
      }
    } catch (e) {
      debugPrint('Notice checking persisted exam vault: $e');
    }
  }

  void _saveVault() {
    try {
      final studentId = AuthRepository.instance.currentUser?.id ?? 'student';
      final vaultKey = StudentAssessmentScreen.vaultKeyFor(
        widget.assessment.id,
        studentId,
      );
      final pointerKey = StudentAssessmentScreen.activePointerKeyFor(studentId);
      final data = jsonEncode({
        'assessmentId': widget.assessment.id,
        'studentId': studentId,
        'assessmentJson': widget.assessment.toJson(),
        'currentStep': _currentStep,
        'rulesAccepted': _rulesAccepted,
        'currentQuestionIndex': _currentQuestionIndex,
        'questionOrderIds': _orderedQuestions.map((q) => q.id).toList(),
        'answers': _studentAnswers,
        'startedAtIso': (_startTime ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'secondsRemaining': _secondsRemaining,
        'violations': _violations,
        'mySessionId': _mySessionId,
        'pendingOfflineSubmission': _pendingOfflineSync,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      });
      AppDataCache.instance.set<String>(vaultKey, data);
      if (_currentStep == 1) {
        AppDataCache.instance.set<String>(pointerKey, data);
      }
      SharedPreferences.getInstance()
          .then((prefs) {
            prefs.setString(vaultKey, data);
            if (_currentStep == 1) {
              prefs.setString(pointerKey, data);
            }
          })
          .catchError((_) {});
    } catch (e) {
      debugPrint('Notice saving exam vault: $e');
    }
  }

  Future<void> _clearVault() async {
    try {
      final studentId = AuthRepository.instance.currentUser?.id ?? 'student';
      final vaultKey = StudentAssessmentScreen.vaultKeyFor(
        widget.assessment.id,
        studentId,
      );
      final pointerKey = StudentAssessmentScreen.activePointerKeyFor(studentId);
      AppDataCache.instance.invalidate(vaultKey);
      AppDataCache.instance.invalidate(pointerKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(vaultKey);
      await prefs.remove(pointerKey);
    } catch (e) {
      debugPrint('Notice clearing exam vault: $e');
    }
  }

  bool get _isSupabaseReady {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Fast 3-second heartbeat to detect disconnection within 5–10 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkConnectivityAndSessionStatus();
    });
  }

  Future<void> _checkConnectivityAndSessionStatus() async {
    if (!mounted || _currentStep != 1) return;
    if (!_isSupabaseReady) return;
    final studentId = AuthRepository.instance.currentUser?.id ?? 'student';
    try {
      final row = await SupabaseService().client
          .from('assessment_attempts')
          .select('status, active_session_id')
          .eq('assessment_id', widget.assessment.id)
          .eq('student_id', studentId)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));

      if (!mounted) return;
      if (_isOffline || _isConnectionFrozen) {
        final duration = _offlineSeconds;
        setState(() {
          _isOffline = false;
          _isConnectionFrozen = false;
          _offlineSeconds = 0;
          _reconnectWindowSeconds = 60;
          _isReconnectTimedOut = false;
        });
        if (duration >= 5) {
          _recordNetworkDisconnectionLog(duration);
        }
      }

      if (row != null) {
        final st = row['status']?.toString();
        if (st == 'disqualified') {
          _handleDisqualified(
            'This $_assessmentLabel session was disqualified by your proctor.',
          );
          return;
        } else if (_mySessionId != null &&
            row['active_session_id'] != null &&
            row['active_session_id'] != _mySessionId &&
            st == 'in_progress') {
          _handleDualDeviceDetected();
          return;
        }
      }

      if (_pendingOfflineSync && !_isSubmitting) {
        _submitAssessment(autoSubmit: true);
      }
    } catch (_) {
      if (!mounted) return;
      if (!_isOffline) {
        setState(() => _isOffline = true);
      }
    }
  }

  void _recordNetworkDisconnectionLog(int durationSeconds) {
    try {
      final user = AuthRepository.instance.currentUser;
      SupabaseService().client
          .from('anti_cheating_logs')
          .insert({
            'event_type': 'network_disconnected',
            'details':
                'Network disconnected for ${durationSeconds}s at question #${_currentQuestionIndex + 1} (Screen was frozen)',
            'student_id': user?.id,
            'assessment_id': widget.assessment.id,
            'event_at': DateTime.now().toUtc().toIso8601String(),
          })
          .catchError((_) {});
    } catch (_) {}
  }

  void _setupProctorChannel(String studentId) {
    try {
      _proctorChannel?.unsubscribe();
      _proctorChannel = SupabaseService().client
          .channel('student_proctor_${widget.assessment.id}_$studentId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'anti_cheating_logs',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'student_id',
              value: studentId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec['assessment_id'] == widget.assessment.id) {
                final ev = rec['event_type']?.toString();
                final details = rec['details']?.toString() ?? '';
                if (ev == 'kicked') {
                  _handleDisqualified(
                    details.isNotEmpty ? details : 'Violation of examination rules.',
                  );
                } else if (ev == 'reset' || ev == 'retake_authorized') {
                  _handleTeacherReset(
                    details.isNotEmpty ? details : 'Instructor authorized fresh attempt.',
                  );
                } else if (ev == 'force_submit') {
                  _handleTeacherForceSubmit(
                    details.isNotEmpty ? details : 'Instructor finalized submission.',
                  );
                }
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'assessment_attempts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'student_id',
              value: studentId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec['assessment_id'] == widget.assessment.id) {
                final st = rec['status']?.toString();
                if (st == 'disqualified') {
                  _handleDisqualified(
                    'This examination session was disqualified by your proctor.',
                  );
                } else if (st == 'auto_submitted') {
                  _handleTeacherForceSubmit(
                    'Instructor finalized submission.',
                  );
                } else if (st == 'reset') {
                  _handleTeacherReset(
                    'Instructor reset attempt.',
                  );
                } else if (_mySessionId != null &&
                    rec['active_session_id'] != null &&
                    rec['active_session_id'] != _mySessionId &&
                    rec['status'] == 'in_progress') {
                  _handleDualDeviceDetected();
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Notice setting up student proctor realtime channel: $e');
    }
  }

  void _handleDisqualified(String reason) {
    if (!mounted) return;
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _offlineRetryTimer?.cancel();
    _clearVault();
    setState(() {
      _isSubmitting = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: AppTheme.catRed),
            SizedBox(width: 8),
            Text(
              'Session Disqualified',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Your $_assessmentLabel session has been disqualified and terminated by the proctor.\n\nReason: $reason',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.catRed),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Return to Dashboard',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDualDeviceDetected() {
    if (!mounted) return;
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _offlineRetryTimer?.cancel();
    _clearVault();
    setState(() {
      _isSubmitting = true;
    });
    _recordViolation('Concurrent login session detected on another device');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.devices_other, color: AppTheme.catRed),
            SizedBox(width: 8),
            Text(
              'Session Conflict',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Another device has logged into this $_assessmentLabel session. Concurrent device testing is strictly prohibited for test security. Your session on this device has been halted.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.catRed),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Exit Assessment',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTeacherReset(String reason) {
    if (!mounted) return;
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _offlineRetryTimer?.cancel();
    _clearVault();

    // Reset local answering state
    setState(() {
      _studentAnswers.clear();
      for (final controller in _textControllers.values) {
        controller.clear();
      }
      _currentQuestionIndex = 0;
      _violations = 0;
      _violationLog.clear();
      _isSubmitting = false;
      _isConnectionFrozen = false;
      _isReconnectTimedOut = false;
      _secondsRemaining = widget.assessment.durationMinutes * 60;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: AppTheme.catOrange, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Session Reset by Instructor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your $_assessmentLabel session was reset by your instructor.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.catOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.catOrange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.catOrange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instructor authorized fresh attempt.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'All prior recorded answers have been wiped. You may now start your attempt fresh from Question 1.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) {
                setState(() {
                  _currentStep = 1;
                });
                _startTimer();
              }
            },
            child: const Text('Start Over Fresh', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleTeacherForceSubmit(String reason) {
    if (!mounted || _currentStep == 2) return;
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _offlineRetryTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session auto-submitted by instructor: $reason'),
        backgroundColor: AppTheme.catBlue,
        duration: const Duration(seconds: 4),
      ),
    );

    _submitAssessment(autoSubmit: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _offlineRetryTimer?.cancel();
    _proctorChannel?.unsubscribe();
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentStep == 1 && !_isSubmitting) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        _saveVault();
        _recordViolation('Tab/window focus lost (Backgrounded)');
      } else if (state == AppLifecycleState.resumed) {
        _recordViolation('Returned to assessment');
        _checkConnectivityAndSessionStatus();
      }
    }
  }

  void _startTimer({bool preserveStartTime = false}) {
    _timer?.cancel();
    if (!preserveStartTime || _startTime == null) {
      _startTime = DateTime.now();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_isOffline) {
          _offlineSeconds++;
          // Freeze screen after 6 seconds of disconnection (within strict 5–10s threshold)
          if (_offlineSeconds >= 6) {
            _isConnectionFrozen = true;
            if (_reconnectWindowSeconds > 0) {
              _reconnectWindowSeconds--;
            } else {
              _isReconnectTimedOut = true;
            }
          }
        }

        // Assessment duration only ticks down while screen is active and not frozen
        if (!_isConnectionFrozen && !_isReconnectTimedOut) {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            if (_secondsRemaining % 5 == 0) {
              _saveVault();
            }
          } else {
            _timer?.cancel();
            _submitAssessment(autoSubmit: true);
          }
        }
      });
    });
  }

  void _recordViolation(String event) {
    if (!mounted) return;
    setState(() {
      _violations++;
      _violationLog.add({'time': DateTime.now(), 'event': event});
    });

    // Background audit logging into anti_cheating_logs
    try {
      final user = AuthRepository.instance.currentUser;
      SupabaseService().client
          .from('anti_cheating_logs')
          .insert({
            'event_type': 'window_focus_lost',
            'details': '$event (Infraction #$_violations)',
            'student_id': user?.id,
            'assessment_id': widget.assessment.id,
            'event_at': DateTime.now().toUtc().toIso8601String(),
          })
          .catchError((_) {});
    } catch (_) {}

    // Strictly SILENT violation logging - Do NOT show warning pop-ups on the student's screen per user request
    // This allows organic tracking without panicking the student.
    // context: context,
    // title: 'Proctor Advisory Notice',
    // message:
    //    'Warning: $event.\nLoss of window focus has been recorded (#$_violations) for instructor review. Please remain on the assessment screen.',
    //);
  }

  Future<void> _submitAssessment({bool autoSubmit = false}) async {
    if (_isSubmitting) return;

    if (!autoSubmit) {
      // Find all unanswered questions
      final List<int> unansweredNumbers = [];
      int? firstUnansweredIndex;

      for (int i = 0; i < _orderedQuestions.length; i++) {
        final q = _orderedQuestions[i];
        final ans = (_studentAnswers[q.id] ?? '').trim();
        if (ans.isEmpty) {
          unansweredNumbers.add(i + 1);
          firstUnansweredIndex ??= i;
        }
      }

      if (unansweredNumbers.isNotEmpty) {
        // Automatically jump to the first unanswered question
        if (firstUnansweredIndex != null) {
          setState(() {
            _currentQuestionIndex = firstUnansweredIndex!;
          });
        }

        final itemSummary = unansweredNumbers.length <= 8
            ? 'Item(s): #${unansweredNumbers.join(', #')}'
            : 'Item(s): #${unansweredNumbers.take(8).join(', #')} and ${unansweredNumbers.length - 8} more';

        AppModals.showWarningDialog(
          context: context,
          title: 'Unanswered Questions Remaining',
          message:
              'You cannot submit the $_assessmentLabel yet because you have ${unansweredNumbers.length} unanswered question(s).\n\n$itemSummary\n\nPlease answer all questions before submitting. For identification questions where you do not know the answer, you may enter "N/A".',
        );
        return;
      }
    }

    _timer?.cancel();
    setState(() => _isSubmitting = true);

    // Auto-check against answer key (unanswered or N/A answers yield 0 points)
    double scoreEarned = 0;
    for (final q in _orderedQuestions) {
      final rawStudentAns = (_studentAnswers[q.id] ?? '').trim();
      final isMatching =
          q.type == QuestionType.matching &&
          q.matchingPairs.isNotEmpty &&
          q.matchingPairs.entries.every(
            (pair) => rawStudentAns.toLowerCase().contains(
              '${pair.key.toLowerCase()}=${pair.value.toLowerCase()}',
            ),
          );
      if (q.matchesStudentAnswer(rawStudentAns) || isMatching) {
        scoreEarned += q.points;
      }
    }

    final durationTaken = _startTime != null
        ? DateTime.now().difference(_startTime!).inMinutes
        : 0;

    final student =
        AuthRepository.instance.currentUser ??
        UserModel(
          id: 'temp_student',
          username: 'student',
          fullName: 'Student',
          email: '',
          role: UserRole.student,
        );

    // Persist attempt record, question responses, and submissions to Supabase
    if (_isSupabaseReady) {
      try {
      final user = AuthRepository.instance.currentUser;
      final studentId = user?.id ?? student.id;
      final attemptStatus = autoSubmit ? 'auto_submitted' : 'submitted';
      final client = SupabaseService().client;

      // Verify assessment still exists in DB (stale-cache guard if teacher deleted it)
      final existingAssess = await client
          .from('digital_assessments')
          .select(
            'id, is_archived, subject_offering_id, assessment_type, grading_category',
          )
          .eq('id', widget.assessment.id)
          .maybeSingle();

      if (existingAssess == null || existingAssess['is_archived'] == true) {
        AppDataCache.instance.invalidatePrefix('student_dashboard_');
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        await AppModals.showWarningDialog(
          context: context,
          title: 'Assessment Unavailable',
          message:
              'This assessment has been removed by your teacher and can no longer accept submissions.',
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final submittedUtc = DateTime.now().toUtc();
      var startedUtc = (_startTime ?? DateTime.now()).toUtc();
      if (startedUtc.isAfter(submittedUtc)) {
        startedUtc = submittedUtc;
      }

      // 1. Upsert assessment_attempts with score_earned & conflict target
      final attemptRes = await client
          .from('assessment_attempts')
          .upsert({
            'assessment_id': widget.assessment.id,
            'student_id': studentId,
            'attempt_number': 1,
            'status': attemptStatus,
            'score_earned': scoreEarned,
            'started_at': startedUtc.toIso8601String(),
            'submitted_at': submittedUtc.toIso8601String(),
          }, onConflict: 'assessment_id,student_id,attempt_number')
          .select('id')
          .maybeSingle();

      final attemptId = attemptRes?['id']?.toString();

      // 2. Persist individual question responses for review & item analysis
      if (attemptId != null && attemptId.isNotEmpty) {
        await client
            .from('assessment_responses')
            .delete()
            .eq('attempt_id', attemptId);

        final responsesToInsert = <Map<String, dynamic>>[];
        for (final q in _orderedQuestions) {
          final studentAns = (_studentAnswers[q.id] ?? '').trim();
          final isMatching =
              q.type == QuestionType.matching &&
              q.matchingPairs.isNotEmpty &&
              q.matchingPairs.entries.every(
                (pair) => studentAns.toLowerCase().contains(
                  '${pair.key.toLowerCase()}=${pair.value.toLowerCase()}',
                ),
              );
          final isCorrect = isMatching || q.matchesStudentAnswer(studentAns);
          final pointsEarned = isCorrect ? q.points : 0.0;

          responsesToInsert.add({
            'attempt_id': attemptId,
            'question_id': q.id,
            'text_response': studentAns,
            'is_correct': isCorrect,
            'points_earned': pointsEarned,
            'answered_at': submittedUtc.toIso8601String(),
          });
        }

        if (responsesToInsert.isNotEmpty) {
          await client.from('assessment_responses').insert(responsesToInsert);
        }
      }

      // 3. Upsert into student_classwork_submissions if mirror row exists & sync Gradebook
      final cwRow = await client
          .from('classwork_items')
          .select(
            'id, subject_offering_id, term_number, gradebook_column_index, grading_category',
          )
          .eq('id', widget.assessment.id)
          .maybeSingle();

      if (cwRow != null) {
        await client.from('student_classwork_submissions').upsert({
          'classwork_id': widget.assessment.id,
          'student_id': studentId,
          'status': 'submitted',
          'score': scoreEarned,
          'submitted_at': submittedUtc.toIso8601String(),
        }, onConflict: 'classwork_id,student_id');
      }

      // Sync auto-graded score to gradebook_term_sheets as Single Source of Truth
      try {
        final offeringId =
            cwRow?['subject_offering_id']?.toString() ??
            existingAssess['subject_offering_id']?.toString() ??
            widget.assessment.subjectOfferingId;
        final termNum =
            (cwRow?['term_number'] as num?)?.toInt() ??
            widget.assessment.termNumber;
        final assessType =
            existingAssess['assessment_type']?.toString().toLowerCase() ??
            widget.assessment.examType;
        final colIdx =
            (cwRow?['gradebook_column_index'] as num?)?.toInt() ??
            widget.assessment.gradebookColumnIndex ??
            (assessType == 'st1'
                ? 1
                : (assessType == 'st2'
                      ? 2
                      : (assessType == 'term_exam' ? 3 : null)));
        final catKey =
            cwRow?['grading_category']?.toString().toLowerCase() ??
            existingAssess['grading_category']?.toString().toLowerCase() ??
            (widget.assessment.isExam ? 'ex' : 'ww');

        if (offeringId != null && offeringId.isNotEmpty && colIdx != null) {
          final sheet =
              await SubjectRepository.instance.getGradebookTermSheet(
                offeringId,
                termNum,
              ) ??
              <String, dynamic>{};
          final scores = Map<String, dynamic>.from(
            sheet['scores'] as Map? ?? {},
          );
          final studentScores = Map<String, dynamic>.from(
            scores[studentId] as Map? ?? {},
          );
          final catScores = Map<String, dynamic>.from(
            studentScores[catKey] as Map? ?? {},
          );
          final colKey = catKey == 'ex'
              ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
              : colIdx.toString();
          catScores[colKey] = scoreEarned;
          studentScores[catKey] = catScores;
          scores[studentId] = studentScores;
          sheet['scores'] = scores;

          final hps = Map<String, dynamic>.from(sheet['hps'] as Map? ?? {});
          final catHps = Map<String, dynamic>.from(hps[catKey] as Map? ?? {});
          if (catHps[colKey] == null) {
            catHps[colKey] = widget.assessment.totalPoints.toInt();
            hps[catKey] = catHps;
            sheet['hps'] = hps;
          }

          await SubjectRepository.instance.saveGradebookTermSheet(
            offeringId,
            termNum,
            sheet,
          );
          TeacherGradebookTab.gradebookRefreshNotifier.value++;
        }
      } catch (gbErr) {
        debugPrint('Gradebook assessment score sync notice: $gbErr');
      }

      // 4. Log session_submitted in anti_cheating_logs for proctoring audit
      try {
        await client.from('anti_cheating_logs').insert({
          'event_type': 'session_submitted',
          'details':
              'Submitted ${widget.assessment.isExam ? "examination" : "quiz"} (Score: ${scoreEarned.toInt()}/${widget.assessment.totalPoints.toInt()})',
          'student_id': studentId,
          'assessment_id': widget.assessment.id,
          'event_at': submittedUtc.toIso8601String(),
        });
      } catch (_) {}

      // Invalidate relevant caches
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('gradebook_');
      await _clearVault();
      _heartbeatTimer?.cancel();
      _offlineRetryTimer?.cancel();
      if (mounted) {
        setState(() {
          _isOffline = false;
          _pendingOfflineSync = false;
        });
      }
    } catch (e) {
      debugPrint('Error saving assessment attempt and scores: $e');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isOffline = true;
        _pendingOfflineSync = true;
      });
      _saveVault();
      _offlineRetryTimer?.cancel();
      _offlineRetryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && _pendingOfflineSync && !_isSubmitting) {
          _submitAssessment(autoSubmit: true);
        }
      });
      return;
    }
  } else {
    await _clearVault();
    _heartbeatTimer?.cancel();
    _offlineRetryTimer?.cancel();
    if (mounted) {
      setState(() {
        _isOffline = false;
        _pendingOfflineSync = false;
      });
    }
  }

  if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _currentStep = 2;
    });

    _submittedResult = AssessmentResultModel(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      assessmentId: widget.assessment.id,
      studentId: student.id,
      studentName: student.fullName,
      submittedAt: DateTime.now(),
      durationTakenMinutes: durationTaken,
      violationCount: _violations,
      violationLog: List.from(_violationLog),
      answers: Map.from(_studentAnswers),
      scoreEarned: scoreEarned,
      totalPoints: widget.assessment.totalPoints,
      isReleased: widget.assessment.resultsReleased,
      needsTeacherReview: widget.assessment.isExam,
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment.title),
        backgroundColor: widget.assessment.isExam
            ? AppTheme.catRed
            : Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: PopScope(
        canPop: _currentStep != 1,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          AppModals.showWarningDialog(
            context: context,
            title: '$_assessmentTitleLabel In Progress',
            message:
                'You cannot leave the assessment while the $_assessmentLabel timer is actively running. Please complete or submit your $_assessmentLabel.',
          );
        },
        child: Stack(
          children: [
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_currentStep == 0) _buildRulesView(),
                      if (_currentStep == 1) _buildAnsweringView(),
                      if (_currentStep == 2) _buildResultView(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesView() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.assessment.isExam ? Icons.description : Icons.quiz,
                  color: widget.assessment.isExam
                      ? AppTheme.catRed
                      : Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assessment.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Subject: ${widget.assessment.subject} • Section: ${widget.assessment.section}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (widget.assessment.description.trim().isNotEmpty) ...[
              const Text(
                'Teacher Instructions & Guidelines:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ExpandableInstructionsText(
                  text: widget.assessment.description,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Assessment Rules & Guidelines:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRuleBullet(
              'Time Limit: ${widget.assessment.durationMinutes} minutes timer.',
            ),
            _buildRuleBullet(
              'Total Questions: ${_orderedQuestions.length} items (${widget.assessment.totalPoints.toInt()} total points).',
            ),
            _buildRuleBullet(
              'Mandatory Answers: Blank questions cannot be submitted manually. For identification questions where you do not know the answer, please enter "N/A".',
            ),
            _buildRuleBullet(
              'Internet Requirement: Active internet connection required throughout the assessment.',
            ),
            _buildRuleBullet(
              'Anti-Cheating Policy: Switching tabs or minimizing the browser will be recorded as a violation for teacher review.',
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'I have read and understood the assessment rules and guidelines.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                value: _rulesAccepted,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) => setState(() => _rulesAccepted = val ?? false),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.assessment.isExam
                      ? AppTheme.catRed
                      : Theme.of(context).colorScheme.primary,
                ),
                onPressed: _rulesAccepted
                    ? () async {
                        final now = DateTime.now();
                        if (now.isBefore(widget.assessment.scheduleDate)) {
                          AppModals.showErrorDialog(
                            context: context,
                            title: 'Assessment Locked',
                            message: 'You cannot start this assessment yet. It is scheduled to begin later.',
                          );
                          return;
                        }

                        final user = AuthRepository.instance.currentUser;
                        final studentId = user?.id ?? 'student';
                        // Check prior attempt status to prevent multiple submissions or bypass
                        if (_isSupabaseReady) {
                          try {
                            final client = SupabaseService().client;
                            final prior = await client
                                .from('assessment_attempts')
                                .select('status, active_session_id')
                                .eq('assessment_id', widget.assessment.id)
                                .eq('student_id', studentId)
                                .maybeSingle();

                            if (prior != null) {
                              final st = prior['status']?.toString();
                              if (st == 'submitted' || st == 'auto_submitted') {
                                if (!mounted) return;
                                AppModals.showWarningDialog(
                                  context: context,
                                  title: 'Assessment Already Submitted',
                                  message: 'You have already completed and submitted this assessment.',
                                );
                                return;
                              } else if (st == 'disqualified') {
                                if (!mounted) return;
                                AppModals.showErrorDialog(
                                  context: context,
                                  title: 'Session Disqualified',
                                  message: 'This assessment attempt was previously disqualified by your proctor.',
                                );
                                return;
                              }
                            }

                            _mySessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
                            await client.from('assessment_attempts').upsert({
                              'assessment_id': widget.assessment.id,
                              'student_id': studentId,
                              'attempt_number': 1,
                              'status': 'in_progress',
                              'active_session_id': _mySessionId,
                              'started_at': DateTime.now().toUtc().toIso8601String(),
                            }, onConflict: 'assessment_id,student_id,attempt_number');
                          } catch (sessErr) {
                            debugPrint('Notice establishing active exam session: $sessErr');
                          }
                        }

                        if (!mounted) return;
                        setState(() => _currentStep = 1);
                        _startTimer();
                        _startHeartbeat();
                        _saveVault();
                        if (_isSupabaseReady) {
                          try {
                            SupabaseService().client
                                .from('anti_cheating_logs')
                                .insert({
                                  'event_type': 'session_started',
                                  'details': 'Started assessment session',
                                  'student_id': user?.id,
                                  'assessment_id': widget.assessment.id,
                                  'event_at': DateTime.now()
                                      .toUtc()
                                      .toIso8601String(),
                                })
                                .catchError((_) {});
                          } catch (_) {}
                        }
                      }
                    : null,
                child: const Text(
                  'START ASSESSMENT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnsweringView() {
    final q = _orderedQuestions[_currentQuestionIndex];
    final totalQ = _orderedQuestions.length;
    final answeredCount = _orderedQuestions
        .where((item) => (_studentAnswers[item.id] ?? '').trim().isNotEmpty)
        .length;
    final unansweredCount = totalQ - answeredCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSubmit = answeredCount == totalQ;

    return Expanded(
      child: Column(
        children: [
          // Top Navigation Bar inside assessment: Question indicator, Answered/Unanswered chips, Timer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Question Counter, Answered Badge, Unanswered Badge, Timer
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Question ${_currentQuestionIndex + 1} of $totalQ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        // Answered Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: answeredCount == totalQ
                                ? AppTheme.catGreen.withValues(alpha: 0.12)
                                : AppTheme.catOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: answeredCount == totalQ
                                  ? AppTheme.catGreen.withValues(alpha: 0.3)
                                  : AppTheme.catOrange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 13,
                                color: answeredCount == totalQ
                                    ? AppTheme.catGreen
                                    : AppTheme.catOrange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$answeredCount / $totalQ answered',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: answeredCount == totalQ
                                      ? AppTheme.catGreen
                                      : AppTheme.catOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Unanswered Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: unansweredCount > 0
                                ? AppTheme.catOrange.withValues(alpha: 0.12)
                                : AppTheme.catSlate.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: unansweredCount > 0
                                  ? AppTheme.catOrange.withValues(alpha: 0.3)
                                  : AppTheme.catSlate.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                unansweredCount > 0
                                    ? Icons.radio_button_unchecked
                                    : Icons.task_alt,
                                size: 13,
                                color: unansweredCount > 0
                                    ? AppTheme.catOrange
                                    : AppTheme.catSlate,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$unansweredCount unanswered',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: unansweredCount > 0
                                      ? AppTheme.catOrange
                                      : AppTheme.catSlate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: AppTheme.catOrange,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_formatTime(_secondsRemaining)} remaining',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.catOrange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Violations: $_violations',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppTheme.catRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Horizontal Question Indicator Bar (Scrollable Dot/Pill Navigator)
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: totalQ,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (ctx, idx) {
                      final itemQ = _orderedQuestions[idx];
                      final isAnswered =
                          (_studentAnswers[itemQ.id] ?? '').trim().isNotEmpty;
                      final isCurrent = idx == _currentQuestionIndex;

                      Color pillBg;
                      Color pillBorder;
                      Color pillText;

                      if (isCurrent) {
                        pillBg = Theme.of(context).colorScheme.primary;
                        pillBorder = Theme.of(context).colorScheme.primary;
                        pillText = Theme.of(context).colorScheme.onPrimary;
                      } else if (isAnswered) {
                        pillBg = AppTheme.catGreen.withValues(alpha: 0.12);
                        pillBorder = AppTheme.catGreen.withValues(alpha: 0.4);
                        pillText = AppTheme.catGreen;
                      } else {
                        pillBg = isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFFFFFFF);
                        pillBorder = Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.18);
                        pillText = Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.7);
                      }

                      return InkWell(
                        onTap: () {
                          setState(() => _currentQuestionIndex = idx);
                          _saveVault();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: pillBorder,
                              width: isCurrent ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAnswered && !isCurrent) ...[
                                const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppTheme.catGreen,
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                'Q${idx + 1}',
                                style: TextStyle(
                                  color: pillText,
                                  fontWeight: isCurrent
                                      ? FontWeight.w800
                                      : FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if ((_isOffline || _pendingOfflineSync) && !_isConnectionFrozen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _pendingOfflineSync
                    ? AppTheme.catRed.withValues(alpha: 0.14)
                    : AppTheme.catOrange.withValues(alpha: 0.14),
                border: Border(
                  bottom: BorderSide(
                    color: _pendingOfflineSync
                        ? AppTheme.catRed.withValues(alpha: 0.35)
                        : AppTheme.catOrange.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _pendingOfflineSync
                            ? AppTheme.catRed
                            : AppTheme.catOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 18,
                    color: _pendingOfflineSync
                        ? AppTheme.catRed
                        : AppTheme.catOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pendingOfflineSync
                          ? 'No or poor internet connection — Reconnecting to submit your $_assessmentLabel... Your answers are safely saved on this device.'
                          : 'Unstable internet connection — Reconnecting... (${_offlineSeconds}s)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _pendingOfflineSync
                            ? AppTheme.catRed
                            : AppTheme.catOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _pendingOfflineSync
                          ? AppTheme.catRed
                          : AppTheme.catOrange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_pendingOfflineSync) {
                              _submitAssessment(autoSubmit: true);
                            } else {
                              _checkConnectivityAndSessionStatus();
                            }
                          },
                    icon: const Icon(Icons.sync_rounded, size: 15),
                    label: Text(
                      _pendingOfflineSync ? 'Retry Sync Now' : 'Reconnect',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Question Body and Pagination Bar wrapped in Stack with Connection Freeze Overlay
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${q.points.round()} ${q.points.round() == 1 ? 'Point' : 'Points'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        q.type.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q.questionText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Choices or text input
                  if (q.type == QuestionType.multipleChoice ||
                      q.type == QuestionType.trueFalse) ...[
                    ...q.choices.map((choice) {
                      final isSelected = _studentAnswers[q.id] == choice;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.08)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.12),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: RadioListTile<String>(
                            title: Text(
                              choice,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            value: choice,
                            // ignore: deprecated_member_use
                            groupValue: _studentAnswers[q.id],
                            activeColor: Theme.of(context).colorScheme.primary,
                            // ignore: deprecated_member_use
                            onChanged: (val) {
                              setState(() {
                                _studentAnswers[q.id] = val ?? '';
                                _saveVault();
                              });
                            },
                          ),
                        ),
                      );
                    }),
                  ] else if (q.type == QuestionType.matching) ...[
                    Column(
                      children: q.matchingPairs.keys.map((left) {
                        final options = q.matchingPairs.values.toList();
                        final current = _studentAnswers[q.id]
                            ?.split('|')
                            .firstWhere(
                              (entry) => entry.startsWith('$left='),
                              orElse: () => '',
                            )
                            .split('=')
                            .skip(1)
                            .join('=');
                        return DropdownButtonFormField<String>(
                          initialValue: options.contains(current)
                              ? current
                              : null,
                          decoration: InputDecoration(labelText: left),
                          items: options
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final answers = (_studentAnswers[q.id] ?? '')
                                .split('|')
                                .where(
                                  (entry) =>
                                      entry.isNotEmpty &&
                                      !entry.startsWith('$left='),
                                )
                                .toList();
                            answers.add('$left=$value');
                            setState(() {
                              _studentAnswers[q.id] = answers.join('|');
                              _saveVault();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Your Answer:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                final ctrl = _getTextController(q.id);
                                ctrl.text = 'N/A';
                                ctrl.selection = TextSelection.fromPosition(
                                  const TextPosition(offset: 3),
                                );
                                setState(() {
                                  _studentAnswers[q.id] = 'N/A';
                                  _saveVault();
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.not_interested,
                                      size: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Insert 'N/A' (I don't know)",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _getTextController(q.id),
                          onChanged: (val) {
                            setState(() {
                              _studentAnswers[q.id] = val;
                              _saveVault();
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Type your answer here',
                            hintText: "Enter answer (or type 'N/A' if unknown)",
                            helperText: "Required: Blank answers are prohibited on submission. If you do not know the answer, enter 'N/A'.",
                            helperMaxLines: 2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Question Bottom Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous'),
                  onPressed: _currentQuestionIndex > 0
                      ? () {
                          setState(() => _currentQuestionIndex--);
                          _saveVault();
                        }
                      : null,
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      canSubmit
                          ? 'All $totalQ items answered'
                          : '$unansweredCount of $totalQ remaining',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: canSubmit ? AppTheme.catGreen : AppTheme.catOrange,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_currentQuestionIndex < totalQ - 1)
                  AppPrimaryButton(
                    label: 'Next',
                    icon: Icons.arrow_forward,
                    height: 40,
                    width: 110,
                    onPressed: () {
                      setState(() => _currentQuestionIndex++);
                      _saveVault();
                    },
                  )
                else
                  AppPrimaryButton(
                    label: _isSubmitting
                        ? 'Submitting...'
                        : (canSubmit
                            ? 'Submit Assessment'
                            : 'Submit ($unansweredCount Left)'),
                    backgroundColor: canSubmit
                        ? AppTheme.catGreen
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                    icon: canSubmit
                        ? Icons.check_circle
                        : Icons.lock_outline,
                    height: 40,
                    width: canSubmit ? 180 : 195,
                    onPressed: (canSubmit && !_isSubmitting)
                        ? () => _submitAssessment(autoSubmit: false)
                        : null,
                  ),
              ],
            ),
          ),
                  ],
                ),
                if (_isConnectionFrozen)
                  _buildConnectionFrozenOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionFrozenOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: (isDark ? const Color(0xF20F172A) : const Color(0xF2FFFFFF)),
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.catRed.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.catRed.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        size: 44,
                        color: AppTheme.catRed,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Connection Lost — $_assessmentTitleLabel Paused',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Offline answering is prohibited to maintain test integrity and prevent unauthorized offline assistance. Question content is temporarily frozen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isReconnectTimedOut) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.catRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.catRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_clock, size: 20, color: AppTheme.catRed),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Reconnection grace window expired (60s). This session has been halted for instructor review.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.catRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.catOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.catOrange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.catOrange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Reconnection Window: ${_reconnectWindowSeconds}s remaining',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.catOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.catRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _checkConnectivityAndSessionStatus,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Check Connection Now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final student =
        AuthRepository.instance.currentUser ??
        UserModel(
          id: 'temp_student',
          username: 'student',
          fullName: 'Student',
          email: '',
          role: UserRole.student,
        );
    final result =
        _submittedResult ??
        AssessmentResultModel(
          id: 'res_empty',
          assessmentId: widget.assessment.id,
          studentId: student.id,
          studentName: student.fullName,
          submittedAt: DateTime.now(),
          durationTakenMinutes: 10,
          answers: {},
          scoreEarned: 0,
          totalPoints: widget.assessment.totalPoints,
          isReleased: widget.assessment.resultsReleased,
        );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReleased = widget.assessment.resultsReleased || result.isReleased;

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.catGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 56,
                color: AppTheme.catGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$_assessmentTitleLabel Completed & Submitted!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.assessment.title,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            // ALWAYS DISPLAY STUDENT'S OFFICIAL SCORE CARD IMMEDIATELY
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF0F8A48).withValues(alpha: isDark ? 0.4 : 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F8A48).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Score Obtained: ${result.scoreEarned.round()} / ${result.totalPoints.round()} pts',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Percentage: ${result.percentage.round()}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // ANSWER KEY REVIEW SECTION: CONTROLLED STRICTLY BY TEACHER TOGGLE
                  if (isReleased) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        StudentExamReviewModal.show(
                          context,
                          assessmentId: widget.assessment.id,
                          title: widget.assessment.title,
                          subjectName: widget.assessment.subject,
                          maxScore: widget.assessment.totalPoints,
                        );
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text(
                        'Review Questions & Answer Key',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.catOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.catOrange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 18, color: AppTheme.catOrange),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Answer Key Locked: Your teacher has not released the item-by-item answer key review yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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

            const SizedBox(height: 32),
            AppPrimaryButton(
              label: 'Return to Student Portal',
              onPressed: () => Navigator.of(context).pop(),
              width: 220,
            ),
          ],
        ),
      ),
    );
  }
}
