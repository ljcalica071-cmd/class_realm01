import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/teacher_profile_tab.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/edit_teacher_profile_dialog.dart';
import 'package:class_realm/shared/widgets/portal_settings_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTeacher = UserModel(
    id: 'T001',
    username: 'testteacher',
    fullName: 'Karen Gonzaga',
    firstName: 'Karen',
    lastName: 'Gonzaga',
    email: 'gonzagakaren.kg@gmail.com',
    role: UserRole.teacher,
    status: AccountStatus.active,
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    AuthRepository.instance.currentUser = testTeacher;
  });

  group('TeacherProfileTab with Settings & About tabs', () {
    testWidgets('renders About and Settings tabs, initially showing About content', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherProfileTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check teacher profile header
      expect(find.text('Karen Gonzaga'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // About tab is selected by default
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Contact & Professional Info'), findsOneWidget);
      expect(find.byType(PortalSettingsContent), findsNothing);
    });

    testWidgets('switching to Settings tab slides to Settings & Privacy content', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherProfileTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Settings' tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Settings content should now be visible
      expect(find.byType(PortalSettingsContent), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      // Switching back to About
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.byType(PortalSettingsContent), findsNothing);
    });

    testWidgets('TeacherProfileTab with initialTab: 1 starts directly on Settings tab', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherProfileTab(initialTab: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PortalSettingsContent), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('Edit Profile button opens EditTeacherProfileDialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeacherProfileTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check button text
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Edit Profile (Next Update)'), findsNothing);

      // Tap Edit Profile button
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Verify modal is open with identity and settings fields
      expect(find.byType(EditTeacherProfileDialog), findsOneWidget);
      expect(find.text('Edit Faculty Profile'), findsOneWidget);
      expect(find.text('First Name *'), findsOneWidget);
      expect(find.text('Last Name *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('Subject Specialization'), findsWidgets);
      expect(find.text('Consultation Schedule'), findsOneWidget);
      expect(find.text('Mobile Phone Number'), findsOneWidget);
      expect(find.text('Facebook Profile Link'), findsOneWidget);
    });
  });
}
