import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/widgets/teacher_unified_assessments_tab.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

void main() {
  tearDown(() {
    CreateAssessmentFlowDialog.creationCooldown.reset();
    CreateAssessmentFlowDialog.aiGenerationCooldown.reset();
  });

  group('TeacherUnifiedAssessmentsTab creation cooldown UI', () {
    testWidgets(
      'disables Create Quiz button during 1-minute cooldown',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        CreateAssessmentFlowDialog.creationCooldown.trigger();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TeacherUnifiedAssessmentsTab(
                activities: [],
                assessments: [],
              ),
            ),
          ),
        );
        await tester.pump();

        final quizBtnFinder = find.byWidgetPredicate(
          (w) =>
              w is AppButton &&
              w.label.startsWith('Create Quiz (') &&
              w.label.endsWith('s)'),
        );
        expect(quizBtnFinder, findsOneWidget);
        final quizBtn = tester.widget<AppButton>(quizBtnFinder);
        expect(quizBtn.onPressed, isNull);

        CreateAssessmentFlowDialog.creationCooldown.reset();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'enables Create Quiz when no cooldown is active',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        CreateAssessmentFlowDialog.creationCooldown.reset();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TeacherUnifiedAssessmentsTab(
                activities: [],
                assessments: [],
              ),
            ),
          ),
        );
        await tester.pump();

        final quizBtnFinder = find.widgetWithText(AppButton, 'Create Quiz');
        expect(quizBtnFinder, findsOneWidget);
        final quizBtn = tester.widget<AppButton>(quizBtnFinder);
        expect(quizBtn.onPressed, isNotNull);
      },
    );
  });
}
