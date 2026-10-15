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
}
