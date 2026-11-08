import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:class_realm/firebase_options.dart';
import 'package:class_realm/core/config/env_config.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';
import 'package:class_realm/core/widgets/app_lifecycle_loading_screen.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:class_realm/shared/widgets/in_app_notification_banner.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/auth_guard.dart';
import 'models/user_model.dart';
import 'routes/app_routes.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/first_login_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/admin_add_teacher_screen.dart';
import 'features/teacher/sub_features/setup/screens/academic_setup_wizard_screen.dart';
import 'features/teacher/screens/teacher_dashboard_screen.dart';
import 'features/student/screens/student_home_screen.dart';
import 'features/student/sub_features/academics/screens/student_academic_performance_screen.dart';
import 'features/student/sub_features/academics/screens/student_grades_screen.dart';
import 'features/student/sub_features/academics/screens/student_learning_materials_screen.dart';
import 'features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'features/student/sub_features/schedule/screens/student_schedule_screen.dart';
import 'features/parent/screens/parent_home_screen.dart';
import 'features/parent/sub_features/child_details/widgets/parent_grades_tab.dart';

/// Runs a startup task with a strict timeout without letting its failure abort the boot sequence.
Future<void> _guarded(
  Future<Object?> task,
  String label, {
  Duration timeout = const Duration(milliseconds: 3500),
}) async {
  try {
    await task.timeout(timeout);
  } catch (e) {
    debugPrint('$label initialization notice: $e');
  }
}

/// Initializes clients before protected screens subscribe to backend services.
Future<void> _initializeRuntimeServices({
  void Function(double progress, String status)? onProgress,
}) async {
  onProgress?.call(0.24, 'Loading environment configuration...');
  await _guarded(EnvConfig.init(), 'EnvConfig');

  onProgress?.call(0.48, 'Connecting to Firebase Auth & Supabase...');
  await Future.wait<void>([
    _guarded(
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      'Firebase',
    ),
    _guarded(SupabaseService.initialize(), 'Supabase'),
  ]);

  onProgress?.call(0.78, 'Preparing local sync engine...');
  try {
    AppDatabase.instance;
    SyncCoordinator.instance.startBackgroundSync();
  } catch (e) {
    debugPrint('Local database initialization notice: $e');
  }
}

Future<UserModel?> _restoreUserSession() async {
  try {
    final restoredUser = await AuthRepository.instance.restoreSession().timeout(
      const Duration(milliseconds: 2400),
      onTimeout: () => AuthRepository.instance.currentUser,
    );
    return restoredUser;
  } catch (e) {
    debugPrint('Session restore notice: $e');
    return AuthRepository.instance.currentUser;
  }
}

Future<UserModel?> _bootstrapClassRealmServices(
  void Function(double progress, String status) onProgress,
) async {
  onProgress(0.12, 'Loading local storage cache...');
  await _guarded(LocalStorageService.init(), 'LocalStorage');
  final cached = AuthRepository.instance.hydrateCachedSessionSync();

  await _initializeRuntimeServices(onProgress: onProgress);

  onProgress(0.92, 'Restoring user session...');
  if (cached != null) {
    try {
      final restored = await _restoreUserSession().timeout(
        const Duration(milliseconds: 1600),
        onTimeout: () => cached,
      );
      return restored ?? cached;
    } catch (_) {
      return cached;
    }
  }

  return await _restoreUserSession();
}

