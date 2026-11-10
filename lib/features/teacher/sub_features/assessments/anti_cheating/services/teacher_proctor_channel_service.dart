import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/supabase_service.dart';

import '../models/proctor_violation_log.dart';
import '../models/student_live_proctor_state.dart';

/// Service managing the live proctoring channel between teacher and students
/// during an active quiz or examination with real-time Supabase network synchronization.
class TeacherProctorChannelService {
  final String assessmentId;
  final StreamController<List<StudentLiveProctorState>> _stateController =
      StreamController<List<StudentLiveProctorState>>.broadcast();

  final Map<String, StudentLiveProctorState> _studentStates = {};
  RealtimeChannel? _subscriptionChannel;

  TeacherProctorChannelService({required this.assessmentId});

  Stream<List<StudentLiveProctorState>> get studentStatesStream =>
      _stateController.stream;

  List<StudentLiveProctorState> get currentStates =>
      _studentStates.values.toList();

  /// Initialize channel with the enrolled student roster
  void initializeRoster(List<Map<String, dynamic>> enrolledStudents) {
    for (final s in enrolledStudents) {
      final studentId = s['id']?.toString() ?? '';
      if (studentId.isEmpty) continue;
      _studentStates[studentId] = StudentLiveProctorState(
        studentId: studentId,
        studentName: s['name']?.toString() ?? 'Student',
        lrn: s['lrn']?.toString() ?? 'N/A',
        section: s['section']?.toString() ?? '',
        status: (s['status'] as ProctorSessionStatus?) ?? ProctorSessionStatus.notStarted,
        violationCount: (s['violation_count'] as num?)?.toInt() ?? 0,
        gender: s['gender']?.toString(),
        lastName: s['last_name']?.toString(),
        firstName: s['first_name']?.toString(),
        middleName: s['middle_name']?.toString(),
        score: (s['score'] as num?)?.toDouble(),
        totalPoints: (s['total_points'] as num?)?.toDouble(),
        isEntryAllowed: s['is_entry_allowed'] != false,
        isMissing: s['is_missing'] == true,
        currentQuestionNumber: (s['current_question_number'] as num?)?.toInt(),
      );
    }
    _broadcast();
  }

  /// Load any violation logs or session records already present in the database
  Future<void> loadHistoricalViolations() async {
    try {
      final client = SupabaseService().client;
      final rows = await client
          .from('anti_cheating_logs')
          .select()
          .eq('assessment_id', assessmentId)
          .order('event_at', ascending: true);

      for (final raw in (rows as List? ?? [])) {
        final r = Map<String, dynamic>.from(raw as Map);
        _handleLogRecord(r);
      }
      _broadcast();
    } catch (e) {
      debugPrint('Notice loading historical proctor violations: $e');
    }
  }

