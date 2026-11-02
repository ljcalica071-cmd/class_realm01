import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

/// Cross-Platform Android-style Activity Lifecycle States.
enum AppActivityLifecycleState {
  created,   // onCreate()
  started,   // onStart()
  resumed,   // onResume()
  paused,    // onPause()
  stopped,   // onStop()
  restarted, // onRestart()
  destroyed, // onDestroy()
}

/// Unified Cross-Platform Activity Lifecycle Coordinator.
///
/// Maps Flutter's [WidgetsBindingObserver] (mobile/desktop) and browser window events
/// (visibilitychange, focus, blur, pagehide, beforeunload on Web) into the 7 canonical
/// Activity Lifecycle states:
/// onCreate -> onStart -> onResume -> onPause -> onStop -> onRestart -> onDestroy.
class AppLifecycleCoordinator with WidgetsBindingObserver {
  static final AppLifecycleCoordinator instance = AppLifecycleCoordinator._internal();
  AppLifecycleCoordinator._internal();

  final ValueNotifier<AppActivityLifecycleState> stateNotifier =
      ValueNotifier<AppActivityLifecycleState>(AppActivityLifecycleState.created);

  /// Global notifier tracking background sync / session revalidation across warm refresh.
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  /// Global notifier tracking real network connectivity.
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  Timer? _connectivityPollTimer;

  AppActivityLifecycleState get currentState => stateNotifier.value;

  void setSyncing(bool syncing) {
    if (isSyncingNotifier.value != syncing) {
      isSyncingNotifier.value = syncing;
    }
  }

  final List<VoidCallback> _resumeListeners = <VoidCallback>[];
  final List<VoidCallback> _pauseListeners = <VoidCallback>[];

  bool _initialized = false;
  AppLifecycleState? _lastFlutterState;

  /// Initializes lifecycle hooks across Mobile, Desktop, and Web.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Register Web-specific event listeners (no-op on mobile/desktop)
    registerWebLifecycleListeners(
      onFocus: () => onResume(),
      onBlur: () => onPause(),
      onHide: () => onStop(),
      onShow: () => onRestart(),
      onUnload: () => onDestroy(),
    );

    // Initial web online status check
    isOnlineNotifier.value = getWebNavigatorOnlineStatus();

    // Register web online/offline window event listeners
    registerWebConnectivityListeners(
      onConnectivityChanged: (online) {
        if (isOnlineNotifier.value != online) {
          isOnlineNotifier.value = online;
          if (online) {
            SyncCoordinator.instance.processPendingQueue();
          }
        }
      },
    );

