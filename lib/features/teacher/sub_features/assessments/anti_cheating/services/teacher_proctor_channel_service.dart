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
  void initializeRoster(List<Map<String, String>> enrolledStudents) {
    for (final s in enrolledStudents) {
      final studentId = s['id'] ?? '';
      if (studentId.isEmpty) continue;
      _studentStates[studentId] = StudentLiveProctorState(
        studentId: studentId,
        studentName: s['name'] ?? 'Student',
        lrn: s['lrn'] ?? 'N/A',
        section: s['section'] ?? '',
        status: ProctorSessionStatus.notStarted,
        violationCount: 0,
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

  /// Subscribe to live Realtime Supabase inserts on `anti_cheating_logs`
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
          .subscribe();
    } catch (e) {
      debugPrint('Notice starting realtime proctor listener: $e');
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
      registerStudentSubmitted(studentId);
    } else if (eventType == 'kicked') {
      kickStudent(studentId, details, writeToDb: false);
    } else if (eventType == 'retake_authorized') {
      authorizeRetake(studentId, writeToDb: false);
    } else {
      // Focus lost / blur / tab switch violation
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
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.inProgress,
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

  /// Teacher Action: Authorize retake for student who suffered technical glitch
  /// Resets violation count and clears kicked state
  void authorizeRetake(String studentId, {bool writeToDb = true}) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.retakeRequested,
        violationCount: 0,
        violations: const [],
        kickedReason: null,
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
              'event_type': 'retake_authorized',
              'details': 'Instructor granted test retake',
              'event_at': DateTime.now().toUtc().toIso8601String(),
            })
            .catchError((_) {});
      } catch (_) {}
    }
  }

  /// Register student submission
  void registerStudentSubmitted(String studentId) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.submitted,
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