  /// Subscribe to live Realtime Supabase changes on `anti_cheating_logs` and `assessment_attempts`
  void startListening() {
    try {
      if (_subscriptionChannel != null) return;
      _subscriptionChannel = SupabaseService().client
          .channel('proctor_monitor_$assessmentId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'anti_cheating_logs',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'assessment_id',
              value: assessmentId,
            ),
            callback: (payload) {
              _handleLogRecord(payload.newRecord);
              _broadcast();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'assessment_attempts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'assessment_id',
              value: assessmentId,
            ),
            callback: (payload) {
              _handleAttemptRecord(payload.newRecord);
              _broadcast();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Notice starting realtime proctor listener: $e');
    }
  }

  void _handleAttemptRecord(Map<String, dynamic> record) {
    final studentId = record['student_id']?.toString() ?? '';
    if (studentId.isEmpty) return;
    final current = _studentStates[studentId];
    if (current == null) return;

    final rawStatus = record['status']?.toString().toLowerCase() ?? '';
    final scoreVal = (record['score_earned'] as num?)?.toDouble();

    if (rawStatus == 'in_progress') {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.inProgress,
        isMissing: false,
        lastActiveAt: DateTime.now(),
      );
    } else if (rawStatus == 'submitted' || rawStatus == 'auto_submitted') {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.submitted,
        score: scoreVal ?? current.score,
        isMissing: false,
        lastActiveAt: DateTime.now(),
      );
    } else if (rawStatus == 'disqualified') {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.kicked,
        score: 0,
        lastActiveAt: DateTime.now(),
      );
    } else if (rawStatus == 'reset') {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.retakeRequested,
        violationCount: 0,
        violations: const [],
        clearScore: true,
        clearKickedReason: true,
        isMissing: false,
        isEntryAllowed: true,
        lastActiveAt: DateTime.now(),
      );
    }
  }

  void _handleLogRecord(Map<String, dynamic> record) {
    final studentId = record['student_id']?.toString() ?? '';
    if (studentId.isEmpty) return;

    final eventType = record['event_type']?.toString().toLowerCase() ?? '';
    final details =
        record['details']?.toString() ??
        (record['event_details'] is Map
            ? record['event_details']['details']?.toString() ?? ''
            : '');
    final timestamp = record['event_at'] != null
        ? DateTime.tryParse(record['event_at'].toString())?.toLocal() ??
              DateTime.now()
        : DateTime.now();

    if (eventType == 'session_started') {
      registerStudentStarted(studentId);
    } else if (eventType == 'session_submitted') {
      double? parsedScore;
      final scoreMatch = RegExp(r'Score:\s*(\d+(?:\.\d+)?)').firstMatch(details);
      if (scoreMatch != null) {
        parsedScore = double.tryParse(scoreMatch.group(1) ?? '');
      }
      registerStudentSubmitted(studentId, score: parsedScore);
    } else if (eventType == 'kicked') {
      kickStudent(studentId, details, writeToDb: false);
    } else if (eventType == 'retake_authorized' || eventType == 'reset') {
      authorizeRetake(studentId, writeToDb: false);
    } else if (eventType == 'force_submit') {
      forceSubmitStudent(studentId, writeToDb: false);
    } else if (eventType == 'entry_allowed') {
      toggleAllowStudent(studentId, true, writeToDb: false);
    } else if (eventType == 'entry_disallowed') {
      toggleAllowStudent(studentId, false, writeToDb: false);
    } else {
      // Focus lost / blur / tab switch / network violation
      final current = _studentStates[studentId];
      final vType = eventType.contains('background')
          ? ProctorViolationType.appBackgrounded
          : (eventType.contains('blur') || eventType.contains('focus')
                ? ProctorViolationType.windowBlur
                : ProctorViolationType.tabSwitch);

      final violation = ProctorViolationLog(
        id:
            record['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        attemptId:
            record['assessment_attempt_id']?.toString() ?? 'att_$studentId',
        studentId: studentId,
        studentName: current?.studentName ?? 'Learner',
        violationType: vType,
        durationSeconds: 0,
        timestamp: timestamp,
      );
      recordViolation(violation);
    }
  }

  /// Register student starting the test
  void registerStudentStarted(String studentId) {
    final current = _studentStates[studentId];
    if (current != null) {
      // Don't overwrite a submitted status if replaying an older start log
      if (current.status == ProctorSessionStatus.submitted) return;
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.inProgress,
        isMissing: false,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }
  }

  /// Record a detected tab switch / blur violation
  void recordViolation(ProctorViolationLog violation) {
    final current = _studentStates[violation.studentId];
    if (current != null) {
      // Check for duplicate violation id
      if (current.violations.any((v) => v.id == violation.id)) return;
      final updatedViolations = List<ProctorViolationLog>.from(
        current.violations,
      )..add(violation);
      _studentStates[violation.studentId] = current.copyWith(
        violationCount: current.violationCount + 1,
        violations: updatedViolations,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }
  }

  /// Teacher Action: Kick student out for academic dishonesty
  /// Sets status to kicked and locks session
  void kickStudent(String studentId, String reason, {bool writeToDb = true}) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.kicked,
        kickedReason: reason,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }

    if (writeToDb) {
      try {
        final client = SupabaseService().client;
        client
            .from('anti_cheating_logs')
            .insert({
              'assessment_id': assessmentId,
              'student_id': studentId,
              'event_type': 'kicked',
              'details': reason,
              'event_at': DateTime.now().toUtc().toIso8601String(),
            })
            .catchError((_) {});

        client
            .from('assessment_attempts')
            .update({
              'status': 'disqualified',
              'score_earned': 0,
            })
            .eq('assessment_id', assessmentId)
            .eq('student_id', studentId)
            .catchError((_) {});
      } catch (_) {}
    }
  }

  /// Teacher Action: Authorize retake / reset session for student
  /// Resets violation count and sends reset signal to student device
  void authorizeRetake(
    String studentId, {
    String reason = 'Instructor granted test retake / reset',
    bool writeToDb = true,
  }) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.retakeRequested,
        violationCount: 0,
        violations: const [],
        clearKickedReason: true,
        currentQuestionNumber: 1,
        clearScore: true,
        isEntryAllowed: true,
        isMissing: false,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }

    if (writeToDb) {
      unawaited(_resetStudentInDatabase(studentId, reason));
    }
  }

  Future<void> _resetStudentInDatabase(String studentId, String reason) async {
    try {
      final client = SupabaseService().client;
      // 1. Delete existing responses linked to this student's attempt(s)
      final attempts = await client
          .from('assessment_attempts')
          .select('id')
          .eq('assessment_id', assessmentId)
          .eq('student_id', studentId);
      final attemptIds = (attempts as List? ?? [])
          .map((a) => a['id']?.toString())
          .whereType<String>()
          .toList();
      if (attemptIds.isNotEmpty) {
        await client
            .from('assessment_responses')
            .delete()
            .inFilter('attempt_id', attemptIds);
      }

      // 2. Delete the attempt row so the student can start a clean attempt (or update if active)
      await client
          .from('assessment_attempts')
          .delete()
          .eq('assessment_id', assessmentId)
          .eq('student_id', studentId);

      // 3. Also delete any classwork submission mirror for this student
      try {
        await client
            .from('student_classwork_submissions')
            .delete()
            .eq('classwork_id', assessmentId)
            .eq('student_id', studentId);
      } catch (_) {}

      // 4. Insert reset event into anti_cheating_logs so active student client receives signal
      await client.from('anti_cheating_logs').insert({
        'assessment_id': assessmentId,
        'student_id': studentId,
        'event_type': 'reset',
        'details': reason,
        'event_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Notice resetting student attempt in database: $e');
    }
  }

  /// Teacher Action: Allow or disallow student taking test
  void toggleAllowStudent(
    String studentId,
    bool allow, {
    bool writeToDb = true,
  }) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        isEntryAllowed: allow,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }

    if (writeToDb) {
      try {
        SupabaseService().client
            .from('anti_cheating_logs')
            .insert({
              'assessment_id': assessmentId,
              'student_id': studentId,
              'event_type': allow ? 'entry_allowed' : 'entry_disallowed',
              'details': allow
                  ? 'Instructor granted test access'
                  : 'Instructor disallowed test access',
              'event_at': DateTime.now().toUtc().toIso8601String(),
            })
            .catchError((_) {});
      } catch (_) {}
    }
  }

  /// Teacher Action: Force auto-submit assessment for a specific student
  /// Only the targeted student is submitted; others continue normally.
  void forceSubmitStudent(
    String studentId, {
    String reason = 'Instructor triggered auto-submission',
    bool writeToDb = true,
  }) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.submitted,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }

    if (writeToDb) {
      try {
        SupabaseService().client
            .from('anti_cheating_logs')
            .insert({
              'assessment_id': assessmentId,
              'student_id': studentId,
              'event_type': 'force_submit',
              'details': reason,
              'event_at': DateTime.now().toUtc().toIso8601String(),
            })
            .catchError((_) {});

        SupabaseService().client
            .from('assessment_attempts')
            .update({
              'status': 'auto_submitted',
            })
            .eq('assessment_id', assessmentId)
            .eq('student_id', studentId)
            .catchError((_) {});
      } catch (_) {}
    }
  }

  /// Register student submission
  void registerStudentSubmitted(String studentId, {double? score}) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.submitted,
        score: score ?? current.score,
        isMissing: false,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }
  }

  void _broadcast() {
    if (!_stateController.isClosed) {
      _stateController.add(_studentStates.values.toList());
    }
  }

  void dispose() {
    if (_subscriptionChannel != null) {
      try {
        SupabaseService().client.removeChannel(_subscriptionChannel!);
      } catch (_) {}
      _subscriptionChannel = null;
    }
    _stateController.close();
  }
}
