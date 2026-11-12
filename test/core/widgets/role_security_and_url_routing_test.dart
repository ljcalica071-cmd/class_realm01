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

    testWidgets(
      'Pending first login user on dashboard route is redirected to first-login',
      (tester) async {
        final pendingStudent = UserModel(
          id: 'student-pending',
          username: 'pending.user',
          fullName: 'Pending Student',
          email: 'pending@example.com',
          role: UserRole.student,
          status: AccountStatus.pendingFirstLogin,
        );
        AuthRepository.instance.setCurrentUser(pendingStudent);

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRoutes.studentFirstLogin: (ctx) =>
                  const Text('STUDENT_FIRST_LOGIN_SCREEN'),
            },
            home: const AuthGuard(
              allowedRoles: [UserRole.student],
              child: Text('PROTECTED_DASHBOARD_CONTENT'),
            ),
          ),
        );

        // Frame 1: Child is not visible
        expect(find.text('PROTECTED_DASHBOARD_CONTENT'), findsNothing);

        await tester.pumpAndSettle();
        // Redirected to first login route
        expect(find.text('STUDENT_FIRST_LOGIN_SCREEN'), findsOneWidget);
        expect(find.text('PROTECTED_DASHBOARD_CONTENT'), findsNothing);
      },
    );

    testWidgets(
      'Pending first login user on first-login route renders content (web minification resilient)',
      (tester) async {
        final pendingStudent = UserModel(
          id: 'student-pending',
          username: 'pending.user',
          fullName: 'Pending Student',
          email: 'pending@example.com',
          role: UserRole.student,
          status: AccountStatus.pendingFirstLogin,
        );
        AuthRepository.instance.setCurrentUser(pendingStudent);

        await tester.pumpWidget(
          const MaterialApp(
            home: AuthGuard(
              allowedRoles: [UserRole.student],
              isFirstLogin: true,
              child: Text('FIRST_LOGIN_PASSWORD_SETUP_FORM'),
            ),
          ),
        );

        // Frame 1: Child renders immediately because isFirstLogin: true is authorized
        expect(find.text('FIRST_LOGIN_PASSWORD_SETUP_FORM'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.text('FIRST_LOGIN_PASSWORD_SETUP_FORM'), findsOneWidget);
      },
    );

    testWidgets(
      'Active user attempting to revisit first-login route is redirected to dashboard',
      (tester) async {
        final activeTeacher = UserModel(
          id: 'teacher-active',
          username: 'teacher.user',
          fullName: 'Active Teacher',
          email: 'teacher@example.com',
          role: UserRole.teacher,
          status: AccountStatus.active,
        );
        AuthRepository.instance.setCurrentUser(activeTeacher);

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRoutes.teacherDashboard: (ctx) =>
                  const Text('TEACHER_DASHBOARD_SCREEN'),
            },
            home: const AuthGuard(
              allowedRoles: [UserRole.teacher],
              isFirstLogin: true,
              child: Text('TEACHER_FIRST_LOGIN_FORM'),
            ),
          ),
        );

        expect(find.text('TEACHER_FIRST_LOGIN_FORM'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('TEACHER_DASHBOARD_SCREEN'), findsOneWidget);
      },
    );

    testWidgets(
      'Active student attempting to revisit first-login route is redirected to student dashboard',
      (tester) async {
        final activeStudent = UserModel(
          id: 'student-active',
          username: 'student.user',
          fullName: 'Active Student',
          email: 'student@example.com',
          role: UserRole.student,
          status: AccountStatus.active,
        );
        AuthRepository.instance.setCurrentUser(activeStudent);
        await LocalStorageService.saveUser(activeStudent);

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRoutes.studentHome: (ctx) =>
                  const Text('STUDENT_DASHBOARD_SCREEN'),
            },
            home: const AuthGuard(
              allowedRoles: [UserRole.student],
              isFirstLogin: true,
              child: Text('STUDENT_FIRST_LOGIN_FORM'),
            ),
          ),
        );

        expect(find.text('STUDENT_FIRST_LOGIN_FORM'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('STUDENT_DASHBOARD_SCREEN'), findsOneWidget);
      },
    );

    testWidgets(
      'Student post-first-login navigation enters student dashboard directly without error dialog or lockout',
      (tester) async {
        // Step 1: Student begins with pending first login
        final pendingStudent = UserModel(
          id: 'student-new',
          username: 'student.new',
          fullName: 'New Student',
          email: 'student.new@school.edu.ph',
          role: UserRole.student,
          status: AccountStatus.pendingFirstLogin,
        );
        AuthRepository.instance.setCurrentUser(pendingStudent);
        await LocalStorageService.saveUser(pendingStudent);

        // Step 2: Simulate OTP verification & password setup completion
        // Both in-memory AuthRepository and LocalStorageService are updated to active
        final activatedStudent = pendingStudent.copyWith(status: AccountStatus.active);
        AuthRepository.instance.setCurrentUser(activatedStudent);
        await LocalStorageService.saveUser(activatedStudent);

        // Step 3: Student navigates to studentHome wrapped in AuthGuard
        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRoutes.studentHome: (ctx) => const AuthGuard(
                    allowedRoles: [UserRole.student],
                    child: Text('STUDENT_DASHBOARD_HOME_LOADED'),
                  ),
              AppRoutes.studentFirstLogin: (ctx) => const Text('STUCK_IN_FIRST_LOGIN'),
              AppRoutes.login: (ctx) => const Text('CANNOT_ENTER_LOGIN_ERROR'),
            },
            initialRoute: AppRoutes.studentHome,
          ),
        );

        // Frame 1 and settled frame: User is recognized as active student
        await tester.pumpAndSettle();

        // Verification: User enters student dashboard directly without being redirected back or locked out
        expect(find.text('STUDENT_DASHBOARD_HOME_LOADED'), findsOneWidget);
        expect(find.text('STUCK_IN_FIRST_LOGIN'), findsNothing);
        expect(find.text('CANNOT_ENTER_LOGIN_ERROR'), findsNothing);
      },
    );

    testWidgets(
      'Archived user is locked out and redirected to login even if status says active',
      (tester) async {
        final archivedTeacher = UserModel(
          id: 'teacher-arch',
          username: 'arch.teacher',
          fullName: 'Archived Teacher',
          email: 'arch@example.com',
          role: UserRole.teacher,
          status: AccountStatus.active,
          isArchived: true,
        );
        AuthRepository.instance.setCurrentUser(archivedTeacher);

        await tester.pumpWidget(
          MaterialApp(
            routes: {AppRoutes.login: (ctx) => const Text('LOGIN_SCREEN')},
            home: const AuthGuard(
              allowedRoles: [UserRole.teacher],
              child: Text('PROTECTED_TEACHER_CONTENT'),
            ),
          ),
        );

        expect(find.text('PROTECTED_TEACHER_CONTENT'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('LOGIN_SCREEN'), findsOneWidget);
      },
    );

    testWidgets(
      'Full 4x4 Cross-Role Matrix in AuthGuard: Admin, Teacher, Student, Parent cannot access any other role',
      (tester) async {
        final usersByRole = <UserRole, UserModel>{
          UserRole.admin: UserModel(
            id: 'u-admin',
            username: 'admin',
            fullName: 'System Admin',
            email: 'admin@classrealm.edu',
            role: UserRole.admin,
            status: AccountStatus.active,
          ),
          UserRole.teacher: UserModel(
            id: 'u-teacher',
            username: 'teacher',
            fullName: 'Teacher One',
            email: 'teacher@classrealm.edu',
            role: UserRole.teacher,
            status: AccountStatus.active,
          ),
          UserRole.student: UserModel(
            id: 'u-student',
            username: 'student',
            fullName: 'Student One',
            email: 'student@classrealm.edu',
            role: UserRole.student,
            status: AccountStatus.active,
          ),
          UserRole.parent: UserModel(
            id: 'u-parent',
            username: 'parent',
            fullName: 'Parent One',
            email: 'parent@classrealm.edu',
            role: UserRole.parent,
            status: AccountStatus.active,
          ),
        };

        final dashboardMarkerByRole = <UserRole, String>{
          UserRole.admin: 'ADMIN_HOME_DEST',
          UserRole.teacher: 'TEACHER_HOME_DEST',
          UserRole.student: 'STUDENT_HOME_DEST',
          UserRole.parent: 'PARENT_HOME_DEST',
        };

        for (final attackerRole in UserRole.values) {
          for (final targetRole in UserRole.values) {
            if (attackerRole == targetRole) continue;

            AuthRepository.instance.setCurrentUser(usersByRole[attackerRole]);

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey('${attackerRole.name}_to_${targetRole.name}'),
                routes: {
                  AppRoutes.adminDashboard: (_) =>
                      const Text('ADMIN_HOME_DEST'),
                  AppRoutes.teacherDashboard: (_) =>
                      const Text('TEACHER_HOME_DEST'),
                  AppRoutes.studentHome: (_) => const Text('STUDENT_HOME_DEST'),
                  AppRoutes.parentHome: (_) => const Text('PARENT_HOME_DEST'),
                },
                home: AuthGuard(
                  allowedRoles: [targetRole],
                  child: Text('SECRET_${targetRole.name.toUpperCase()}_SCREEN'),
                ),
              ),
            );

            // 0 frames of unauthorized content rendered
            expect(
              find.text('SECRET_${targetRole.name.toUpperCase()}_SCREEN'),
              findsNothing,
              reason:
                  '${attackerRole.name} must never see ${targetRole.name} content on frame 1',
            );

            await tester.pumpAndSettle();

            // Option A: Redirected strictly back to attacker's own legitimate dashboard
            expect(
              find.text(dashboardMarkerByRole[attackerRole]!),
              findsOneWidget,
              reason:
                  '${attackerRole.name} attempting to access ${targetRole.name} must be redirected to ${dashboardMarkerByRole[attackerRole]}',
            );
            expect(
              find.text('SECRET_${targetRole.name.toUpperCase()}_SCREEN'),
              findsNothing,
            );
          }
        }
      },
    );
  });

  group('Strict 4x4 URL & F5 Route Gatekeeper (AppRoutes)', () {
    final adminRoutes = <String>[
      AppRoutes.adminDashboard,
      AppRoutes.adminBroadcasts,
      AppRoutes.adminTeacherManagement,
      AppRoutes.adminActivityAnalytics,
      AppRoutes.adminProfile,
      AppRoutes.adminAddTeacher,
    ];

    final teacherRoutes = <String>[
      AppRoutes.teacherDashboard,
      AppRoutes.teacherClassroomSetup,
      AppRoutes.teacherGradebook,
      AppRoutes.teacherManageStudents,
      AppRoutes.teacherManageParents,
      AppRoutes.teacherClasswork,
      teacherClassworkWithQuery,
      AppRoutes.teacherLessonPlanning,
      AppRoutes.teacherLearningMaterials,
      AppRoutes.teacherAttendance,
      AppRoutes.teacherGrades,
      AppRoutes.teacherSchedule,
      AppRoutes.teacherNotifications,
      AppRoutes.teacherProfile,
      AppRoutes.teacherSettings,
      AppRoutes.academicSetup,
    ];

    final studentRoutes = <String>[
      AppRoutes.studentHome,
      AppRoutes.studentClasswork,
      AppRoutes.studentAlerts,
      AppRoutes.studentProfile,
      AppRoutes.studentAttendance,
      AppRoutes.studentSchedule,
      AppRoutes.studentMaterials,
      AppRoutes.studentGrades,
      AppRoutes.studentPerformance,
    ];

    final parentRoutes = <String>[
      AppRoutes.parentHome,
      AppRoutes.parentAttendance,
      AppRoutes.parentSchedule,
      AppRoutes.parentAlerts,
      AppRoutes.parentProfile,
      AppRoutes.parentGrades,
    ];

    test('Admin can ONLY access Admin routes and NEVER Teacher/Student/Parent routes', () {
      for (final route in adminRoutes) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.admin),
          isTrue,
          reason: 'Admin should be allowed on $route',
        );
      }
      for (final route in [
        ...teacherRoutes,
        ...studentRoutes,
        ...parentRoutes,
        AppRoutes.teacherFirstLogin,
        AppRoutes.studentFirstLogin,
        AppRoutes.parentFirstLogin,
      ]) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.admin),
          isFalse,
          reason: 'Admin must NEVER access $route',
        );
      }
    });

    test('Teacher can ONLY access Teacher routes and NEVER Admin/Student/Parent routes', () {
      for (final route in teacherRoutes) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.teacher),
          isTrue,
          reason: 'Teacher should be allowed on $route',
        );
      }
      for (final route in [
        ...adminRoutes,
        ...studentRoutes,
        ...parentRoutes,
        AppRoutes.teacherFirstLogin,
        AppRoutes.studentFirstLogin,
        AppRoutes.parentFirstLogin,
      ]) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.teacher),
          isFalse,
          reason: 'Teacher must NEVER access $route',
        );
      }
    });

    test('Student can ONLY access Student routes and NEVER Admin/Teacher/Parent routes', () {
      for (final route in studentRoutes) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.student),
          isTrue,
          reason: 'Student should be allowed on $route',
        );
      }
      for (final route in [
        ...adminRoutes,
        ...teacherRoutes,
        ...parentRoutes,
        AppRoutes.teacherFirstLogin,
        AppRoutes.studentFirstLogin,
        AppRoutes.parentFirstLogin,
      ]) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.student),
          isFalse,
          reason: 'Student must NEVER access $route',
        );
      }
    });

    test('Parent can ONLY access Parent routes and NEVER Admin/Teacher/Student routes', () {
      for (final route in parentRoutes) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.parent),
          isTrue,
          reason: 'Parent should be allowed on $route',
        );
      }
      for (final route in [
        ...adminRoutes,
        ...teacherRoutes,
        ...studentRoutes,
        AppRoutes.teacherFirstLogin,
        AppRoutes.studentFirstLogin,
        AppRoutes.parentFirstLogin,
      ]) {
        expect(
          AppRoutes.isRouteAllowedForRole(route, UserRole.parent),
          isFalse,
          reason: 'Parent must NEVER access $route',
        );
      }
    });

    test('resolveSafeRouteForUser forces unauthorized F5/URL or stale last_active_route back to own dashboard', () {
      final admin = UserModel(
        id: '1',
        username: 'admin',
        fullName: 'Admin',
        email: 'admin@test.com',
        role: UserRole.admin,
      );
      final teacher = UserModel(
        id: '2',
        username: 'teacher',
        fullName: 'Teacher',
        email: 'teacher@test.com',
        role: UserRole.teacher,
      );
      final student = UserModel(
        id: '3',
        username: 'student',
        fullName: 'Student',
        email: 'student@test.com',
        role: UserRole.student,
      );
      final parent = UserModel(
        id: '4',
        username: 'parent',
        fullName: 'Parent',
        email: 'parent@test.com',
        role: UserRole.parent,
      );

      // Admin typing /teacher/gradebook or /student/home or /parent/home
      expect(
        AppRoutes.resolveSafeRouteForUser(
          admin,
          candidateRoute: AppRoutes.teacherGradebook,
          fallbackSavedRoute: AppRoutes.studentHome,
        ),
        AppRoutes.adminDashboard,
      );

      // Teacher typing /admin/dashboard or /student/grades or /parent/home
      expect(
        AppRoutes.resolveSafeRouteForUser(
          teacher,
          candidateRoute: AppRoutes.adminDashboard,
          fallbackSavedRoute: AppRoutes.parentHome,
        ),
        AppRoutes.teacherDashboard,
      );

      // Student typing /admin/teacher-management or /teacher/classwork or /parent/grades
      expect(
        AppRoutes.resolveSafeRouteForUser(
          student,
          candidateRoute: AppRoutes.adminTeacherManagement,
          fallbackSavedRoute: AppRoutes.teacherClasswork,
        ),
        AppRoutes.studentHome,
      );

      // Parent typing /student/home or /teacher/dashboard or /admin/dashboard
      expect(
        AppRoutes.resolveSafeRouteForUser(
          parent,
          candidateRoute: AppRoutes.studentHome,
          fallbackSavedRoute: AppRoutes.adminDashboard,
        ),
        AppRoutes.parentHome,
      );

      // Legitimate sub-route with query parameters is normalized to its safe MaterialApp route path
      expect(
        AppRoutes.resolveSafeRouteForUser(
          teacher,
          candidateRoute: '/teacher/classwork?tab=pt',
        ),
        AppRoutes.teacherClasswork,
      );
    });
  });

  group('LocalStorageService Tamper-Proof Signature Verification', () {
    test('Valid saved user is retrieved intact when signature matches', () async {
      await LocalStorageService.clearAuth();
      final student = UserModel(
        id: 'stu-001',
        username: 'juan',
        fullName: 'Juan Dela Cruz',
        email: 'juan@student.edu',
        role: UserRole.student,
        status: AccountStatus.active,
      );

      await LocalStorageService.saveUser(student);
      final cached = LocalStorageService.getCachedUser();
      expect(cached, isNotNull);
      expect(cached!.id, 'stu-001');
      expect(cached.role, UserRole.student);
    });

    test(
      'DevTools localStorage tampering of role (student -> admin) is immediately detected and purged',
      () async {
        await LocalStorageService.clearAuth();
        final student = UserModel(
          id: 'stu-001',
          username: 'juan',
          fullName: 'Juan Dela Cruz',
          email: 'juan@student.edu',
          role: UserRole.student,
          status: AccountStatus.active,
        );

        await LocalStorageService.saveUser(student);

        // Simulate attacker opening Chrome DevTools -> Application -> Local Storage
        // and editing "role":"student" to "role":"admin"
        final prefs = await SharedPreferences.getInstance();
        final rawJson = prefs.getString(LocalStorageService.keyCachedUser)!;
        final tamperedJson = rawJson.replaceAll(
          '"role":"student"',
          '"role":"admin"',
        );
        await prefs.setString(LocalStorageService.keyCachedUser, tamperedJson);

        // getCachedUser() must reject the tampered payload and wipe the cache
        final afterTamper = LocalStorageService.getCachedUser();
        expect(afterTamper, isNull);
        expect(prefs.getString(LocalStorageService.keyCachedUser), isNull);
        expect(prefs.getString(LocalStorageService.keyCachedUserSig), isNull);
      },
    );

    test(
      'DevTools localStorage tampering of user ID or linkedStudentId is detected and purged',
      () async {
        await LocalStorageService.clearAuth();
        final parent = UserModel(
          id: 'par-001',
          username: 'maria',
          fullName: 'Maria Dela Cruz',
          email: 'maria@parent.edu',
          role: UserRole.parent,
          status: AccountStatus.active,
          linkedStudentId: 'stu-001',
        );

        await LocalStorageService.saveUser(parent);

        // Simulate parent editing linkedStudentId to view another child's grades
        final prefs = await SharedPreferences.getInstance();
        final rawJson = prefs.getString(LocalStorageService.keyCachedUser)!;
        final tamperedJson = rawJson.replaceAll(
          '"linkedStudentId":"stu-001"',
          '"linkedStudentId":"stu-999-other-child"',
        );
        await prefs.setString(LocalStorageService.keyCachedUser, tamperedJson);

        final afterTamper = LocalStorageService.getCachedUser();
        expect(afterTamper, isNull);
      },
    );
  });
}

const String teacherClassworkWithQuery = '/teacher/classwork?tab=ww';
