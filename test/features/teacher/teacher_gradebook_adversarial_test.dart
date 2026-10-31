import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';

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

  group('Adversarial Stress Test: buildTwoTierHeader Overflow & Fractional DPRs', () {
    for (final dpr in [1.0, 1.25, 1.333, 1.5, 1.75, 2.0, 2.625, 3.0]) {
      testWidgets('Zero overflow in buildTwoTierHeader at DPR $dpr', (tester) async {
        tester.view.physicalSize = Size(1400 * dpr, 900 * dpr);
        tester.view.devicePixelRatio = dpr;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildGradebook());
        await tester.pumpAndSettle();

        // Switch to FINAL GRADES to invoke buildTwoTierHeader()
        await tester.tap(find.text('FINAL GRADES'));
        await tester.pumpAndSettle();

        expect(find.text('TERM GRADES'), findsOneWidget);
        expect(find.text('FINAL GRADE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Adversarial Stress Test: Slot Expansion Exhaustion & Boundary Limits', () {
    testWidgets('Slots strictly expand from 5 to 10 and cannot exceed 10', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildGradebook());
      await tester.pumpAndSettle();

      final addWw = find.byKey(const ValueKey('add-slot-ww'));
      expect(addWw, findsOneWidget);

      // Verify slot 5 exists, slot 6 does not exist initially
      expect(find.widgetWithText(Container, '5'), findsWidgets);
      expect(find.widgetWithText(Container, '6'), findsNothing);

      // Expand to 10
      for (int i = 6; i <= 10; i++) {
        await tester.tap(addWw);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(Container, '$i'), findsWidgets);
      }

      // At 10, the add button must vanish
      expect(find.byKey(const ValueKey('add-slot-ww')), findsNothing);
      expect(find.widgetWithText(Container, '11'), findsNothing);
    });
  });

  group('Adversarial Stress Test: Rapid Symmetrical Gender Toggling Across Views', () {
    testWidgets('Rapid gender toggles across Term and Final Grades views without error', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildGradebook());
      await tester.pumpAndSettle();

      final genders = ['Female', 'All', 'Male', 'Female', 'Male', 'All', 'Female'];
      for (final g in genders) {
        await tester.tap(find.text(g));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to Final Grades tab and repeat
      await tester.tap(find.text('FINAL GRADES'));
      await tester.pumpAndSettle();

      for (final g in genders) {
        await tester.tap(find.text(g));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
