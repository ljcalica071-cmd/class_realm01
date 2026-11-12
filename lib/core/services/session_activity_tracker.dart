import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:class_realm/core/utils/logout_helper.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/routes/app_routes.dart';

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

  /// Custom clock provider (defaults to DateTime.now, overrideable for automated tests)
  static DateTime Function() nowProvider = DateTime.now;

  /// External keep-alive hook for video/lecture viewers
  static void keepAlive() {
    _state?._recordInteraction();
  }

  /// Records a user interaction manually from external callers.
  static void recordInteraction() {
    _state?._recordInteraction();
  }

  @override
  State<SessionActivityTracker> createState() => _SessionActivityTrackerState();
}

class _SessionActivityTrackerState extends State<SessionActivityTracker>
    with WidgetsBindingObserver {
  DateTime _lastInteractionAt = DateTime.now();
  DateTime? _lastDiskSaveAt;
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
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    _lastInteractionAt =
        LocalStorageService.getLastInteraction() ??
        SessionActivityTracker.nowProvider();
    LocalStorageService.saveLastInteraction(_lastInteractionAt);

    _initSessionLog();
    _startTicker();
    _startHeartbeat();
    _subscribeToMaintenanceMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    SessionActivityTracker._state = null;
    _tickerTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (_maintenanceChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_maintenanceChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    _recordInteraction();
    return false;
  }

  void _recordInteraction() {
    final now = SessionActivityTracker.nowProvider();
    _lastInteractionAt = now;
    // Throttle disk persistence to at most once every 5 seconds
    if (_lastDiskSaveAt == null ||
        now.difference(_lastDiskSaveAt!).inSeconds >= 5) {
      _lastDiskSaveAt = now;
      LocalStorageService.saveLastInteraction(now);
    }
  }

  // =========================================================================
  // 1. SUPABASE SESSION LOG INITIALIZATION & HEARTBEAT (REAL DATA)
  // =========================================================================

  Future<void> _initSessionLog() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) return;

    final existingSessionId =
        LocalStorageService.getActiveSessionId() ??
        AuthRepository.instance.activeSessionId;
    if (existingSessionId != null) {
      _activeSessionLogId = existingSessionId;
      return;
    }

    try {
      _sessionStart = DateTime.now();
      // Delegate to AuthRepository to guarantee a single source of truth and zero duplicate inserts
      final sId = await AuthRepository.instance.startSessionLog(user);
      if (sId != null && mounted) {
        _activeSessionLogId = sId;
      }
    } catch (e) {
      debugPrint('SessionActivityTracker init session notice: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final user = AuthRepository.instance.currentUser;
      if (user == null) return;

      final sessionId =
          _activeSessionLogId ?? LocalStorageService.getActiveSessionId();
      if (sessionId == null) return;

      final nowUtc = DateTime.now().toUtc();
      final totalSeconds = DateTime.now().difference(_sessionStart).inSeconds;

      try {
        await Supabase.instance.client
            .from('user_session_logs')
            .update({
              'last_active_at': nowUtc.toIso8601String(),
              'duration_seconds': totalSeconds >= 0 ? totalSeconds : 0,
            })
            .eq('id', sessionId);
      } catch (e) {
        // Edge Case #18: Silent try-catch with local cache fallback
        debugPrint('Heartbeat sync silent retry notice: $e');
        LocalStorageService.savePendingHeartbeat(sessionId, nowUtc);
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
    if (user == null) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _activeSessionLogId = null;
      return;
    }

    if (_heartbeatTimer == null) {
      _startHeartbeat();
      _initSessionLog();
    }

    final now = SessionActivityTracker.nowProvider();
    final inactiveDuration = now.difference(_lastInteractionAt);

    // Strict 30-Minute Inactivity Limit
    if (inactiveDuration >= const Duration(minutes: 30)) {
      _triggerAutoLogout('inactivity');
      return;
    }

    if (inactiveDuration >= const Duration(minutes: 28)) {
      _showInactivityWarningModal();
    }
  }

  void _showInactivityWarningModal() {
    if (!mounted || _isWarningDialogShowing) return;
    final navContext = AppRoutes.navigatorKey.currentContext ?? context;
    _isWarningDialogShowing = true;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        // Strict 60-30-10 Color Architecture
        // 60% Dominant: Card Surface (#FFFFFF Light, #263040 Dark)
        final cardBg =
            isDark ? const Color(0xFF263040) : const Color(0xFFFFFFFF);
        // 30% Secondary: Borders & Supporting elements
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFE2E8F0);
        final primaryTextColor =
            isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
        final secondaryTextColor =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563);
        // 10% Accent: Steel Blue #487898 (Light) / Sky Blue #60A5FA (Dark)
        final accentColor =
            isDark ? const Color(0xFF60A5FA) : const Color(0xFF487898);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row: 20px badge icon + 15px primary title
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.catOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.catOrange,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Inactivity Warning',
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Body text: 12.5px-13px, weight 500, height 1.45
                  Text(
                    'Are you still there? You will be logged out in 2 minutes due to inactivity. Click "Stay Logged In" to continue your session.',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Compact Action Buttons: height 36px, fontSize 13px, FontWeight.w600, borderRadius 8px
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 36,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: secondaryTextColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _isWarningDialogShowing = false;
                            Navigator.of(dialogContext).pop();
                            _triggerAutoLogout('inactivity');
                          },
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _recordInteraction();
                            _isWarningDialogShowing = false;
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text(
                            'Stay Logged In',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isWarningDialogShowing = false;
    });
  }

  Future<void> _triggerAutoLogout(String reason) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_isWarningDialogShowing) {
      _isWarningDialogShowing = false;
      try {
        AppRoutes.navigatorKey.currentState?.maybePop();
      } catch (_) {}
    }

    _lastInteractionAt = SessionActivityTracker.nowProvider();
    LocalStorageService.saveLastInteraction(_lastInteractionAt);

    final navContext = AppRoutes.navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      await LogoutHelper.logout(navContext, reason);
    } else {
      await LogoutHelper.logout(context, reason);
    }
  }

  // =========================================================================
  // 3. REALTIME MAINTENANCE MODE GATEKEEPING (EDGE CASES #1, #4, #5)
  // =========================================================================

  Future<void> _enforceMaintenanceLockdownIfNeeded() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null || user.role == UserRole.admin) return;

    if (user.role == UserRole.teacher) {
      await SyncCoordinator.instance.processPendingQueue();
    }
    await LocalStorageService.saveMaintenanceMode(true);
    await LocalStorageService.saveMaintenanceForcedLogout(true);
    await _triggerAutoLogout('maintenance_forced');
  }

  void _subscribeToMaintenanceMode() {
    // 1. Immediate initial check on mount (online & offline cache)
    unawaited(() async {
      final isMaint = await AuthRepository.instance.isSystemMaintenanceActive();
      if (isMaint && mounted) {
        await _enforceMaintenanceLockdownIfNeeded();
      }
    }());

    // 2. Realtime subscription for live toggle changes
    try {
      _maintenanceChannel = Supabase.instance.client
          .channel('system_settings_listener')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'system_settings',
            callback: (payload) async {
              final newRow = payload.newRecord;
              final isMaintenance = newRow['is_maintenance_mode'] == true;
              await LocalStorageService.saveMaintenanceMode(isMaintenance);
              if (isMaintenance) {
                await _enforceMaintenanceLockdownIfNeeded();
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _recordInteraction(),
      onPointerMove: (_) => _recordInteraction(),
      onPointerHover: (_) => _recordInteraction(),
      onPointerSignal: (_) => _recordInteraction(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
