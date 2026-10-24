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
import 'features/parent/screens/parent_home_screen.dart';
import 'shared/widgets/indicators/global_top_loading_bar.dart';

/// Initializes clients before protected screens subscribe to backend services.
Future<void> _initializeRuntimeServices() async {
  try {
    await EnvConfig.init();
  } catch (e) {
    debugPrint('EnvConfig initialization notice: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }

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
      const Duration(seconds: 4),
      onTimeout: () => AuthRepository.instance.currentUser,
    );
    return restoredUser;
  } catch (e) {
    debugPrint('Session restore notice: $e');
    return AuthRepository.instance.currentUser;
  }
}

Future<UserModel?> _bootstrapClassRealmServices() async {
  await LocalStorageService.init();
  final cached = AuthRepository.instance.hydrateCachedSessionSync();

  // Run heavy runtime services asynchronously without blocking the loading screen completion
  final runtimeInit = _initializeRuntimeServices().catchError((e) {
    debugPrint('Runtime services initialization notice: $e');
  });

  if (cached != null) {
    try {
      final restored = await _restoreUserSession().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => cached,
      );
      return restored ?? cached;
    } catch (_) {
      return cached;
    }
  }

  unawaited(runtimeInit);
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Removes the # from the URL

  if (!kIsWeb) {
    AppLifecycleCoordinator.instance.initialize();
    runApp(const ClassRealmApp(isWarmBoot: false));
    return;
  }

  // 1. Initialize synchronous local cache layer (< 5ms)
  await LocalStorageService.init();

  // 1.5 Sync-Initialize basic config needed for background revalidation
  await EnvConfig.init();
  await SupabaseService.initialize();

  // 2. Synchronously hydrate cached UserModel before first frame renders (if active & < 30m idle)
  final cachedUser = AuthRepository.instance.hydrateCachedSessionSync();

  final hasActiveSession = cachedUser != null;
  final warm = isWarmSession() || hasActiveSession;

  // A refresh in the same tab restores its cached route without the cold-start
  // loading screen. Render Frame 1 IMMEDIATELY on the user's active route.
  if (hasActiveSession && warm) {
    // -----------------------------------------------------------------------
    // Warm Browser Refresh (F5) or warm app resume:
    // Render target screen IMMEDIATELY on Frame 1 using cached UserModel & SWR data.
    // Zero blank screen, zero loading splash reset, zero logout!
    // -----------------------------------------------------------------------
    markWarmSession();
    AppLifecycleCoordinator.instance.initialize();
    AppLifecycleCoordinator.instance.onStart();
    AppLifecycleCoordinator.instance.onResume();
    AppLifecycleCoordinator.instance.setSyncing(true);

    // Render Frame 1 instantly! Never block UI on network calls!
    runApp(const ClassRealmApp(isWarmBoot: true));

    // Non-blocking background revalidation & delta sync
    unawaited(() async {
      try {
        await _initializeRuntimeServices();
        await _restoreUserSession();
      } catch (e) {
        debugPrint('Background session revalidation notice: $e');
      } finally {
        AppLifecycleCoordinator.instance.setSyncing(false);
      }
    }());
  } else {
    // -----------------------------------------------------------------------
    // Cold Start:
    // Display branded onCreate() Slow-to-Fast Progress Loading Screen
    // (0% -> 30% -> 65% -> 100%) with school_logo.png + logo_app.png.
    // -----------------------------------------------------------------------
    AppLifecycleCoordinator.instance.initialize();
    runApp(const ClassRealmApp(isWarmBoot: false));
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

    final initialPath = getBrowserUrlPath();
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
      AppRoutes.studentHome,
      AppRoutes.parentHome,
    };
    if (restorableRoutes.contains(initialPath)) {
      _targetRoute = initialPath;
    }
  }

  String _determineInitialDestination() {
    final user = _bootstrappedUser ?? AuthRepository.instance.currentUser;
    if (user != null) {
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
    if (activeUser != null) {
      final String dest;
      final savedRoute = LocalStorageService.getLastActiveRoute();
      if (_targetRoute != null && _targetRoute!.isNotEmpty && _targetRoute != '/') {
        dest = _targetRoute!;
      } else if (savedRoute != null && savedRoute.isNotEmpty && savedRoute != '/') {
        dest = savedRoute;
      } else {
        dest = AppRoutes.getDashboardRouteForRole(activeUser.role);
      }
      
      updateBrowserUrl(dest);
      if (dest.isNotEmpty &&
          dest != AppRoutes.login &&
          dest != AppRoutes.splash &&
          dest != '/') {
        AppRoutes.navigatorKey.currentState?.pushReplacementNamed(dest);
      } else {
        AppRoutes.navigatorKey.currentState?.pushReplacementNamed(
          AppRoutes.getDashboardRouteForRole(activeUser.role),
        );
      }
    } else {
      updateBrowserUrl(AppRoutes.login);
      final current = getBrowserUrlPath();
      if (current != AppRoutes.login) {
        AppRoutes.navigatorKey.currentState?.pushReplacementNamed(
          AppRoutes.login,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final initialDestination = _determineInitialDestination();
        if (widget.isWarmBoot) {
          updateBrowserUrl(initialDestination);
        }

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
          themeAnimationDuration: const Duration(milliseconds: 600),
          themeAnimationCurve: Curves.easeInOut,
          initialRoute: initialDestination,
          builder: (context, child) {
            return Stack(
              children: [
                ?child,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: GlobalTopLoadingBar(),
                ),
                if (!_isBootstrapped)
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
            );
          },
          routes: {
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
                      child: TeacherDashboardScreen(),
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
                // If a user is already logged in and tries to go to login page (or refreshes on it),
                // bounce them back to their dashboard.
                Future.microtask(() {
                  Navigator.pushReplacementNamed(
                    context, 
                    AppRoutes.getDashboardRouteForRole(activeUser.role)
                  );
                });
                return const Scaffold(body: Center(child: CircularProgressIndicator())); // Temporary blank state
              }
              return const LoginScreen();
            },
            AppRoutes.adminAddTeacher: (context) => const AuthGuard(
              allowedRoles: [UserRole.admin],
              child: AdminAddTeacherScreen(),
            ),
            AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
            AppRoutes.studentFirstLogin: (context) => const AuthGuard(
              allowedRoles: [UserRole.student, UserRole.parent],
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
            AppRoutes.studentHome: (context) => const AuthGuard(
              allowedRoles: [UserRole.student],
              child: StudentHomeScreen(),
            ),
            AppRoutes.parentHome: (context) => const AuthGuard(
              allowedRoles: [UserRole.parent],
              child: ParentHomeScreen(),
            ),
          },
        );
      },
    );
  }
}
