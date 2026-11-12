import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/session_activity_tracker.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  setUp(() {
    AuthRepository.instance.setCurrentUser(null);
  });

  tearDown(() {
    AuthRepository.instance.setCurrentUser(null);
  });

  group('Session Inactivity Auto-Logout Tests (All 4 Roles)', () {
    final roles = [
      UserRole.admin,
      UserRole.teacher,
      UserRole.student,
      UserRole.parent,
    ];

    for (final role in roles) {
      testWidgets('Auto-logout triggers after 30 minutes of inactivity for ${role.name}', (
        tester,
      ) async {
        DateTime fakeTime = DateTime(2026, 11, 12, 10, 0, 0);
        SessionActivityTracker.nowProvider = () => fakeTime;
        addTearDown(() {
          SessionActivityTracker.nowProvider = DateTime.now;
        });

        final user = UserModel(
          id: 'user-${role.name}',
          username: '${role.name}_user',
          fullName: 'Test ${role.name}',
          email: '${role.name}@test.com',
          role: role,
          status: AccountStatus.active,
        );
        AuthRepository.instance.setCurrentUser(user);

        bool loggedOut = false;

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: AppRoutes.navigatorKey,
            routes: {
              AppRoutes.login: (ctx) {
                loggedOut = true;
                return const Scaffold(body: Text('LOGIN_SCREEN'));
              },
              '/dashboard': (ctx) => const Scaffold(body: Text('DASHBOARD_CONTENT')),
            },
            initialRoute: '/dashboard',
            builder: (ctx, child) => SessionActivityTracker(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );

        expect(find.text('DASHBOARD_CONTENT'), findsOneWidget);
        expect(loggedOut, isFalse);

        // Advance 28 minutes: warning modal appears
        fakeTime = fakeTime.add(const Duration(minutes: 28));
        await tester.pump(const Duration(seconds: 15));
        expect(find.text('Inactivity Warning'), findsOneWidget);
        expect(loggedOut, isFalse);

        // Advance remaining 2 minutes without user pressing anything (total 30 minutes)
        fakeTime = fakeTime.add(const Duration(minutes: 2, seconds: 15));
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();

        // Must be automatically logged out and navigated to login
        expect(loggedOut, isTrue);
        expect(find.text('LOGIN_SCREEN'), findsOneWidget);
      });
    }

    testWidgets('User interaction resets the inactivity timer', (tester) async {
      DateTime fakeTime = DateTime(2026, 11, 12, 10, 0, 0);
      SessionActivityTracker.nowProvider = () => fakeTime;
      addTearDown(() {
        SessionActivityTracker.nowProvider = DateTime.now;
      });

      final user = UserModel(
        id: 'user-active',
        username: 'active_student',
        fullName: 'Active Student',
        email: 'student@test.com',
        role: UserRole.student,
        status: AccountStatus.active,
      );
      AuthRepository.instance.setCurrentUser(user);

      bool loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppRoutes.navigatorKey,
          routes: {
            AppRoutes.login: (ctx) {
              loggedOut = true;
              return const Scaffold(body: Text('LOGIN_SCREEN'));
            },
            '/dashboard': (ctx) => const Scaffold(
              body: Center(child: Text('DASHBOARD_CONTENT')),
            ),
          },
          initialRoute: '/dashboard',
          builder: (ctx, child) => SessionActivityTracker(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );

      // Advance 20 minutes (still active)
      fakeTime = fakeTime.add(const Duration(minutes: 20));
      await tester.pump(const Duration(seconds: 15));
      expect(loggedOut, isFalse);

      // Simulate pointer movement / touch / click interaction
      final center = tester.getCenter(find.text('DASHBOARD_CONTENT'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      await gesture.moveTo(center + const Offset(10, 10));
      await tester.pump();
      await gesture.removePointer();

      // Advance another 20 minutes (only 20m elapsed since last interaction, total 40m)
      fakeTime = fakeTime.add(const Duration(minutes: 20));
      await tester.pump(const Duration(seconds: 15));

      // Should NOT be logged out because the timer was reset at minute 20
      expect(loggedOut, isFalse);
      expect(find.text('DASHBOARD_CONTENT'), findsOneWidget);
    });

    testWidgets('AppLifecycleCoordinator.onResume detects >= 30m inactivity and auto-logouts', (
      tester,
    ) async {
      final user = UserModel(
        id: 'user-sleep',
        username: 'teacher_sleep',
        fullName: 'Teacher Sleep',
        email: 'teacher@test.com',
        role: UserRole.teacher,
        status: AccountStatus.active,
      );
      AuthRepository.instance.setCurrentUser(user);

      bool loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppRoutes.navigatorKey,
          routes: {
            AppRoutes.login: (ctx) {
              loggedOut = true;
              return const Scaffold(body: Text('LOGIN_SCREEN'));
            },
            '/dashboard': (ctx) => const Scaffold(body: Text('DASHBOARD_CONTENT')),
          },
          initialRoute: '/dashboard',
          builder: (ctx, child) => child ?? const SizedBox.shrink(),
        ),
      );

      // Simulate last interaction 35 minutes ago (e.g. computer was in sleep mode or tab backgrounded)
      final pastTime = DateTime.now().subtract(const Duration(minutes: 35));
      await LocalStorageService.saveLastInteraction(pastTime);

      // Trigger lifecycle resume
      AppLifecycleCoordinator.instance.onResume();
      await tester.pumpAndSettle();

      // Must immediately logout on resume
      expect(loggedOut, isTrue);
      expect(find.text('LOGIN_SCREEN'), findsOneWidget);
    });
  });
}