    _startConnectivityHeartbeat();
  }

  void addResumeListener(VoidCallback listener) {
    if (!_resumeListeners.contains(listener)) {
      _resumeListeners.add(listener);
    }
  }

  void removeResumeListener(VoidCallback listener) {
    _resumeListeners.remove(listener);
  }

  void addPauseListener(VoidCallback listener) {
    if (!_pauseListeners.contains(listener)) {
      _pauseListeners.add(listener);
    }
  }

  void removePauseListener(VoidCallback listener) {
    _pauseListeners.remove(listener);
  }

  // =========================================================================
  // 7 Activity Lifecycle Handlers
  // =========================================================================

  /// onCreate(): App/activity is created and initialized in memory.
  void onCreate() {
    stateNotifier.value = AppActivityLifecycleState.created;
    debugPrint('[AppLifecycleCoordinator] onCreate()');
  }

  /// onStart(): App becomes visible on screen, non-interactive while first frame settles.
  void onStart() {
    stateNotifier.value = AppActivityLifecycleState.started;
    debugPrint('[AppLifecycleCoordinator] onStart()');
  }

  /// onResume(): App moves to foreground and is fully interactive.
  /// Resumes activity tracking, checks wall-clock inactivity (>= 30m), and runs delta sync.
  void onResume() {
    stateNotifier.value = AppActivityLifecycleState.resumed;
    debugPrint('[AppLifecycleCoordinator] onResume()');

    final now = DateTime.now();
    final lastInteraction = LocalStorageService.getLastInteraction();

    if (lastInteraction != null) {
      final inactiveDuration = now.difference(lastInteraction);
      if (inactiveDuration >= const Duration(minutes: 30)) {
        debugPrint('[AppLifecycleCoordinator] Wall-clock inactivity >= 30m detected on resume.');
        // Notify session expiration if authenticated
        final user = AuthRepository.instance.currentUser;
        if (user != null) {
          unawaited(AuthRepository.instance.endSession('inactivity'));
        }
      }
    }

    // Refresh interaction timestamp
    unawaited(LocalStorageService.saveLastInteraction(now));

    // Run silent background delta sync
    try {
      SyncCoordinator.instance.startBackgroundSync();
    } catch (_) {}

    // Notify registered resume subscribers
    for (final listener in List<VoidCallback>.from(_resumeListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('[AppLifecycleCoordinator] Resume listener notice: $e');
      }
    }
  }

  /// onPause(): Window or app loses focus (AppLifecycleState.inactive or window.blur).
  /// Saves exact lastInteractionAt and persists active state.
  void onPause() {
    stateNotifier.value = AppActivityLifecycleState.paused;
    debugPrint('[AppLifecycleCoordinator] onPause()');

    final now = DateTime.now();
    unawaited(LocalStorageService.saveLastInteraction(now));

    for (final listener in List<VoidCallback>.from(_pauseListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('[AppLifecycleCoordinator] Pause listener notice: $e');
      }
    }
  }

  /// onStop(): App is completely hidden or backgrounded (hidden/paused on mobile or document hidden on web).
  /// Flushes session duration and pauses non-essential polling.
  void onStop() {
    stateNotifier.value = AppActivityLifecycleState.stopped;
    debugPrint('[AppLifecycleCoordinator] onStop()');

    final now = DateTime.now();
    unawaited(LocalStorageService.saveLastInteraction(now));

    // Flush session heartbeat to user_session_logs
    unawaited(AuthRepository.instance.recordHeartbeat());
  }

  /// onRestart(): User returns to the activity from onStop().
  /// Transitions through onStart() -> onResume().
  void onRestart() {
    stateNotifier.value = AppActivityLifecycleState.restarted;
    debugPrint('[AppLifecycleCoordinator] onRestart() -> onStart() -> onResume()');
    onStart();
    onResume();
  }

  /// onDestroy(): App is closed/detached. Disposes resources cleanly and persists final state.
  void onDestroy() {
    stateNotifier.value = AppActivityLifecycleState.destroyed;
    debugPrint('[AppLifecycleCoordinator] onDestroy()');

    final now = DateTime.now();
    unawaited(LocalStorageService.saveLastInteraction(now));
    unawaited(AuthRepository.instance.recordHeartbeat());
  }

  // =========================================================================
  // Flutter WidgetsBindingObserver Lifecycle Mapping
  // =========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prev = _lastFlutterState;
    _lastFlutterState = state;

    switch (state) {
      case AppLifecycleState.resumed:
        if (prev == AppLifecycleState.paused || prev == AppLifecycleState.hidden) {
          onRestart();
        } else {
          onResume();
        }
        break;
      case AppLifecycleState.inactive:
        onPause();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        onStop();
        break;
      case AppLifecycleState.detached:
        onDestroy();
        break;
    }
  }

  void _startConnectivityHeartbeat() {
    _connectivityPollTimer?.cancel();
    _connectivityPollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await checkConnectivity();
    });
  }

  Future<bool> checkConnectivity() async {
    bool hasConnection = false;
    try {
      if (kIsWeb) {
        final navOnline = getWebNavigatorOnlineStatus();
        if (!navOnline) {
          if (isOnlineNotifier.value != false) isOnlineNotifier.value = false;
          return false;
        }
      }

      final response = await http
          .head(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 4));
      hasConnection = response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      try {
        final supaUri = Uri.parse(Supabase.instance.client.rest.url);
        final response = await http
            .head(supaUri)
            .timeout(const Duration(seconds: 3));
        hasConnection = response.statusCode > 0;
      } catch (_) {
        hasConnection = false;
      }
    }

    if (isOnlineNotifier.value != hasConnection) {
      isOnlineNotifier.value = hasConnection;
      if (hasConnection) {
        SyncCoordinator.instance.processPendingQueue();
      }
    }
    return hasConnection;
  }

  void dispose() {
    if (_initialized) {
      _connectivityPollTimer?.cancel();
      _connectivityPollTimer = null;
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
  }
}
