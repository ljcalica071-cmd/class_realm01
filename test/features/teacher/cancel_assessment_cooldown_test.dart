import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/widgets/teacher_unified_assessments_tab.dart';
import 'package:class_realm/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleQuiz = QuizOrExamModel(
    id: 'test-quiz-101',
    title: 'Quiz 3',
    description: 'Quiz 3 description',
    subject: 'General Mathematics',
    section: 'Section B2',
    scheduleDate: DateTime.now().add(const Duration(hours: 1)),
    durationMinutes: 45,
    maxScore: 50,
    isExam: false,
    questions: const [],
  );

  final sampleExam = QuizOrExamModel(
    id: 'test-exam-202',
    title: 'Midterm Examination',
    description: 'Midterm description',
    subject: 'General Mathematics',
    section: 'Section B2',
    scheduleDate: DateTime.now().add(const Duration(hours: 2)),
    durationMinutes: 90,
    maxScore: 100,
    isExam: true,
    questions: const [],
  );

  testWidgets(
    'CancelAssessmentDialog enforces 5-second cooldown and clear warning on Quiz',
    (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => CancelAssessmentDialog(item: sampleQuiz),
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Open the Cancel Quiz dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pump(); // Build dialog

      // 1. Verify clear warning content
      expect(find.text('Cancel Quiz'), findsOneWidget);
      expect(
        find.text('Are you sure you want to cancel "Quiz 3"?'),
        findsOneWidget,
      );
      expect(
        find.text('Active student sessions will end immediately.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Recorded attempts and scores will be voided (no student penalized).',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'This quiz and its HPS will be removed so you can recreate it anytime.',
        ),
        findsOneWidget,
      );

      // 2. Verify cooldown banner and initial 5-second state
      expect(
        find.text(
          'Cooldown active: Wait 5s before cancellation to prevent accidental action.',
        ),
        findsOneWidget,
      );
      expect(find.text('Yes, Cancel Quiz (5s)'), findsOneWidget);

      // Verify the button cannot be tapped yet
      await tester.tap(find.text('Yes, Cancel Quiz (5s)'), warnIfMissed: false);
      expect(find.text('Cancel Quiz'), findsOneWidget); // still open!
      expect(result, isNull);

      // 3. Advance timer by 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Yes, Cancel Quiz (3s)'), findsOneWidget);
      expect(
        find.text(
          'Cooldown active: Wait 3s before cancellation to prevent accidental action.',
        ),
        findsOneWidget,
      );

      // 4. Advance timer by 3 more seconds to complete cooldown
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Yes, Cancel Quiz'), findsOneWidget);
      expect(find.text('Yes, Cancel Quiz (3s)'), findsNothing);
      expect(
        find.textContaining('Cooldown active:'),
        findsNothing,
      );

      // 5. Now tap the enabled button
      await tester.tap(find.text('Yes, Cancel Quiz'));
      await tester.pumpAndSettle();

      // Dialog dismissed with true
      expect(find.text('Cancel Quiz'), findsNothing);
      expect(result, isTrue);
    },
  );

  testWidgets(
    'CancelAssessmentDialog displays Examination title and can be dismissed via Keep Assessment',
    (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => CancelAssessmentDialog(item: sampleExam),
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();

      expect(find.text('Cancel Examination'), findsOneWidget);
      expect(
        find.text('Are you sure you want to cancel "Midterm Examination"?'),
        findsOneWidget,
      );
      expect(find.text('Yes, Cancel Exam (5s)'), findsOneWidget);

      // Dismiss early via Keep Assessment
      await tester.tap(find.text('Keep Assessment'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Examination'), findsNothing);
      expect(result, isFalse);
    },
  );

  testWidgets(
    'DeleteConfirmationDialog clearly states permanent deletion and gradebook removal',
    (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => DeleteConfirmationDialog(
                          title: 'Activity 2',
                          itemType: 'Activity',
                          onDelete: () {
                            deleteCalled = true;
                          },
                        ),
                      );
                    },
                    child: const Text('Open Delete Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Delete Dialog'));
      await tester.pumpAndSettle();

      // 1. Verify dialog header and item name
      expect(find.text('Delete Item'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete this activity?'),
        findsOneWidget,
      );
      expect(find.text('Activity 2'), findsOneWidget);

      // 2. Verify clear consequence bullets
      expect(
        find.text(
          'This activity and its record will be permanently deleted from Classwork.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Its corresponding column and highest possible score (HPS) will be removed from the Gradebook.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('This action is permanent and cannot be undone.'),
        findsOneWidget,
      );

      // 3. Confirm deletion
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Item'), findsNothing);
      expect(deleteCalled, isTrue);
    },
  );
}