void _applySavedUserTheme(UserModel? user) {
  if (user == null) {
    AppTheme.themeModeNotifier.value = ThemeMode.light;
    return;
  }
  final isDark = LocalStorageService.isUserDarkMode(
    user.id,
    email: user.email,
  );
  AppTheme.themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

String _normalizeRoutePath(String rawPath) {
  var clean = rawPath.split('?').first.split('#').first.trim();
  if (clean.length > 1 && clean.endsWith('/')) {
    clean = clean.substring(0, clean.length - 1);
  }
  return clean.isEmpty ? '/' : clean;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Removes the # from the URL

  if (!kIsWeb) {
    AppLifecycleCoordinator.instance.initialize();
    runApp(const ClassRealmApp(isWarmBoot: false));
    return;
  }

  // On Web, check whether this tab is already in a warm session (e.g., F5 refresh).
  final warmTab = isWarmSession();

  if (!warmTab) {
    updatePreBootstrapProgress(
      0.55,
      'Loading local storage & configuration...',
    );
  }
  // Speed: local storage and env config are independent - load in parallel with hard timeouts.
  await Future.wait<void>([
    _guarded(LocalStorageService.init(), 'LocalStorage'),
    _guarded(EnvConfig.init(), 'EnvConfig'),
  ]);

  if (!warmTab) {
    updatePreBootstrapProgress(
      0.74,
      'Connecting to Firebase Auth & Supabase...',
    );
  }
  // Speed: Firebase and Supabase handshakes run concurrently instead of
  // back-to-back, so cold start only waits for the slower of the two.
  await Future.wait<void>([
    _guarded(
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      'Firebase',
    ),
    _guarded(SupabaseService.initialize(), 'Supabase'),
  ]);

  // Synchronously hydrate cached UserModel before first frame renders (if active & < 30m idle)
  final cachedUser = AuthRepository.instance.hydrateCachedSessionSync();

  if (cachedUser != null) {
    // -----------------------------------------------------------------------
    // Instant Session Hydration (Warm F5 or Cached Active Session):
    // Render target screen IMMEDIATELY on Frame 1 using cached UserModel & SWR data,
    // and revalidate session + local SQLite sync in the background.
    // -----------------------------------------------------------------------
    _applySavedUserTheme(cachedUser);
    if (!warmTab) {
      updatePreBootstrapProgress(1.0, 'ClassRealm Ready! Welcome.');
    }
    markWarmSession();
    AppLifecycleCoordinator.instance.initialize();
    if (!warmTab) {
      AppLifecycleCoordinator.instance.onCreate();
    }
    AppLifecycleCoordinator.instance.onStart();
    AppLifecycleCoordinator.instance.onResume();
    AppLifecycleCoordinator.instance.setSyncing(true);

    runApp(const ClassRealmApp(isWarmBoot: true));

    unawaited(() async {
      try {
        if (!kIsWeb) {
          AppDatabase.instance;
          SyncCoordinator.instance.startBackgroundSync();
        }
        await _restoreUserSession();
      } catch (e) {
        debugPrint('Background session revalidation notice: $e');
      } finally {
        AppLifecycleCoordinator.instance.setSyncing(false);
      }
    }());
  } else {
    // -----------------------------------------------------------------------
    // Cold Start on Web (No Cached User):
    // Bound session check tightly and defer Drift SQLite / background sync
    // until after runApp() so the UI never hangs on Web Workers or network.
    // -----------------------------------------------------------------------
    updatePreBootstrapProgress(0.88, 'Preparing your secure workspace...');
    await _guarded(
      _restoreUserSession(),
      'SessionRestore',
      timeout: const Duration(milliseconds: 2200),
    );
    _applySavedUserTheme(AuthRepository.instance.currentUser);

    updatePreBootstrapProgress(1.0, 'ClassRealm Ready! Welcome.');
    markWarmSession();
    AppLifecycleCoordinator.instance.initialize();
    AppLifecycleCoordinator.instance.onCreate();
    AppLifecycleCoordinator.instance.onStart();
    AppLifecycleCoordinator.instance.onResume();

    runApp(const ClassRealmApp(isWarmBoot: true));

    unawaited(() async {
      try {
        if (!kIsWeb) {
          AppDatabase.instance;
          SyncCoordinator.instance.startBackgroundSync();
        }
      } catch (e) {
        debugPrint('Local database initialization notice: $e');
      }
    }());
  }
}

class ClassRealmApp extends StatefulWidget {
  final bool isWarmBoot;
  const ClassRealmApp({super.key, this.isWarmBoot = false});

  @override
  State<ClassRealmApp> createState() => _ClassRealmAppState();
}

class _ClassRealmAppState extends State<ClassRealmApp> {
  late bool _isBootstrapped = widget.isWarmBoot;
  UserModel? _bootstrappedUser;
  String? _targetRoute;
  late final Map<String, WidgetBuilder> _appRoutes = _buildAppRoutes();
  String _initialDestination = AppRoutes.login;

  @override
  void initState() {
    super.initState();
    if (widget.isWarmBoot) {
      _bootstrappedUser = AuthRepository.instance.currentUser;
    }
    // Remove static HTML pre-loader as soon as Flutter renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removePreBootstrapLoader();
    });

    final initialPath = _normalizeRoutePath(getBrowserUrlPath());
    const restorableRoutes = {
      AppRoutes.adminDashboard,
      AppRoutes.adminBroadcasts,
      AppRoutes.adminTeacherManagement,
      AppRoutes.adminAddTeacher,
      AppRoutes.adminActivityAnalytics,
      AppRoutes.adminProfile,
      AppRoutes.teacherDashboard,
      AppRoutes.teacherClassroomSetup,
      AppRoutes.teacherGradebook,
      AppRoutes.teacherManageStudents,
      AppRoutes.teacherManageParents,
      AppRoutes.teacherClasswork,
      AppRoutes.teacherLessonPlanning,
      AppRoutes.teacherLearningMaterials,
      AppRoutes.teacherAttendance,
      AppRoutes.teacherGrades,
      AppRoutes.teacherSchedule,
      AppRoutes.teacherNotifications,
      AppRoutes.teacherProfile,
      AppRoutes.teacherSettings,
      AppRoutes.studentHome,
      AppRoutes.studentClasswork,
      AppRoutes.studentAlerts,
      AppRoutes.studentProfile,
      AppRoutes.studentAttendance,
      AppRoutes.studentSchedule,
      AppRoutes.studentMaterials,
      AppRoutes.studentGrades,
      AppRoutes.studentPerformance,
      AppRoutes.parentHome,
      AppRoutes.parentAttendance,
      AppRoutes.parentSchedule,
      AppRoutes.parentAlerts,
      AppRoutes.parentProfile,
      AppRoutes.parentGrades,
    };
    if (restorableRoutes.contains(initialPath)) {
      _targetRoute = initialPath;
    }
    _initialDestination = _determineInitialDestination();
    if (widget.isWarmBoot) {
      updateBrowserUrl(_initialDestination);
    }
  }

  String _determineInitialDestination() {
    final user = _bootstrappedUser ?? AuthRepository.instance.currentUser;
    if (user != null) {
      if (user.status == AccountStatus.pendingFirstLogin ||
          user.status == AccountStatus.pending) {
        return AppRoutes.getFirstLoginRouteForRole(user.role);
      }
      if (_targetRoute != null && _targetRoute!.isNotEmpty) {
        return _targetRoute!;
      }
      final lastRoute = LocalStorageService.getLastActiveRoute();
      if (lastRoute != null &&
          lastRoute.isNotEmpty &&
          lastRoute != AppRoutes.login &&
          lastRoute != AppRoutes.splash &&
          lastRoute != '/') {
        return lastRoute;
      }
      return AppRoutes.getDashboardRouteForRole(user.role);
    }
    return AppRoutes.login;
  }

  void _onBootstrapComplete(UserModel? user) {
    final activeUser =
        user ??
        AuthRepository.instance.currentUser ??
        LocalStorageService.getCachedUser();
    _applySavedUserTheme(activeUser);
    if (activeUser != null) {
      final String dest;
      final savedRoute = LocalStorageService.getLastActiveRoute();
      if (activeUser.status == AccountStatus.pendingFirstLogin ||
          activeUser.status == AccountStatus.pending) {
        dest = AppRoutes.getFirstLoginRouteForRole(activeUser.role);
      } else if (_targetRoute != null &&
          _targetRoute!.isNotEmpty &&
          _targetRoute != '/') {
        dest = _targetRoute!;
      } else if (savedRoute != null &&
          savedRoute.isNotEmpty &&
          savedRoute != '/') {
        dest = savedRoute;
      } else {
        dest = AppRoutes.getDashboardRouteForRole(activeUser.role);
      }

      updateBrowserUrl(dest);
      if (dest.isNotEmpty &&
          dest != AppRoutes.login &&
          dest != AppRoutes.splash &&
          dest != '/') {
        AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          dest,
          (route) => false,
        );
      } else {
        AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.getDashboardRouteForRole(activeUser.role),
          (route) => false,
        );
      }
    } else {
      updateBrowserUrl(AppRoutes.login);
      final current = getBrowserUrlPath();
      if (current != AppRoutes.login) {
        AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  Map<String, WidgetBuilder> _buildAppRoutes() {
    return {
      AppRoutes.splash: (context) => const SizedBox.shrink(),
      '/': (context) {
        final activeUser = AuthRepository.instance.currentUser;
        if (activeUser != null) {
          switch (activeUser.role) {
            case UserRole.admin:
              return const AuthGuard(
                allowedRoles: [UserRole.admin],
                child: AdminDashboardScreen(initialIndex: 0),
              );
            case UserRole.teacher:
              return const AuthGuard(
                allowedRoles: [UserRole.teacher],
                child: TeacherDashboardScreen(initialSelectedIndex: 0),
              );
            case UserRole.student:
              return const AuthGuard(
                allowedRoles: [UserRole.student],
                child: StudentHomeScreen(),
              );
            case UserRole.parent:
              return const AuthGuard(
                allowedRoles: [UserRole.parent],
                child: ParentHomeScreen(),
              );
          }
        }
        return const LoginScreen();
      },
      AppRoutes.login: (context) {
        final activeUser = AuthRepository.instance.currentUser;
        if (activeUser != null) {
          final isFirstLoginPending =
              activeUser.status == AccountStatus.pendingFirstLogin ||
              activeUser.status == AccountStatus.pending;
          final target = isFirstLoginPending
              ? AppRoutes.getFirstLoginRouteForRole(activeUser.role)
              : AppRoutes.getDashboardRouteForRole(activeUser.role);
          Future.microtask(() {
            if (context.mounted) {
              updateBrowserUrl(target);
              Navigator.pushNamedAndRemoveUntil(
                context,
                target,
                (route) => false,
              );
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const LoginScreen();
      },
      AppRoutes.adminAddTeacher: (context) => const AuthGuard(
        allowedRoles: [UserRole.admin],
        child: AdminAddTeacherScreen(),
      ),
      AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
      AppRoutes.studentFirstLogin: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: FirstLoginScreen(),
      ),
      AppRoutes.parentFirstLogin: (context) => const AuthGuard(
        allowedRoles: [UserRole.parent],
        child: FirstLoginScreen(),
      ),
      AppRoutes.teacherFirstLogin: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: FirstLoginScreen(),
      ),
      AppRoutes.academicSetup: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: AcademicSetupWizardScreen(),
      ),
      AppRoutes.adminDashboard: (context) => const AuthGuard(
        allowedRoles: [UserRole.admin],
        child: AdminDashboardScreen(initialIndex: 0),
      ),
      AppRoutes.adminBroadcasts: (context) => const AuthGuard(
        allowedRoles: [UserRole.admin],
        child: AdminDashboardScreen(initialIndex: 1),
      ),
      AppRoutes.adminTeacherManagement: (context) => const AuthGuard(
        allowedRoles: [UserRole.admin],
        child: AdminDashboardScreen(initialIndex: 2),
      ),
      AppRoutes.adminActivityAnalytics: (context) => const AuthGuard(
        allowedRoles: [UserRole.admin],
        child: AdminDashboardScreen(initialIndex: 3),
      ),
      AppRoutes.adminProfile: (context) => const AuthGuard(
        allowedRoles: [UserRole.admin],
        child: AdminDashboardScreen(initialIndex: 4),
      ),
      // Teacher Routes with sub-route support
      AppRoutes.teacherDashboard: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 0),
      ),
      AppRoutes.teacherClassroomSetup: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 17),
      ),
      AppRoutes.teacherGradebook: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 18),
      ),
      AppRoutes.teacherManageStudents: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 12),
      ),
      AppRoutes.teacherManageParents: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 19),
      ),
      AppRoutes.teacherClasswork: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 1),
      ),
      AppRoutes.teacherLessonPlanning: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 3),
      ),
      AppRoutes.teacherLearningMaterials: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 4),
      ),
      AppRoutes.teacherAttendance: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 5),
      ),
      AppRoutes.teacherGrades: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 9),
      ),
      AppRoutes.teacherSchedule: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 14),
      ),
      AppRoutes.teacherNotifications: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 15),
      ),
      AppRoutes.teacherProfile: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 16),
      ),
      AppRoutes.teacherSettings: (context) => const AuthGuard(
        allowedRoles: [UserRole.teacher],
        child: TeacherDashboardScreen(initialSelectedIndex: 10),
      ),
      // Student Routes with sub-route support
      AppRoutes.studentHome: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentHomeScreen(initialTabIndex: 0),
      ),
      AppRoutes.studentClasswork: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentHomeScreen(initialTabIndex: 1),
      ),
      AppRoutes.studentAlerts: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentHomeScreen(initialTabIndex: 2),
      ),
      AppRoutes.studentProfile: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentHomeScreen(initialTabIndex: 3),
      ),
      AppRoutes.studentAttendance: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentAttendanceScreen(),
      ),
      AppRoutes.studentSchedule: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentScheduleScreen(),
      ),
      AppRoutes.studentMaterials: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentLearningMaterialsScreen(),
      ),
      AppRoutes.studentGrades: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentGradesScreen(),
      ),
      AppRoutes.studentPerformance: (context) => const AuthGuard(
        allowedRoles: [UserRole.student],
        child: StudentAcademicPerformanceScreen(),
      ),
      // Parent Routes with sub-route support
      AppRoutes.parentHome: (context) => const AuthGuard(
        allowedRoles: [UserRole.parent],
        child: ParentHomeScreen(initialTabIndex: 0),
      ),
      AppRoutes.parentAttendance: (context) => const AuthGuard(
        allowedRoles: [UserRole.parent],
        child: ParentHomeScreen(initialTabIndex: 1),
      ),
      AppRoutes.parentSchedule: (context) => const AuthGuard(
        allowedRoles: [UserRole.parent],
        child: ParentHomeScreen(initialTabIndex: 2),
      ),
      AppRoutes.parentAlerts: (context) => const AuthGuard(
        allowedRoles: [UserRole.parent],
        child: ParentHomeScreen(initialTabIndex: 3),
      ),
      AppRoutes.parentProfile: (context) => const AuthGuard(
        allowedRoles: [UserRole.parent],
        child: ParentHomeScreen(initialTabIndex: 4),
      ),
      AppRoutes.parentGrades: (context) => const AuthGuard(
        allowedRoles: [UserRole.parent],
        child: ParentGradesScreen(initialStudent: null),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final initialDestination = _initialDestination.isNotEmpty
            ? _initialDestination
            : _determineInitialDestination();
        final appRoutes = _appRoutes;

        return MaterialApp(
          navigatorKey: AppRoutes.navigatorKey,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          title: 'ClassRealm',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 250),
          themeAnimationCurve: Curves.easeOutCubic,
          initialRoute: initialDestination,
          onGenerateInitialRoutes: (String initialRouteName) {
            final normalizedRoute = _normalizeRoutePath(initialRouteName);
            final validBuilder = appRoutes[normalizedRoute];
            final actualRouteName = validBuilder != null
                ? normalizedRoute
                : initialDestination;
            final builder =
                validBuilder ??
                appRoutes[initialDestination] ??
                appRoutes[AppRoutes.login]!;
            if (validBuilder == null) {
              updateBrowserUrl(actualRouteName);
            }
            return [
              MaterialPageRoute(
                settings: RouteSettings(name: actualRouteName),
                builder: builder,
              ),
            ];
          },
          onUnknownRoute: (settings) {
            final user = AuthRepository.instance.currentUser;
            final fallbackRoute = user != null
                ? AppRoutes.getDashboardRouteForRole(user.role)
                : AppRoutes.login;
            updateBrowserUrl(fallbackRoute);
            return MaterialPageRoute(
              settings: RouteSettings(name: fallbackRoute),
              builder: (ctx) =>
                  (appRoutes[fallbackRoute] ?? appRoutes[AppRoutes.login]!)(
                    ctx,
                  ),
            );
          },
          builder: (context, child) {
            return InAppNotificationBannerOverlay(
              child: Stack(
                children: [
                  ?child,
                  if (!_isBootstrapped && !widget.isWarmBoot)
                    Positioned.fill(
                      child: AppLifecycleLoadingScreen(
                        initializationTask: _bootstrapClassRealmServices,
                        onComplete: (screenContext, user) {
                          if (mounted) {
                            setState(() {
                              _bootstrappedUser = user;
                              _isBootstrapped = true;
                            });
                            _onBootstrapComplete(user);
                          }
                        },
                      ),
                    ),
                ],
              ),
            );
          },
          routes: appRoutes,
        );
      },
    );
  }
}
