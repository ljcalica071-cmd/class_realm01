import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  Widget buildSetupTab() {
    return const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TeacherClassroomSetupTab(),
        ),
      ),
    );
  }

  testWidgets(
    'renders classroom setup tab with top actions and relocated archived toggle button in section row',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSetupTab());
      await tester.pumpAndSettle();

      // Top banner buttons
      expect(find.text('Timetable & Schedule'), findsOneWidget);
      expect(find.text('Add Subject'), findsOneWidget);

      // Section header row has title and relocated toggle button
      expect(find.text('ACTIVE SUBJECTS'), findsOneWidget);
      expect(find.textContaining('Archived Subjects'), findsOneWidget);

      // Toggle to archived view
      await tester.tap(find.textContaining('Archived Subjects'));
      await tester.pumpAndSettle();

      expect(find.text('ARCHIVED SUBJECTS'), findsOneWidget);
      expect(find.textContaining('Active Subjects'), findsOneWidget);
      expect(find.text('No Archived Subjects'), findsOneWidget);
    },
  );

  testWidgets(
    'opens Add Subject form and displays required Term Block validation when 1 Term has empty term block',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSetupTab());
      await tester.pumpAndSettle();

      // Open Add Subject form
      await tester.tap(find.text('Add Subject'));
      await tester.pumpAndSettle();

      expect(find.text('Add Subject & Sections'), findsOneWidget);
      expect(find.text('Save Subject'), findsOneWidget);
      expect(find.text('SUBJECT TERM CONFIGURATION'), findsOneWidget);
      expect(find.text('Term Block (Active Term)'), findsOneWidget);

      // Enter subject name to pass subject name validation
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. General Mathematics'),
        'Advanced Mathematics',
      );

      // Enter section name
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. STEM 11-A'),
        'STEM 11-A',
      );

      // Enter valid weights summing to 100%
      final textFields = find.byType(TextField);
      // wwCtrl, ptCtrl, exCtrl are 2nd, 3rd, 4th textfields
      await tester.enterText(textFields.at(1), '20');
      await tester.enterText(textFields.at(2), '50');
      await tester.enterText(textFields.at(3), '30');
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);

      // Change terms taught to 1 Term Only
      await tester.tap(find.text('3 Terms (Full Year / Trimester)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 Term Only').last);
      await tester.pumpAndSettle();

      // Verify Term Block is marked required with asterisk
      expect(find.text('*'), findsWidgets);
    },
  );
}
