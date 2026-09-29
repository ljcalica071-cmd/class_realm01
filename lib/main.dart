import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/pending_account_screen.dart';
import 'features/auth/screens/first_login_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/teacher/sub_features/setup/screens/academic_setup_wizard_screen.dart';
import 'features/teacher/screens/teacher_dashboard_screen.dart';
import 'features/student/screens/student_home_screen.dart';
import 'features/parent/screens/parent_home_screen.dart';

void main() {
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
            AppRoutes.register: (context) => const RegisterScreen(),
            AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
            AppRoutes.pendingAccount: (context) => const PendingAccountScreen(),
            AppRoutes.firstLogin: (context) => const FirstLoginScreen(),
            AppRoutes.academicSetup: (context) => const AcademicSetupWizardScreen(),
            AppRoutes.adminDashboard: (context) => const AdminDashboardScreen(),
            AppRoutes.teacherDashboard: (context) => const TeacherDashboardScreen(),
            AppRoutes.studentHome: (context) => const StudentHomeScreen(),
            AppRoutes.parentHome: (context) => const ParentHomeScreen(),
          },
        );
      },
    );
  }
}
