import 'package:flutter/widgets.dart';
import '../models/proctor_violation_log.dart';

/// Service responsible for tracking true tab-switches and window unfocus
/// during an online quiz or major examination.
///
/// CRITICAL PROJECT RULE:
/// In-app popups, confirmation dialogs, dropdown overlays, or bottom sheets
/// MUST NOT be counted as violations.
/// Only TRUE tab switches / app un-focus (AppLifecycleState.paused,
/// web visibilitychange to 'hidden', or desktop window unfocus) are recorded.
class StudentLifecycleWatcher with WidgetsBindingObserver {
  final String attemptId;
  final String studentId;
  final String studentName;
  final void Function(ProctorViolationLog violation)? onViolationDetected;

  DateTime? _unfocusStartTime;
  bool _isDisposed = false;
  int _internalDialogDepth = 0;

  StudentLifecycleWatcher({
    required this.attemptId,
    required this.studentId,
    required this.studentName,
    this.onViolationDetected,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Call this when displaying an internal in-app dialog/popup to ensure
  /// it is shielded from false-positive detection.
  void notifyDialogOpened() {
    _internalDialogDepth++;
  }

  /// Call this when an internal in-app dialog/popup is closed.
  void notifyDialogClosed() {
    if (_internalDialogDepth > 0) {
      _internalDialogDepth--;
    }
  }

  bool get isInsideDialog => _internalDialogDepth > 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    // If app becomes hidden or paused, learner left the assessment screen
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _recordUnfocusStart();
    } else if (state == AppLifecycleState.resumed) {
      _recordUnfocusEnd(ProctorViolationType.appBackgrounded);
    }
  }

  void _recordUnfocusStart() {
    _unfocusStartTime ??= DateTime.now();
  }

  void _recordUnfocusEnd(ProctorViolationType type) {
    if (_unfocusStartTime == null) return;

    final duration = DateTime.now().difference(_unfocusStartTime!).inSeconds;
    _unfocusStartTime = null;

    // Filter out micro-glitches under 1 second if inside internal dialog
    if (isInsideDialog && duration < 2) return;

    final violation = ProctorViolationLog(
      id: 'violation_${DateTime.now().millisecondsSinceEpoch}',
      attemptId: attemptId,
      studentId: studentId,
      studentName: studentName,
      violationType: type,
      durationSeconds: duration < 1 ? 1 : duration,
      timestamp: DateTime.now(),
    );

    onViolationDetected?.call(violation);
  }

  /// Explicit event trigger when window blur is captured on Flutter Web/Desktop
  void onExternalWindowBlur() {
    if (_isDisposed || isInsideDialog) return;
    _recordUnfocusStart();
  }

  /// Explicit event trigger when window focus returns
  void onExternalWindowFocus() {
    if (_isDisposed) return;
    _recordUnfocusEnd(ProctorViolationType.tabSwitch);
  }

  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}
