import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';

void main() {
  group('CreateAssessmentFlowDialog In-Person & Slot Locking', () {
    testWidgets('shows Set Date * when switching to In-Person mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateAssessmentFlowDialog(
              onAssessmentCreated: () {},
              initialIsExam: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Scheduled Date *'), findsOneWidget);
      expect(find.text('Question Distributions (3 Types)'), findsOneWidget);
      expect(find.text('View Complete Anti-Cheating & Exam Taking Guidelines'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('In-Person (Manual Record)'));
      await tester.pump();

      expect(find.text('Set Date *'), findsOneWidget);
      expect(find.text('Date Administered *'), findsNothing);
      expect(find.text('Question Distributions (3 Types)'), findsNothing);
      expect(find.text('View Complete Anti-Cheating & Exam Taking Guidelines'), findsNothing);
      expect(find.text('Publish Examination'), findsOneWidget);
    });
  });
}
