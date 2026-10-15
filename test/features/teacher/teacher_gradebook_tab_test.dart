import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  Widget buildGradebook() {
    return const MaterialApp(
      home: Scaffold(
        body: TeacherGradebookTab(),
      ),
    );
  }

  testWidgets(
    'renders Gradebook layout with Informational Note Banner when no subjects/students exist',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildGradebook());
      await tester.pumpAndSettle();

      // 1. Informational Note Banner is displayed
      expect(
        find.textContaining('Note: You currently have no subjects with enrolled students'),
        findsOneWidget,
      );

      // 2. Redundant title block is removed
      expect(
        find.text('Strengthened Senior High School Class Record'),
        findsNothing,
      );

      // 3. Metadata pill badges are removed
      expect(find.textContaining('Terms: 3'), findsNothing);
      expect(find.textContaining('Units: 2 / Term'), findsNothing);
      expect(find.textContaining('S.Y.: 2026-2027'), findsNothing);

      // 4. "No students yet" placeholder rows are displayed under MALE and FEMALE
      expect(find.text('No students yet'), findsWidgets);

      // 5. Grid cells exist but are disabled
      final cells = find.byType(GradebookGridCell);
      expect(cells, findsWidgets);
      final firstCell = tester.widget<GradebookGridCell>(cells.first);
      expect(firstCell.isEnabled, isFalse);
    },
  );

  testWidgets(
    'renders FINAL GRADES tab with official DepEd two-tier header, full width, and no unnecessary metadata',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildGradebook());
      await tester.pumpAndSettle();

      // Tap FINAL GRADES tab
      await tester.tap(find.text('FINAL GRADES'));
      await tester.pumpAndSettle();

      // 1. Two-tier DepEd header elements exist
      expect(find.text('TERM GRADES'), findsOneWidget);
      expect(find.text('FIRST TERM'), findsOneWidget);
      expect(find.text('SECOND TERM'), findsOneWidget);
      expect(find.text('THIRD TERM'), findsOneWidget);
      expect(find.text('FINAL GRADE'), findsOneWidget);
      expect(find.text('DESCRIPTOR'), findsOneWidget);
      expect(find.text('REMARK'), findsOneWidget);

      // 2. Unnecessary metadata box removed
      expect(find.text('NO. OF TERMS'), findsNothing);
      expect(find.text('TERM BLOCKS'), findsNothing);
      expect(find.text('UNITS PER TERM'), findsNothing);
      expect(find.text('TOTAL UNITS EARNED'), findsNothing);

      // 3. Gender headers and placeholders exist
      expect(find.text('MALE'), findsOneWidget);
      expect(find.text('FEMALE'), findsOneWidget);
      expect(find.text('No students yet'), findsWidgets);
    },
  );
}
