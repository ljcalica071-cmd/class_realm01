import 'dart:async';
import '../models/proctor_violation_log.dart';
import '../models/student_live_proctor_state.dart';

/// Service managing the live proctoring channel between teacher and students
/// during an active quiz or examination.
class TeacherProctorChannelService {
  final String assessmentId;
  final StreamController<List<StudentLiveProctorState>> _stateController =
      StreamController<List<StudentLiveProctorState>>.broadcast();

  final Map<String, StudentLiveProctorState> _studentStates = {};

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
      final updatedViolations = List<ProctorViolationLog>.from(current.violations)
        ..add(violation);
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
  void kickStudent(String studentId, String reason) {
    final current = _studentStates[studentId];
    if (current != null) {
      _studentStates[studentId] = current.copyWith(
        status: ProctorSessionStatus.kicked,
        kickedReason: reason,
        lastActiveAt: DateTime.now(),
      );
      _broadcast();
    }
  }

  /// Teacher Action: Authorize retake for student who suffered technical glitch
  /// Resets violation count and clears kicked state
  void authorizeRetake(String studentId) {
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
    _stateController.close();
  }
}
