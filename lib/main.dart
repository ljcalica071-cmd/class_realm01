import 'dart:async';
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

/// Parallel, non-blocking initializer for database sync & session restore.
Future<UserModel?> _runBackgroundServices() async {
  try {
    AppDatabase.instance;
    SyncCoordinator.instance.startBackgroundSync();
  } catch (e) {
    debugPrint('Local database initialization notice: $e');
  }

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Removes the # from the URL

  // 1. Initialize synchronous local cache layer
  await LocalStorageService.init();

  // 2. Initialize environment & backend services before session hydration
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

  // 3. Synchronously hydrate cached UserModel before first frame renders (if active & < 30m idle)
  AuthRepository.instance.hydrateCachedSessionSync();

  // 4. Initialize Cross-Platform Activity Lifecycle Coordinator
  AppLifecycleCoordinator.instance.initialize();

  final warm = isWarmSession();
  final cachedUser = AuthRepository.instance.currentUser;

  if (warm && cachedUser != null) {
    // -----------------------------------------------------------------------
    // Warm Browser Refresh (F5) or warm app resume:
    // Render target screen IMMEDIATELY on Frame 1 using synchronous hydrated
    // UserModel and cached dashboard data.
    // Zero loading screen reset, zero login screen flash!
    // -----------------------------------------------------------------------
    unawaited(_runBackgroundServices());
    AppLifecycleCoordinator.instance.onStart();
    AppLifecycleCoordinator.instance.onResume();
    runApp(const ClassRealmApp(isWarmBoot: true));
  } else {
    // -----------------------------------------------------------------------
    // Cold Start:
    // Display branded onCreate() Slow-to-Fast Progress Loading Screen
    // (0% -> 30% -> 65% -> 100%) with school_logo.png + logo_app.png.
    // -----------------------------------------------------------------------
    runApp(const ClassRealmApp(isWarmBoot: false));
  }
}

class ClassRealmApp extends StatelessWidget {
  final bool isWarmBoot;
  const ClassRealmApp({super.key, this.isWarmBoot = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        Widget buildColdLoadingScreen() {
          return AppLifecycleLoadingScreen(
            initializationTask: _runBackgroundServices,
            onComplete: (screenContext, user) {
              final nav = AppRoutes.navigatorKey.currentState ??
                  Navigator.of(screenContext);
              if (user != null) {
                final lastRoute = LocalStorageService.getLastActiveRoute();
                final target = (lastRoute != null &&
                        lastRoute.isNotEmpty &&
                        lastRoute != AppRoutes.login &&
                        lastRoute != AppRoutes.splash &&
                        lastRoute != '/')
                    ? lastRoute
                    : AppRoutes.getDashboardRouteForRole(user.role);
                updateBrowserUrl(target);
                nav.pushNamedAndRemoveUntil(target, (route) => false);
              } else {
                updateBrowserUrl(AppRoutes.login);
                nav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              }
            },
          );
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
          themeMode: themeMode, // Auto switches based on device setting or manual toggle
          themeAnimationDuration: const Duration(milliseconds: 600),
          themeAnimationCurve: Curves.easeInOut,
          initialRoute: isWarmBoot ? null : AppRoutes.splash,
          routes: {
            AppRoutes.splash: (context) => buildColdLoadingScreen(),
            '/': (context) {
              if (!isWarmBoot) {
                return buildColdLoadingScreen();
              }
              final user = AuthRepository.instance.currentUser;
              if (user != null) {
                switch (user.role) {
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
            AppRoutes.login: (context) => const LoginScreen(),
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
            AppRoutes.teacherDashboard: (context) => const AuthGuard(
              allowedRoles: [UserRole.teacher],
              child: TeacherDashboardScreen(),
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
