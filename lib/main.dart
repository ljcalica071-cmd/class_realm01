import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:class_realm/firebase_options.dart';
import 'package:class_realm/core/config/env_config.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';

import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/auth_guard.dart';
import 'models/user_model.dart';
import 'routes/app_routes.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/first_login_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/teacher/sub_features/setup/screens/academic_setup_wizard_screen.dart';
import 'features/teacher/screens/teacher_dashboard_screen.dart';
import 'features/student/screens/student_home_screen.dart';
import 'features/parent/screens/parent_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Removes the # from the URL

  // Initialize Local Storage & Drift SQLite Database
  await LocalStorageService.init();
  try {
    AppDatabase.instance;
    SyncCoordinator.instance.startBackgroundSync();
  } catch (e) {
    debugPrint('Local database initialization notice: $e');
  }

  // Initialize Environment Variables
  try {
    await EnvConfig.init();
  } catch (e) {
    debugPrint('EnvConfig initialization error: $e');
  }

  // Initialize Firebase (Requires `flutterfire configure` to generate firebase_options.dart)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(
      'Firebase initialization error. Make sure to run flutterfire configure.',
    );
  }

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const ClassRealmApp());
}



class ClassRealmApp extends StatelessWidget {
  const ClassRealmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
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
          initialRoute: AppRoutes.login,
          routes: {
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
              child: AdminDashboardScreen(),
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
