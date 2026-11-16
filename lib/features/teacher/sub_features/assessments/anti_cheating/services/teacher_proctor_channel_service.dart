import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';

import '../models/proctor_violation_log.dart';
import '../models/student_live_proctor_state.dart';

/// Service managing the live proctoring channel between teacher and students
/// during an active quiz or examination with real-time Supabase network synchronization.
class TeacherProctorChannelService {
  final String assessmentId;
  final VoidCallback? onRealtimeEvent;
  final StreamController<List<StudentLiveProctorState>> _stateController =
      StreamController<List<StudentLiveProctorState>>.broadcast();

  final Map<String, StudentLiveProctorState> _studentStates = {};
  final Map<String, DateTime> _studentResetAt = {};
  RealtimeChannel? _subscriptionChannel;

  TeacherProctorChannelService({
    required this.assessmentId,
    this.onRealtimeEvent,
  });

  Stream<List<StudentLiveProctorState>> get studentStatesStream =>
      _stateController.stream;

  List<StudentLiveProctorState> get currentStates =>
      _studentStates.values.toList();

  DateTime? getResetAt(String studentId) => _studentResetAt[studentId];

  /// Initialize channel with the enrolled student roster
  void initializeRoster(List<Map<String, dynamic>> enrolledStudents) {
    for (final s in enrolledStudents) {
      final studentId = s['id']?.toString() ?? '';
      if (studentId.isEmpty) continue;
      final existing = _studentStates[studentId];
      final resetAt = _studentResetAt[studentId];
      final isRecentlyReset =
          resetAt != null &&
          DateTime.now().toUtc().difference(resetAt).inSeconds < 8;

      var resolvedStatus =
          (s['status'] as ProctorSessionStatus?) ??
          existing?.status ??
          ProctorSessionStatus.notStarted;

      if (isRecentlyReset &&
          (resolvedStatus == ProctorSessionStatus.submitted ||
              resolvedStatus == ProctorSessionStatus.notStarted)) {
        resolvedStatus = ProctorSessionStatus.retakeRequested;
      }

      final resolvedScore = resolvedStatus == ProctorSessionStatus.submitted
          ? (s['score'] as num?)?.toDouble()
          : null;

      _studentStates[studentId] = StudentLiveProctorState(
        studentId: studentId,
        studentName: s['name']?.toString() ?? existing?.studentName ?? 'Student',
        lrn: s['lrn']?.toString() ?? existing?.lrn ?? 'N/A',
        section: s['section']?.toString() ?? existing?.section ?? '',
        status: resolvedStatus,
        violationCount: isRecentlyReset
            ? 0
            : ((s['violation_count'] as num?)?.toInt() ??
                  existing?.violationCount ??
                  0),
        violations: isRecentlyReset
            ? const []
            : ((s['violations'] as List<ProctorViolationLog>?) ??
                  existing?.violations ??
                  const []),
        lastActiveAt: existing?.lastActiveAt,
        kickedReason: isRecentlyReset ? null : existing?.kickedReason,
        gender: s['gender']?.toString() ?? existing?.gender,
        lastName: s['last_name']?.toString() ?? existing?.lastName,
        firstName: s['first_name']?.toString() ?? existing?.firstName,
        middleName: s['middle_name']?.toString() ?? existing?.middleName,
        score: resolvedScore,
        totalPoints:
            (s['total_points'] as num?)?.toDouble() ?? existing?.totalPoints,
        isEntryAllowed: s['is_entry_allowed'] != false,
        isMissing: s['is_missing'] == true,
        currentQuestionNumber:
            (s['current_question_number'] as num?)?.toInt() ??
            existing?.currentQuestionNumber,
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

      // Reset violation counters before replaying chronological logs so every
      // call is idempotent, accurate, and reflects resets cleanly.
      for (final entry in _studentStates.entries.toList()) {
        _studentStates[entry.key] = entry.value.copyWith(
          violationCount: 0,
          violations: const [],
        );
      }

      for (final raw in (rows as List? ?? [])) {
        final r = Map<String, dynamic>.from(raw as Map);
        _handleLogRecord(r, isReplay: true);
      }

      // Enforce invariant: any student not in `submitted` status cannot carry a stale score
      for (final entry in _studentStates.entries.toList()) {
        if (entry.value.status != ProctorSessionStatus.submitted &&
            entry.value.score != null) {
          _studentStates[entry.key] = entry.value.copyWith(clearScore: true);
        }
      }

      _broadcast();
    } catch (e) {
      debugPrint('Notice loading historical proctor violations: $e');
    }
  }

  /// Subscribe to live Realtime Supabase changes on `anti_cheating_logs`, `assessment_attempts`, and `student_classwork_submissions`
  void startListening() {
    try {
      if (_subscriptionChannel != null) return;
      _subscriptionChannel = SupabaseService().client
          .channel('proctor_monitor_$assessmentId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'anti_cheating_logs',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'assessment_id',
              value: assessmentId,
            ),
            callback: (payload) {
              if (payload.newRecord.isNotEmpty) {
                _handleLogRecord(payload.newRecord);
                _broadcast();
              }
              onRealtimeEvent?.call();
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
              if (payload.eventType == PostgresChangeEvent.delete) {
                final oldStudentId =
                    payload.oldRecord['student_id']?.toString() ?? '';
                if (oldStudentId.isNotEmpty) {
                  _handleAttemptDeleted(oldStudentId);
                }
              } else if (payload.newRecord.isNotEmpty) {
                _handleAttemptRecord(payload.newRecord);
              }
              _broadcast();
              onRealtimeEvent?.call();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'student_classwork_submissions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'classwork_id',
              value: assessmentId,
            ),
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                final oldStudentId =
                    payload.oldRecord['student_id']?.toString() ?? '';
                if (oldStudentId.isNotEmpty) {
                  final cur = _studentStates[oldStudentId];
                  if (cur != null &&
                      cur.status != ProctorSessionStatus.inProgress) {
                    _studentStates[oldStudentId] = cur.copyWith(
                      clearScore: true,
                    );
                  }
                }
              } else if (payload.newRecord.isNotEmpty) {
                final rec = payload.newRecord;
                final studentId = rec['student_id']?.toString() ?? '';
                final statusStr =
                    rec['status']?.toString().toLowerCase() ?? '';
                final scoreVal = (rec['score'] as num?)?.toDouble();
                if (studentId.isNotEmpty &&
                    (statusStr == 'submitted' || statusStr == 'graded')) {
                  registerStudentSubmitted(studentId, score: scoreVal);
                }
              }
              _broadcast();
              onRealtimeEvent?.call();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Notice starting realtime proctor listener: $e');
    }
  }

