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
          .select('assessment_id, started_at')
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
          final qRows =
              (rawAssess['assessment_questions'] as List? ?? [])
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
  void handleTeacherResetForTesting(String reason) =>
      _handleTeacherReset(reason);

  @visibleForTesting
  void handleTeacherForceSubmitForTesting(String reason) =>
      _handleTeacherForceSubmit(reason);

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
          .select('status, started_at')
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
          _mySessionId ??=
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
          .select('status')
          .eq('assessment_id', widget.assessment.id)
          .eq('student_id', studentId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

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
        }
      }

      if (_pendingOfflineSync && !_isSubmitting) {
        _submitAssessment(autoSubmit: true);
      }
    } on PostgrestException catch (_) {
      // Database/schema/RLS response means the device IS connected to the server
      if (!mounted) return;
      if (_isOffline || _isConnectionFrozen) {
        setState(() {
          _isOffline = false;
          _isConnectionFrozen = false;
          _offlineSeconds = 0;
          _reconnectWindowSeconds = 60;
          _isReconnectTimedOut = false;
        });
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
                    details.isNotEmpty
                        ? details
                        : 'Violation of examination rules.',
                  );
                } else if (ev == 'reset' || ev == 'retake_authorized') {
                  _handleTeacherReset(
                    details.isNotEmpty
                        ? details
                        : 'Instructor authorized fresh attempt.',
                  );
                } else if (ev == 'force_submit') {
                  _handleTeacherForceSubmit(
                    details.isNotEmpty
                        ? details
                        : 'Instructor finalized submission.',
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
                  _handleTeacherForceSubmit('Instructor finalized submission.');
                } else if (st == 'reset') {
                  _handleTeacherReset('Instructor reset attempt.');
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
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
            Icon(
              Icons.restart_alt_rounded,
              color: AppTheme.catOrange,
              size: 22,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Session Reset by Instructor',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
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
                border: Border.all(
                  color: AppTheme.catOrange.withValues(alpha: 0.3),
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
            child: const Text(
              'Start Over Fresh',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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

    AppTopToast.info(context, 'Session auto-submitted by instructor: $reason');

    _submitAssessment(autoSubmit: true);
  }

  @override
  void dispose() {
    if (_currentStep == 1 && !_isSubmitting) {
      _saveVault();
    }
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
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        _saveVault();
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) {
          _recordViolation('Tab/window focus lost (Backgrounded)');
        }
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
            message: 'This assessment has been removed by your teacher and can no longer accept submissions.',
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
          try {
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
              final isCorrect =
                  isMatching || q.matchesStudentAnswer(studentAns);
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
              try {
                await client
                    .from('assessment_responses')
                    .insert(responsesToInsert);
              } catch (insErr) {
                // Fallback without text_response column in case schema lacks it
                debugPrint('assessment_responses insert fallback: $insErr');
                final fallbackRows = responsesToInsert
                    .map(
                      (r) => {
                        'attempt_id': r['attempt_id'],
                        'question_id': r['question_id'],
                        'is_correct': r['is_correct'],
                        'points_earned': r['points_earned'],
                        'answered_at': r['answered_at'],
                      },
                    )
                    .toList();
                await client.from('assessment_responses').insert(fallbackRows);
              }
            }
          } catch (respErr) {
            debugPrint('assessment_responses persistence notice: $respErr');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 50,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: onSurface,
        titleSpacing: 4,
        title: Text(
          widget.assessment.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: onSurface.withValues(alpha: 0.08)),
        ),
      ),
      body: PopScope(
        canPop: _currentStep != 1,
        onPopInvokedWithResult: (didPop, _) {
          // Non-intrusive: prevent back navigation while answering without showing a blocking modal
        },
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540),
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: isMobile ? 12 : 20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: onSurface.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (_currentStep == 0)
                    _buildRulesView(isMobile, primaryColor, onSurface),
                  if (_currentStep == 1)
                    _buildAnsweringView(isMobile, primaryColor, onSurface),
                  if (_currentStep == 2)
                    _buildResultView(isMobile, primaryColor, onSurface),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRulesView(bool isMobile, Color primaryColor, Color onSurface) {
    return Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 18 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.assessment.isExam
                        ? Icons.assignment_outlined
                        : Icons.quiz_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assessment.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.assessment.subject} • ${widget.assessment.section}',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (widget.assessment.description.trim().isNotEmpty) ...[
              Text(
                'Teacher Instructions & Guidelines',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: onSurface.withValues(alpha: 0.08)),
                ),
                child: ExpandableInstructionsText(
                  text: widget.assessment.description,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Assessment Rules & Guidelines:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 10),
            _buildRuleBullet(
              'Time Limit: ${widget.assessment.durationMinutes} minutes timer.',
            ),
            _buildRuleBullet(
              'Total Questions: ${_orderedQuestions.length} items (${widget.assessment.totalPoints.toInt()} total points).',
            ),
            _buildRuleBullet(
              'Mandatory Answers: Blank questions cannot be submitted manually. For identification questions where you do not know the answer, enter "N/A".',
            ),
            _buildRuleBullet(
              'Internet Requirement: Active internet connection required throughout the assessment.',
            ),
            _buildRuleBullet(
              'Anti-Cheating Policy: Switching tabs or minimizing the browser will be recorded as a violation for teacher review.',
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'I have read and understood the assessment rules and guidelines.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: onSurface,
                  ),
                ),
                value: _rulesAccepted,
                activeColor: primaryColor,
                onChanged: (val) =>
                    setState(() => _rulesAccepted = val ?? false),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                        if (_isSupabaseReady) {
                          try {
                            final client = SupabaseService().client;
                            final prior = await client
                                .from('assessment_attempts')
                                .select('status')
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

                            _mySessionId =
                                'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
                            await client.from('assessment_attempts').upsert(
                              {
                                'assessment_id': widget.assessment.id,
                                'student_id': studentId,
                                'attempt_number': 1,
                                'status': 'in_progress',
                                'started_at': DateTime.now()
                                    .toUtc()
                                    .toIso8601String(),
                              },
                              onConflict:
                                  'assessment_id,student_id,attempt_number',
                            );
                          } catch (sessErr) {
                            debugPrint(
                              'Notice establishing active exam session: $sessErr',
                            );
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnsweringView(
    bool isMobile,
    Color primaryColor,
    Color onSurface,
  ) {
    final q = _orderedQuestions[_currentQuestionIndex];
    final totalQ = _orderedQuestions.length;
    final answeredCount = _orderedQuestions
        .where((item) => (_studentAnswers[item.id] ?? '').trim().isNotEmpty)
        .length;
    final unansweredCount = totalQ - answeredCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSubmit = answeredCount == totalQ;
    final isLowTime = _secondsRemaining <= 60;

    return Expanded(
      child: Stack(
        children: [
          Column(
            children: [
              // 30% Secondary Surface Header Bar: Question indicator, Answered/Unanswered chips, Timer
              Container(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 14 : 20,
                  10,
                  isMobile ? 14 : 20,
                  10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1} of $totalQ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: onSurface,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$answeredCount / $totalQ answered',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            if (unansweredCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$unansweredCount left',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: onSurface.withValues(alpha: 0.65),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: isLowTime ? AppTheme.catRed : primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(_secondsRemaining),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isLowTime
                                    ? AppTheme.catRed
                                    : onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Violations: $_violations',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: _violations > 0
                                    ? AppTheme.catRed
                                    : onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Compact Question Pill Navigator
                    SizedBox(
                      height: 28,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: totalQ,
                        separatorBuilder: (_, _) => const SizedBox(width: 5),
                        itemBuilder: (ctx, idx) {
                          final itemQ = _orderedQuestions[idx];
                          final isAnswered = (_studentAnswers[itemQ.id] ?? '')
                              .trim()
                              .isNotEmpty;
                          final isCurrent = idx == _currentQuestionIndex;

                          Color pillBg;
                          Color pillBorder;
                          Color pillText;

                          if (isCurrent) {
                            pillBg = primaryColor;
                            pillBorder = primaryColor;
                            pillText = Theme.of(context).colorScheme.onPrimary;
                          } else if (isAnswered) {
                            pillBg = primaryColor.withValues(alpha: 0.12);
                            pillBorder = primaryColor.withValues(alpha: 0.35);
                            pillText = primaryColor;
                          } else {
                            pillBg = isDark
                                ? const Color(0xFF111827)
                                : Colors.white;
                            pillBorder = onSurface.withValues(alpha: 0.14);
                            pillText = onSurface.withValues(alpha: 0.65);
                          }

                          return InkWell(
                            onTap: () {
                              setState(() => _currentQuestionIndex = idx);
                              _saveVault();
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: pillBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: pillBorder,
                                  width: isCurrent ? 1.4 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAnswered && !isCurrent) ...[
                                    Icon(
                                      Icons.check,
                                      size: 11,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  Text(
                                    'Q${idx + 1}',
                                    style: TextStyle(
                                      color: pillText,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w600,
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

              // Question Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 22,
                    isMobile ? 16 : 24,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${q.points.round()} ${q.points.round() == 1 ? 'Point' : 'Points'}',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            q.type.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q.questionText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Choices or text input
                      if (q.type == QuestionType.multipleChoice ||
                          q.type == QuestionType.trueFalse) ...[
                        ...q.choices.map((choice) {
                          final isSelected = _studentAnswers[q.id] == choice;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _studentAnswers[q.id] = choice;
                                  _saveVault();
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor.withValues(alpha: 0.08)
                                      : (isDark
                                            ? const Color(0xFF1F2937)
                                                  .withValues(alpha: 0.5)
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryColor
                                        : onSurface.withValues(alpha: 0.12),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? primaryColor
                                              : onSurface.withValues(
                                                  alpha: 0.35,
                                                ),
                                          width: isSelected ? 5 : 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        choice,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.35,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: onSurface,
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
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: primaryColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.not_interested,
                                          size: 12,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Insert 'N/A' (I don't know)",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _getTextController(q.id),
                              style: const TextStyle(fontSize: 13.5),
                              onChanged: (val) {
                                setState(() {
                                  _studentAnswers[q.id] = val;
                                  _saveVault();
                                });
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                labelText: 'Type your answer here',
                                labelStyle: const TextStyle(fontSize: 13),
                                hintText:
                                    "Enter answer (or type 'N/A' if unknown)",
                                hintStyle: const TextStyle(fontSize: 12.5),
                                helperText: "Blank answers are prohibited on submission. Enter 'N/A' if unknown.",
                                helperMaxLines: 2,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
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

              // Unboxed Previous / Next Navigation Row (directly in layout flow, no bottom box)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  6,
                  isMobile ? 16 : 24,
                  isMobile ? 14 : 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _currentQuestionIndex > 0
                              ? onSurface.withValues(alpha: 0.85)
                              : onSurface.withValues(alpha: 0.3),
                          side: BorderSide.none,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 15),
                        label: const Text(
                          'Previous',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _currentQuestionIndex > 0
                            ? () {
                                setState(() => _currentQuestionIndex--);
                                _saveVault();
                              }
                            : null,
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          canSubmit
                              ? 'All $totalQ answered'
                              : '${_currentQuestionIndex + 1} / $totalQ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_currentQuestionIndex < totalQ - 1)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _currentQuestionIndex++);
                            _saveVault();
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 15),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canSubmit
                                ? primaryColor
                                : onSurface.withValues(alpha: 0.12),
                            foregroundColor: canSubmit
                                ? Theme.of(context).colorScheme.onPrimary
                                : onSurface.withValues(alpha: 0.45),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            canSubmit
                                ? Icons.check_circle_outline_rounded
                                : Icons.lock_outline_rounded,
                            size: 15,
                          ),
                          label: Text(
                            _isSubmitting
                                ? 'Submitting...'
                                : (canSubmit
                                      ? 'Submit Assessment'
                                      : 'Submit ($unansweredCount Left)'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: (canSubmit && !_isSubmitting)
                              ? () => _submitAssessment(autoSubmit: false)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Calm Freeze + Loading Indicator when genuinely disconnected or syncing
          if (_isConnectionFrozen || _pendingOfflineSync)
            _buildConnectionFrozenOverlay(primaryColor, onSurface),
        ],
      ),
    );
  }

  Widget _buildConnectionFrozenOverlay(Color primaryColor, Color onSurface) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: (isDark ? const Color(0xCC111827) : const Color(0xCCFFFFFF)),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: onSurface.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _pendingOfflineSync
                      ? 'Syncing your responses...'
                      : 'Reconnecting to server...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your progress is safely saved. Please wait a moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultView(bool isMobile, Color primaryColor, Color onSurface) {
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
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 42,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_assessmentTitleLabel Completed & Submitted!',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.assessment.title,
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Score Card in 60-30-10 Palette
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1F2937)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: onSurface.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    'Score Obtained: ${result.scoreEarned.round()} / ${result.totalPoints.round()} pts',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Percentage: ${result.percentage.round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  if (isReleased) ...[
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                        icon: const Icon(Icons.fact_check_outlined, size: 16),
                        label: const Text(
                          'Review Questions & Answer Key',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 15,
                          color: onSurface.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Answer Key Locked: Your teacher has not released the item-by-item answer key review yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Return to Student Portal',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
