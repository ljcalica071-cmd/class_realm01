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

      // 3. Gender toggle buttons and active gender header exist
      expect(find.text('MALE (0)'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('No students yet'), findsWidgets);

      // Tapping Female toggle switches active gender section cleanly
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      expect(find.text('FEMALE (0)'), findsOneWidget);
    },
  );

  testWidgets(
    'gender filter switches cleanly between All, Male, and Female without duplicating rows or throwing assertions',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildGradebook());
      await tester.pumpAndSettle();

      // Initially on Term 1 with Male selected
      expect(find.text('MALE (0)'), findsOneWidget);
      expect(find.text('FEMALE (0)'), findsNothing);

      // 1. Switch to Female filter
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();

      expect(find.text('FEMALE (0)'), findsOneWidget);
      expect(find.text('MALE (0)'), findsNothing);

      // 2. Switch to All filter
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('MALE (0)'), findsOneWidget);
      expect(find.text('FEMALE (0)'), findsOneWidget);

      // 3. Switch back to Male filter
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();

      expect(find.text('MALE (0)'), findsOneWidget);
      expect(find.text('FEMALE (0)'), findsNothing);
    },
  );

  testWidgets(
    'assessment score columns dynamically expand from 5 up to 10 slots with inline "+" button',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildGradebook());
      await tester.pumpAndSettle();

      // Verify initial 5 Written Works slots and '+' button
      final addWwFinder = find.byKey(const ValueKey('add-slot-ww'));
      expect(addWwFinder, findsOneWidget);
      expect(find.byTooltip('Add Written Work slot'), findsOneWidget);

      // Verify column '5' is present
      expect(find.widgetWithText(Container, '5'), findsWidgets);

      // Increment WW slots one by one up to 10
      for (int slot = 6; slot <= 10; slot++) {
        await tester.tap(addWwFinder);
        await tester.pumpAndSettle();
      }

      // At 10 slots, '+' button for WW should disappear
      expect(find.byKey(const ValueKey('add-slot-ww')), findsNothing);
      expect(find.byTooltip('Add Written Work slot'), findsNothing);

      // Verify Performance Tasks '+' button exists and expand it up to 10
      final addPtFinder = find.byKey(const ValueKey('add-slot-pt'));
      expect(addPtFinder, findsOneWidget);
      expect(find.byTooltip('Add Performance Task slot'), findsOneWidget);

      for (int slot = 6; slot <= 10; slot++) {
        await tester.tap(addPtFinder);
        await tester.pumpAndSettle();
      }

      // At 10 slots, '+' button for PT should disappear
      expect(find.byKey(const ValueKey('add-slot-pt')), findsNothing);
      expect(find.byTooltip('Add Performance Task slot'), findsNothing);
    },
  );
}