  void _handleAttemptDeleted(String studentId) {
    final current = _studentStates[studentId];
    if (current == null) return;
    _studentResetAt[studentId] = DateTime.now().toUtc();
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

  void _handleAttemptRecord(Map<String, dynamic> record) {
    final studentId = record['student_id']?.toString() ?? '';
    if (studentId.isEmpty) return;
    final current = _studentStates[studentId];
    if (current == null) return;

    final rawStatus = record['status']?.toString().toLowerCase() ?? '';
    final scoreVal = (record['score_earned'] as num?)?.toDouble();
    final qIndex = (record['current_question_index'] as num?)?.toInt();

    if (rawStatus == 'in_progress') {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.inProgress,
        clearScore: true,
        isMissing: false,
        currentQuestionNumber: qIndex != null ? qIndex + 1 : current.currentQuestionNumber,
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
      _studentResetAt[studentId] = DateTime.now().toUtc();
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

  void _handleLogRecord(Map<String, dynamic> record, {bool isReplay = false}) {
    final studentId = record['student_id']?.toString() ?? '';
    if (studentId.isEmpty) return;

    final eventType = record['event_type']?.toString().toLowerCase() ?? '';
    final details =
        record['details']?.toString() ??
        (record['event_details'] is Map
            ? record['event_details']['details']?.toString() ?? ''
            : '');
    final parsedUtc = record['event_at'] != null
        ? DateTime.tryParse(record['event_at'].toString())?.toUtc()
        : null;
    final timestamp = parsedUtc?.toLocal() ?? DateTime.now();

    if (eventType == 'session_started') {
      registerStudentStarted(
        studentId,
        forceRestart: true,
        broadcastUpdate: !isReplay,
      );
    } else if (eventType == 'session_submitted') {
      final resetAt = _studentResetAt[studentId];
      if (resetAt != null &&
          parsedUtc != null &&
          !parsedUtc.isAfter(resetAt)) {
        return;
      }
      double? parsedScore;
      final scoreMatch = RegExp(r'Score:\s*(\d+(?:\.\d+)?)').firstMatch(details);
      if (scoreMatch != null) {
        parsedScore = double.tryParse(scoreMatch.group(1) ?? '');
      }
      registerStudentSubmitted(
        studentId,
        score: parsedScore,
        broadcastUpdate: !isReplay,
      );
    } else if (eventType == 'kicked') {
      kickStudent(studentId, details, writeToDb: false, broadcastUpdate: !isReplay);
    } else if (eventType == 'retake_authorized' || eventType == 'reset') {
      if (parsedUtc != null) {
        _studentResetAt[studentId] = parsedUtc;
      } else {
        _studentResetAt[studentId] = DateTime.now().toUtc();
      }
      authorizeRetake(
        studentId,
        writeToDb: false,
        broadcastUpdate: !isReplay,
      );
    } else if (eventType == 'entry_allowed') {
      toggleAllowStudent(
        studentId,
        true,
        writeToDb: false,
        broadcastUpdate: !isReplay,
      );
    } else if (eventType == 'entry_disallowed') {
      toggleAllowStudent(
        studentId,
        false,
        writeToDb: false,
        broadcastUpdate: !isReplay,
      );
    } else if (eventType == 'window_focus_lost' ||
        eventType.contains('tab_switch') ||
        eventType.contains('background') ||
        eventType.contains('blur') ||
        eventType.contains('focus')) {
      final resetAt = _studentResetAt[studentId];
      if (resetAt != null &&
          parsedUtc != null &&
          !parsedUtc.isAfter(resetAt)) {
        return;
      }
      // Focus lost / blur / tab switch violation (excludes network_disconnected, force_submit, etc.)
      final current = _studentStates[studentId];
      final vType = eventType.contains('background')
          ? ProctorViolationType.appBackgrounded
          : (eventType.contains('blur')
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
      recordViolation(violation, broadcastUpdate: !isReplay);
    }
  }

  /// Register student starting the test
  void registerStudentStarted(
    String studentId, {
    bool forceRestart = false,
    bool broadcastUpdate = true,
  }) {
    final current = _studentStates[studentId];
    if (current != null) {
      if (!forceRestart && current.status == ProctorSessionStatus.submitted) {
        return;
      }
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.inProgress,
        clearScore: true,
        isMissing: false,
        lastActiveAt: DateTime.now(),
      );
      if (broadcastUpdate) _broadcast();
    }
  }

  /// Record a detected tab switch / blur violation
  void recordViolation(
    ProctorViolationLog violation, {
    bool broadcastUpdate = true,
  }) {
    final current = _studentStates[violation.studentId];
    if (current != null) {
      // Check for duplicate violation id
      if (current.violations.any((v) => v.id == violation.id)) return;
      // Guard against duplicate twin events emitted within 2 seconds of each other
      if (current.violations.any(
        (v) => violation.timestamp.difference(v.timestamp).inSeconds.abs() < 2,
      )) {
        return;
      }
      final updatedViolations = List<ProctorViolationLog>.from(
        current.violations,
      )..add(violation);
      _studentStates[violation.studentId] = current.copyWith(
        violationCount: current.violationCount + 1,
        violations: updatedViolations,
        lastActiveAt: DateTime.now(),
      );
      if (broadcastUpdate) _broadcast();
    }
  }

  /// Teacher Action: Kick student out for academic dishonesty
  /// Sets status to kicked and locks session
  void kickStudent(
    String studentId,
    String reason, {
    bool writeToDb = true,
    bool broadcastUpdate = true,
  }) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.kicked,
        kickedReason: reason,
        lastActiveAt: DateTime.now(),
      );
      if (broadcastUpdate) _broadcast();
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
  /// Resets violation count, clears old score, and sends reset signal to student device
  Future<void> authorizeRetake(
    String studentId, {
    String reason = 'Instructor granted test retake / reset',
    bool writeToDb = true,
    bool broadcastUpdate = true,
  }) async {
    _studentResetAt[studentId] = DateTime.now().toUtc();
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
      if (broadcastUpdate) _broadcast();
    }

    if (writeToDb) {
      await _resetStudentInDatabase(studentId, reason);
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

      // 2. Delete the attempt row so the student can start a clean attempt
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

      // 4. Delete prior violation and submission logs for this student so old scores/infractions cannot replay
      try {
        await client
            .from('anti_cheating_logs')
            .delete()
            .eq('assessment_id', assessmentId)
            .eq('student_id', studentId)
            .inFilter('event_type', [
              'window_focus_lost',
              'tab_switch',
              'app_backgrounded',
              'window_blur',
              'session_started',
              'session_submitted',
              'kicked',
            ]);
      } catch (_) {}

      // 5. Clear old score from gradebook_term_sheets so Gradebook & Proctoring stay 100% in sync
      try {
        final cwRow = await client
            .from('classwork_items')
            .select(
              'subject_offering_id, term_number, gradebook_column_index, grading_category',
            )
            .eq('id', assessmentId)
            .maybeSingle();
        final daRow = await client
            .from('digital_assessments')
            .select('subject_offering_id, assessment_type, grading_category')
            .eq('id', assessmentId)
            .maybeSingle();

        final offeringId =
            cwRow?['subject_offering_id']?.toString() ??
            daRow?['subject_offering_id']?.toString();
        final termNum = (cwRow?['term_number'] as num?)?.toInt() ?? 1;
        final assessType =
            daRow?['assessment_type']?.toString().toLowerCase();
        final colIdx =
            (cwRow?['gradebook_column_index'] as num?)?.toInt() ??
            (assessType == 'st1'
                ? 1
                : (assessType == 'st2'
                      ? 2
                      : (assessType == 'term_exam' ? 3 : null)));
        final catKey =
            cwRow?['grading_category']?.toString().toLowerCase() ??
            daRow?['grading_category']?.toString().toLowerCase() ??
            (assessType != null && assessType != 'quiz' ? 'ex' : 'ww');

        if (offeringId != null && offeringId.isNotEmpty && colIdx != null) {
          AppDataCache.instance.invalidatePrefix('gradebook_');
          final termSheet = await SubjectRepository.instance
              .getGradebookTermSheet(offeringId, termNum);
          if (termSheet != null && termSheet['scores'] is Map) {
            final scoresMap = Map<String, dynamic>.from(
              termSheet['scores'] as Map,
            );
            if (scoresMap[studentId] is Map) {
              final studentVal = Map<String, dynamic>.from(
                scoresMap[studentId] as Map,
              );
              if (studentVal[catKey] is Map) {
                final catScores = Map<String, dynamic>.from(
                  studentVal[catKey] as Map,
                );
                final colKey = catKey == 'ex'
                    ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
                    : colIdx.toString();
                catScores.remove(colKey);
                catScores.remove(colIdx.toString());
                catScores.remove((colIdx - 1).toString());
                studentVal[catKey] = catScores;
                scoresMap[studentId] = studentVal;
                termSheet['scores'] = scoresMap;
                await SubjectRepository.instance.saveGradebookTermSheet(
                  offeringId,
                  termNum,
                  termSheet,
                );
                try {
                  await LocalStorageService.clearGradebookSheet(
                    offeringId,
                    termNum,
                  );
                } catch (_) {}
              }
            }
          }
          AppDataCache.instance.invalidatePrefix('gradebook_');
          AppDataCache.instance.invalidatePrefix('teacher_assessments_');
          AppDataCache.instance.invalidatePrefix('teacher_activities_');
          AppDataCache.instance.invalidatePrefix('student_dashboard_');
          TeacherGradebookTab.gradebookRefreshNotifier.value++;
        }
      } catch (gbErr) {
        debugPrint('Notice clearing gradebook score on retake: $gbErr');
      }

      // 6. Insert reset event into anti_cheating_logs so active student client receives signal
      final resetNowUtc = DateTime.now().toUtc();
      _studentResetAt[studentId] = resetNowUtc;
      await client.from('anti_cheating_logs').insert({
        'assessment_id': assessmentId,
        'student_id': studentId,
        'event_type': 'reset',
        'details': reason,
        'event_at': resetNowUtc.toIso8601String(),
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
    bool broadcastUpdate = true,
  }) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        isEntryAllowed: allow,
        lastActiveAt: DateTime.now(),
      );
      if (broadcastUpdate) _broadcast();
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

  /// Register student submission
  void registerStudentSubmitted(
    String studentId, {
    double? score,
    bool broadcastUpdate = true,
  }) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.submitted,
        score: score ?? current.score,
        isMissing: false,
        lastActiveAt: DateTime.now(),
      );
      if (broadcastUpdate) _broadcast();
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
