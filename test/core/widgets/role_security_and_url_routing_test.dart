import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/widgets/auth_guard.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  group('AppRoutes Role Mapping & Sub-Route Validation', () {
    test('getDashboardRouteForRole maps correctly for all roles', () {
      expect(
        AppRoutes.getDashboardRouteForRole(UserRole.admin),
        AppRoutes.adminDashboard,
      );
      expect(
        AppRoutes.getDashboardRouteForRole(UserRole.teacher),
        AppRoutes.teacherDashboard,
      );
      expect(
        AppRoutes.getDashboardRouteForRole(UserRole.student),
        AppRoutes.studentHome,
      );
      expect(
        AppRoutes.getDashboardRouteForRole(UserRole.parent),
        AppRoutes.parentHome,
      );
    });

    test('getFirstLoginRouteForRole maps correctly for all roles', () {
      expect(
        AppRoutes.getFirstLoginRouteForRole(UserRole.teacher),
        AppRoutes.teacherFirstLogin,
      );
      expect(
        AppRoutes.getFirstLoginRouteForRole(UserRole.student),
        AppRoutes.studentFirstLogin,
      );
      expect(
        AppRoutes.getFirstLoginRouteForRole(UserRole.parent),
        AppRoutes.parentFirstLogin,
      );
    });

    test('Student and Parent sub-routes follow strict URL conventions', () {
      // Student sub-routes
      expect(AppRoutes.studentHome, '/student/home');
      expect(AppRoutes.studentClasswork, '/student/classwork');
      expect(AppRoutes.studentAlerts, '/student/alerts');
      expect(AppRoutes.studentProfile, '/student/profile');
      expect(AppRoutes.studentAttendance, '/student/attendance');
      expect(AppRoutes.studentSchedule, '/student/schedule');
      expect(AppRoutes.studentMaterials, '/student/materials');
      expect(AppRoutes.studentGrades, '/student/grades');
      expect(AppRoutes.studentPerformance, '/student/performance');

      // Parent sub-routes
      expect(AppRoutes.parentHome, '/parent/home');
      expect(AppRoutes.parentAttendance, '/parent/attendance');
      expect(AppRoutes.parentSchedule, '/parent/schedule');
      expect(AppRoutes.parentAlerts, '/parent/alerts');
      expect(AppRoutes.parentProfile, '/parent/profile');
      expect(AppRoutes.parentGrades, '/parent/grades');
    });
  });

  group('AuthGuard Role Security & Access Control', () {
    setUp(() {
      AuthRepository.instance.setCurrentUser(null);
    });

    tearDown(() {
      AuthRepository.instance.setCurrentUser(null);
    });

    testWidgets('Unauthenticated user is denied and child is NOT rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {AppRoutes.login: (ctx) => const Text('LOGIN_SCREEN')},
          home: const AuthGuard(
            allowedRoles: [UserRole.student],
            child: Text('PROTECTED_STUDENT_CONTENT'),
          ),
        ),
      );

      // Frame 1: child should NOT be visible to prevent content leaks
      expect(find.text('PROTECTED_STUDENT_CONTENT'), findsNothing);

      // Post-frame callback triggers redirect
      await tester.pumpAndSettle();
      expect(find.text('LOGIN_SCREEN'), findsOneWidget);
      expect(find.text('PROTECTED_STUDENT_CONTENT'), findsNothing);
    });

    testWidgets(
      'Student cannot bypass into Teacher route (tampering blocked)',
      (tester) async {
        final studentUser = UserModel(
          id: 'student-123',
          username: 'student.user',
          fullName: 'Juan Dela Cruz',
          email: 'student@example.com',
          role: UserRole.student,
          status: AccountStatus.active,
        );
        AuthRepository.instance.setCurrentUser(studentUser);

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRoutes.studentHome: (ctx) => const Text('STUDENT_HOME'),
            },
            home: const AuthGuard(
              allowedRoles: [UserRole.teacher],
              child: Text('SECRET_TEACHER_CONTENT'),
            ),
          ),
        );

        // Child is never rendered to unauthorized roles
        expect(find.text('SECRET_TEACHER_CONTENT'), findsNothing);

        await tester.pumpAndSettle();
        // Should redirect to student's legitimate dashboard
        expect(find.text('STUDENT_HOME'), findsOneWidget);
        expect(find.text('SECRET_TEACHER_CONTENT'), findsNothing);
      },
    );

    testWidgets('Parent cannot bypass into Student or Admin routes', (
      tester,
    ) async {
      final parentUser = UserModel(
        id: 'parent-456',
        username: 'parent.user',
        fullName: 'Maria Dela Cruz',
        email: 'parent@example.com',
        role: UserRole.parent,
        status: AccountStatus.active,
      );
      AuthRepository.instance.setCurrentUser(parentUser);

      await tester.pumpWidget(
        MaterialApp(
          routes: {AppRoutes.parentHome: (ctx) => const Text('PARENT_HOME')},
          home: const AuthGuard(
            allowedRoles: [UserRole.admin],
            child: Text('SECRET_ADMIN_CONTENT'),
          ),
        ),
      );

      expect(find.text('SECRET_ADMIN_CONTENT'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('PARENT_HOME'), findsOneWidget);
      expect(find.text('SECRET_ADMIN_CONTENT'), findsNothing);
    });

    testWidgets(
      'Authorized student role successfully renders student content',
      (tester) async {
        final studentUser = UserModel(
          id: 'student-123',
          username: 'student.user',
          fullName: 'Juan Dela Cruz',
          email: 'student@example.com',
          role: UserRole.student,
          status: AccountStatus.active,
        );
        AuthRepository.instance.setCurrentUser(studentUser);

        await tester.pumpWidget(
          const MaterialApp(
            home: AuthGuard(
              allowedRoles: [UserRole.student],
              child: Text('AUTHORIZED_STUDENT_DASHBOARD'),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('AUTHORIZED_STUDENT_DASHBOARD'), findsOneWidget);
      },
    );

    testWidgets('Deactivated student is locked out and redirected to login', (
      tester,
    ) async {
      final deactivatedStudent = UserModel(
        id: 'student-deact',
        username: 'deact.user',
        fullName: 'Deactivated User',
        email: 'deact@example.com',
        role: UserRole.student,
        status: AccountStatus.deactivated,
      );
      AuthRepository.instance.setCurrentUser(deactivatedStudent);

      await tester.pumpWidget(
        MaterialApp(
          routes: {AppRoutes.login: (ctx) => const Text('LOGIN_SCREEN')},
          home: const AuthGuard(
            allowedRoles: [UserRole.student],
            child: Text('PROTECTED_STUDENT_CONTENT'),
          ),
        ),
      );

      expect(find.text('PROTECTED_STUDENT_CONTENT'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('LOGIN_SCREEN'), findsOneWidget);
      expect(find.text('PROTECTED_STUDENT_CONTENT'), findsNothing);
    });
  });
}
