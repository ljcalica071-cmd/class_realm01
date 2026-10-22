import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:class_realm/core/utils/logout_helper.dart';
import 'package:class_realm/core/theme/app_theme.dart';

/// Global Session Activity Tracker Widget (Edge Cases #1, #4, #15, #16, #18)
/// Handles:
/// - 30-minute Wall-Clock Inactivity Auto-Logout (resilient to OS sleep/wake)
/// - 28-minute Inactivity Warning Prompt ("Are you still there?")
/// - 60-second Resilient Silent Heartbeat to Supabase `user_session_logs`
/// - Real-Time Maintenance Mode Gatekeeping & Forced Logout
class SessionActivityTracker extends StatefulWidget {
  final Widget child;
  const SessionActivityTracker({super.key, required this.child});

  static _SessionActivityTrackerState? _state;

  /// External keep-alive hook for video/lecture viewers
  static void keepAlive() {
    _state?._recordInteraction();
  }

  @override
  State<SessionActivityTracker> createState() => _SessionActivityTrackerState();
}

class _SessionActivityTrackerState extends State<SessionActivityTracker>
    with WidgetsBindingObserver {
  DateTime _lastInteractionAt = DateTime.now();
  Timer? _tickerTimer;
  Timer? _heartbeatTimer;
  RealtimeChannel? _maintenanceChannel;

  bool _isWarningDialogShowing = false;
  String? _activeSessionLogId;
  DateTime _sessionStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    SessionActivityTracker._state = this;
    WidgetsBinding.instance.addObserver(this);

    _lastInteractionAt = LocalStorageService.getLastInteraction() ?? DateTime.now();
    LocalStorageService.saveLastInteraction(_lastInteractionAt);

    _initSessionLog();
    _startTicker();
    _startHeartbeat();
    _subscribeToMaintenanceMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionActivityTracker._state = null;
    _tickerTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (_maintenanceChannel != null) {
      Supabase.instance.client.removeChannel(_maintenanceChannel!);
    }
    super.dispose();
  }

  void _recordInteraction() {
    _lastInteractionAt = DateTime.now();
    LocalStorageService.saveLastInteraction(_lastInteractionAt);
  }

  // =========================================================================
  // 1. SUPABASE SESSION LOG INITIALIZATION & HEARTBEAT (REAL DATA)
  // =========================================================================

  Future<void> _initSessionLog() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    final existingSessionId = LocalStorageService.getActiveSessionId();
    if (existingSessionId != null) {
      _activeSessionLogId = existingSessionId;
      return;
    }

    try {
      final now = DateTime.now();
      _sessionStart = now;

      final roleStr = user.role.name;
      final res = await Supabase.instance.client
          .from('user_session_logs')
          .insert({
            'user_id': user.id,
            'role': roleStr,
            'session_date': now.toIso8601String().split('T').first,
            'login_at': now.toIso8601String(),
            'last_active_at': now.toIso8601String(),
            'is_active': true,
            'duration_seconds': 0,
          })
          .select('id')
          .single();

      _activeSessionLogId = res['id']?.toString();
      if (_activeSessionLogId != null) {
        await LocalStorageService.saveActiveSessionId(_activeSessionLogId!);
      }
    } catch (e) {
      debugPrint('SessionActivityTracker init session notice: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final user = AuthRepository.instance.currentUser;
      if (user == null) return;

      final sessionId = _activeSessionLogId ?? LocalStorageService.getActiveSessionId();
      if (sessionId == null) return;

      final now = DateTime.now();
      final totalSeconds = now.difference(_sessionStart).inSeconds;

      try {
        await Supabase.instance.client.from('user_session_logs').update({
          'last_active_at': now.toIso8601String(),
          'duration_seconds': totalSeconds >= 0 ? totalSeconds : 0,
        }).eq('id', sessionId);
      } catch (e) {
        // Edge Case #18: Silent try-catch with local cache fallback
        debugPrint('Heartbeat sync silent retry notice: $e');
        LocalStorageService.savePendingHeartbeat(sessionId, now);
      }
    });
  }

  // =========================================================================
  // 2. WALL-CLOCK INACTIVITY TICKER & OS SLEEP/RESUME (EDGE CASES #15 & #16)
  // =========================================================================

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkInactivity();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Laptop or mobile woke up from sleep/suspend: immediately compute difference
      _checkInactivity();
    }
  }

  void _checkInactivity() {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final inactiveDuration = now.difference(_lastInteractionAt);

    // Strict 30-Minute Inactivity Limit
    if (inactiveDuration >= const Duration(minutes: 30)) {
      _triggerAutoLogout('inactivity_timeout');
      return;
    }

    // 28-Minute Warning Prompt (2 minutes before logout)
    if (inactiveDuration >= const Duration(minutes: 28) && !_isWarningDialogShowing) {
      _showInactivityWarningModal();
    }
  }

  void _showInactivityWarningModal() {
    if (!mounted || _isWarningDialogShowing) return;
    _isWarningDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.catOrange, size: 28),
              SizedBox(width: 12),
              Text('Inactivity Warning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Are you still there? You will be logged out in 2 minutes due to inactivity. Click "Stay Logged In" to continue your session.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.catGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _recordInteraction();
                _isWarningDialogShowing = false;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Stay Logged In', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ).then((_) {
      _isWarningDialogShowing = false;
    });
  }

  Future<void> _triggerAutoLogout(String reason) async {
    _tickerTimer?.cancel();
    _heartbeatTimer?.cancel();

    if (_isWarningDialogShowing && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isWarningDialogShowing = false;
    }

    final sessionId = _activeSessionLogId ?? LocalStorageService.getActiveSessionId();
    if (sessionId != null) {
      try {
        final now = DateTime.now();
        await Supabase.instance.client.from('user_session_logs').update({
          'logout_at': now.toIso8601String(),
          'logout_reason': reason,
          'is_active': false,
        }).eq('id', sessionId);
      } catch (_) {}
      await LocalStorageService.clearActiveSessionId();
    }

    if (mounted) {
      await LogoutHelper.logout(context);
    }
  }

  // =========================================================================
  // 3. REALTIME MAINTENANCE MODE GATEKEEPING (EDGE CASES #1, #4, #5)
  // =========================================================================

  void _subscribeToMaintenanceMode() {
    _maintenanceChannel = Supabase.instance.client
        .channel('system_settings_listener')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'system_settings',
          callback: (payload) async {
            final newRow = payload.newRecord;
            final isMaintenance = newRow['is_maintenance_mode'] == true;
            if (isMaintenance) {
              final user = AuthRepository.instance.currentUser;
              // Admin is never locked out
              if (user != null && user.role != UserRole.admin) {
                // Edge Case #4: Flush offline teacher queue before force logout
                if (user.role == UserRole.teacher) {
                  await SyncCoordinator.instance.processPendingQueue();
                }
                await _triggerAutoLogout('maintenance_forced');
                if (mounted) {
                  _showMaintenanceForcedDialog();
                }
              }
            }
          },
        )
        .subscribe();
  }

  void _showMaintenanceForcedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.build_circle_outlined, color: AppTheme.catRed, size: 28),
            SizedBox(width: 12),
            Text('System Maintenance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'The system is currently under maintenance. You cannot log into your account at this time. Please try again later.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _recordInteraction(),
      onPointerMove: (_) => _recordInteraction(),
      onPointerHover: (_) => _recordInteraction(),
      behavior: HitTestBehavior.translucent,
      child: Focus(
        onKeyEvent: (node, event) {
          _recordInteraction();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
