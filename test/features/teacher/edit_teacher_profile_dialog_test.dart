import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/edit_teacher_profile_dialog.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/consultation_hours_picker.dart';

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
    contactNumber: '09123456789',
    facebookLink: 'https://facebook.com/karen.gonzaga',
    consultationHours: 'Mon, Wed 01:00 PM - 03:00 PM',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    AuthRepository.instance.currentUser = testTeacher;
  });

  group('EditTeacherProfileDialog & Validation Tests', () {
    testWidgets('renders dialog with initial user data and form fields', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Faculty Profile'), findsOneWidget);
      expect(find.byType(ConsultationHoursPicker), findsOneWidget);
      expect(find.text('Karen'), findsOneWidget);
      expect(find.text('Gonzaga'), findsOneWidget);
      expect(find.text('gonzagakaren.kg@gmail.com'), findsOneWidget);
    });

    testWidgets('validates phone number: requires 11-digit 09 format and shows inline error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the phone text field and enter invalid 08 number
      final phoneField = find.widgetWithText(TextField, '09123456789');
      expect(phoneField, findsOneWidget);

      await tester.enterText(phoneField, '08123456789');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify inline error message
      expect(
        find.text('Phone number must be an 11-digit mobile number starting with 09 (e.g. 09123456789).'),
        findsOneWidget,
      );
    });

    testWidgets('validates Facebook link: requires valid URL format and shows inline error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter invalid Facebook URL
      final fbField = find.widgetWithText(TextField, 'https://facebook.com/karen.gonzaga');
      expect(fbField, findsOneWidget);

      await tester.enterText(fbField, 'not-a-valid-url');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify inline error message
      expect(
        find.text('Enter a valid Facebook profile URL (e.g. https://facebook.com/karen.gonzaga).'),
        findsOneWidget,
      );
    });

    testWidgets('Save Changes button is disabled when no changes are made and enables upon editing', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No changes made'), findsOneWidget);
      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'Save Changes');
      expect(saveBtnFinder, findsOneWidget);

      final elevatedButton = tester.widget<ElevatedButton>(saveBtnFinder);
      expect(elevatedButton.onPressed, isNull);

      // Modify first name
      final fNameField = find.widgetWithText(TextField, 'Karen');
      await tester.enterText(fNameField, 'Karen Joy');
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      final updatedBtn = tester.widget<ElevatedButton>(saveBtnFinder);
      expect(updatedBtn.onPressed, isNotNull);
    });

    testWidgets('allows clearing consultation schedule completely (optional field)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Clear All'
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      expect(find.text('No consultation schedule set (Optional).'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);
    });

    testWidgets('displays live character counters for names and specialization', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Karen" length = 5 / 30
      expect(find.text('5/30'), findsOneWidget);
      // "Gonzaga" length = 7 / 30
      expect(find.text('7/30'), findsOneWidget);
      // Middle Initial = 0 / 2
      expect(find.text('0/2'), findsOneWidget);
      // Specialization = 0 / 100
      expect(find.text('0/100'), findsOneWidget);
    });

    testWidgets('clears error messages live as user corrects the input', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final phoneField = find.widgetWithText(TextField, '09123456789');
      // Enter invalid phone
      await tester.enterText(phoneField, '08123456789');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Phone number must be an 11-digit mobile number starting with 09 (e.g. 09123456789).'),
        findsOneWidget,
      );

      // Now correct the phone live
      final updatedPhoneField = find.widgetWithText(TextField, '08123456789');
      await tester.enterText(updatedPhoneField, '09987654321');
      await tester.pumpAndSettle();

      // Error must immediately disappear live
      expect(
        find.text('Phone number must be an 11-digit mobile number starting with 09 (e.g. 09123456789).'),
        findsNothing,
      );
    });

    testWidgets('enables Save Changes when only facebook or specialization is modified', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTeacherProfileDialog(teacher: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No changes made'), findsOneWidget);

      // Enter specialization
      final specField = find.widgetWithText(
        TextField,
        'e.g. General Mathematics & Statistics (Optional)',
      );
      await tester.enterText(specField, 'Advanced Physics');
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'Save Changes');
      final btn = tester.widget<ElevatedButton>(saveBtnFinder);
      expect(btn.onPressed, isNotNull);
    });
  });
}
