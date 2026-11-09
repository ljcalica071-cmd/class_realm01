import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_assessment_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppDataCache.instance.clearAll();
  });

  QuizOrExamModel createSampleExam({bool resultsReleased = false}) {
    return QuizOrExamModel(
      id: 'test-exam-101',
      title: 'Periodical Examination in Biology',
      description: 'Summative Periodical Examination covering Terms 1 to 2.',
      subject: 'General Biology',
      section: 'Grade 10 - Rizal',
      isExam: true,
      examType: 'st1',
      durationMinutes: 45,
      scheduleDate: DateTime.now(),
      isPublished: true,
      resultsReleased: resultsReleased,
      questions: [
        QuestionModel(
          id: 'q-mc-1',
          questionText: 'Which organelle is considered the powerhouse of the cell?',
          type: QuestionType.multipleChoice,
          points: 1.0,
          choices: ['Mitochondria', 'Ribosome', 'Nucleus', 'Chloroplast'],
          correctAnswer: 'A',
        ),
        QuestionModel(
          id: 'q-tf-2',
          questionText: 'Photosynthesis occurs primarily in plant cell mitochondria.',
          type: QuestionType.trueFalse,
          points: 1.0,
          choices: ['True', 'False'],
          correctAnswer: 'False',
        ),
        QuestionModel(
          id: 'q-id-3',
          questionText: 'State the acronym of the primary molecule that stores genetic information.',
          type: QuestionType.identification,
          points: 1.0,
          correctAnswer: 'DNA',
        ),
      ],
    );
  }

  Widget createTestWidget(QuizOrExamModel exam) {
    return MaterialApp(
      home: Scaffold(
        body: StudentAssessmentScreen(assessment: exam),
      ),
    );
  }

  group('StudentAssessmentScreen End-to-End Student Side Flow', () {
    testWidgets('Step 0: Student must acknowledge examination rules before starting', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam();
      await tester.pumpWidget(createTestWidget(exam));
      await tester.pumpAndSettle();

      // Check header and rules display
      expect(find.text('Assessment Rules & Guidelines:'), findsOneWidget);
      expect(find.textContaining('Time Limit: 45 minutes timer.'), findsOneWidget);
      expect(find.textContaining('Anti-Cheating Policy:'), findsOneWidget);

      // Verify START ASSESSMENT button is disabled initially
      final startBtnFinder = find.widgetWithText(ElevatedButton, 'START ASSESSMENT');
      expect(startBtnFinder, findsOneWidget);
      ElevatedButton startBtn = tester.widget(startBtnFinder);
      expect(startBtn.onPressed, isNull);

      // Check acknowledgment checkbox
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Button must now be enabled
      startBtn = tester.widget(startBtnFinder);
      expect(startBtn.onPressed, isNotNull);

      // Tap start assessment
      await tester.ensureVisible(startBtnFinder);
      await tester.tap(startBtnFinder);
      await tester.pumpAndSettle();

      // Should now be in Step 1 (Question answering view)
      expect(find.textContaining('Question 1 of 3'), findsOneWidget);
      expect(find.text('0 / 3 answered'), findsOneWidget);
      expect(find.textContaining('Violations: 0'), findsOneWidget);
    });

    testWidgets('Step 1: Student answers MC, TF, and Identification questions with integer points', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam();
      await tester.pumpWidget(createTestWidget(exam));
      await tester.pumpAndSettle();

      // Accept rules & start
      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      final startBtnFinder = find.widgetWithText(ElevatedButton, 'START ASSESSMENT');
      await tester.ensureVisible(startBtnFinder);
      await tester.tap(startBtnFinder);
      await tester.pumpAndSettle();

      // Verify Question 1 (MC) points badge has no decimals: '1 Point'
      expect(find.text('1 Point'), findsOneWidget);
      expect(find.text('MULTIPLECHOICE'), findsOneWidget);

      // Answer Question 1: Select Mitochondria
      final optMito = find.text('Mitochondria');
      expect(optMito, findsOneWidget);
      await tester.tap(optMito);
      await tester.pumpAndSettle();

      // Check progress updated
      expect(find.text('1 / 3 answered'), findsOneWidget);

      // Navigate to Question 2 via Next button
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Question 2 of 3'), findsOneWidget);
      expect(find.text('TRUEFALSE'), findsOneWidget);

      // Answer Question 2: Select False
      final optFalse = find.text('False');
      expect(optFalse, findsOneWidget);
      await tester.tap(optFalse);
      await tester.pumpAndSettle();

      expect(find.text('2 / 3 answered'), findsOneWidget);

      // Navigate to Question 3 via Next button
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Question 3 of 3'), findsOneWidget);
      expect(find.text('IDENTIFICATION'), findsOneWidget);

      // Enter answer in text field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'DNA');
      await tester.pumpAndSettle();

      // All 3 questions answered
      expect(find.text('3 / 3 answered'), findsOneWidget);

      // Last question displays 'Submit Assessment'
      expect(find.text('Submit Assessment'), findsOneWidget);
    });

    testWidgets('Step 1: Identification Quick "N/A" Button fills answer', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam();
      await tester.pumpWidget(createTestWidget(exam));
      await tester.pumpAndSettle();

      // Accept rules and jump to Question 3
      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      final startBtnFinder = find.widgetWithText(ElevatedButton, 'START ASSESSMENT');
      await tester.ensureVisible(startBtnFinder);
      await tester.tap(startBtnFinder);
      await tester.pumpAndSettle();

      // Tap Next twice to reach Question 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Question 3 of 3'), findsOneWidget);

      // Tap Insert 'N/A' button
      final naBtn = find.text("Insert 'N/A' (I don't know)");
      expect(naBtn, findsOneWidget);
      await tester.tap(naBtn);
      await tester.pumpAndSettle();

      // Verify text field contains 'N/A'
      expect(find.text('N/A'), findsWidgets);
      expect(find.text('1 / 3 answered'), findsOneWidget);
    });

    testWidgets('Step 1: Auto-Resume restores in-progress answers and saved index from vault', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam();
      final prefs = await SharedPreferences.getInstance();

      // Pre-seed the vault key with an in-progress exam at Question index 1 (Question 2)
      final vaultKey = StudentAssessmentScreen.vaultKeyFor(exam.id, 'student');
      final pointerKey = StudentAssessmentScreen.activePointerKeyFor('student');

      final vaultData = jsonEncode({
        'assessmentId': exam.id,
        'studentId': 'student',
        'currentStep': 1,
        'rulesAccepted': true,
        'currentQuestionIndex': 1, // Question 2
        'questionOrderIds': exam.questions.map((q) => q.id).toList(),
        'answers': {
          'q-mc-1': 'Mitochondria',
        },
        'secondsRemaining': 2000,
        'violations': 0,
      });

      await prefs.setString(vaultKey, vaultData);
      await prefs.setString(pointerKey, vaultData);
      AppDataCache.instance.set<String>(vaultKey, vaultData);
      AppDataCache.instance.set<String>(pointerKey, vaultData);

      await tester.pumpWidget(createTestWidget(exam));
      await tester.pumpAndSettle();

      // Must bypass Step 0 directly into Step 1 at Question 2
      expect(find.text('Assessment Rules & Guidelines:'), findsNothing);
      expect(find.textContaining('Question 2 of 3'), findsOneWidget);
      expect(find.text('1 / 3 answered'), findsOneWidget);
    });

    testWidgets('Step 2: Submitting answers transitions to result summary with whole integer score', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam(resultsReleased: false);
      await tester.pumpWidget(createTestWidget(exam));
      await tester.pumpAndSettle();

      // Start exam
      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      final startBtnFinder = find.widgetWithText(ElevatedButton, 'START ASSESSMENT');
      await tester.ensureVisible(startBtnFinder);
      await tester.tap(startBtnFinder);
      await tester.pumpAndSettle();

      // Answer Q1 correctly
      await tester.tap(find.text('Mitochondria'));
      await tester.pumpAndSettle();

      // Move to Q2 and answer correctly
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('False'));
      await tester.pumpAndSettle();

      // Move to Q3 and answer correctly
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DNA');
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.text('Submit Assessment');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Should transition to Step 2 Result Summary
      expect(find.textContaining('Completed & Submitted!'), findsOneWidget);

      // Student IMMEDIATELY sees their score (whole integer, no decimals)
      expect(find.text('Score Obtained: 3 / 3 pts'), findsOneWidget);
      expect(find.text('Percentage: 100%'), findsOneWidget);

      // Since resultsReleased == false, verify Answer Key review is locked
      expect(
        find.textContaining('Answer Key Locked: Your teacher has not released the item-by-item answer key review yet.'),
        findsOneWidget,
      );
      expect(find.text('Review Questions & Answer Key'), findsNothing);
    });

    testWidgets('Step 2: When resultsReleased is true, Review Questions & Answer Key button is active', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam(resultsReleased: true);
      await tester.pumpWidget(createTestWidget(exam));
      await tester.pumpAndSettle();

      // Start exam
      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      final startBtnFinder = find.widgetWithText(ElevatedButton, 'START ASSESSMENT');
      await tester.ensureVisible(startBtnFinder);
      await tester.tap(startBtnFinder);
      await tester.pumpAndSettle();

      // Answer Q1
      await tester.tap(find.text('Mitochondria'));
      await tester.pumpAndSettle();

      // Move to Q2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('False'));
      await tester.pumpAndSettle();

      // Move to Q3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DNA');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit Assessment'));
      await tester.pumpAndSettle();

      // Should be in Step 2 with visible score
      expect(find.textContaining('Completed & Submitted!'), findsOneWidget);
      expect(find.text('Score Obtained: 3 / 3 pts'), findsOneWidget);
      expect(find.text('Percentage: 100%'), findsOneWidget);

      // Verify Review Answers button is displayed and active
      expect(find.text('Review Questions & Answer Key'), findsOneWidget);
    });

    testWidgets('Step 1: Submit button is strictly DISABLED while there are unanswered questions, and student can freely navigate back/forward', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam();
      await tester.pumpWidget(createTestWidget(exam));
      await tester.pumpAndSettle();

      // Start assessment
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'START ASSESSMENT'));
      await tester.pumpAndSettle();

      // On Q1, answer Mitochondria
      await tester.tap(find.text('Mitochondria'));
      await tester.pumpAndSettle();

      // Navigate to Q2 via Next button
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Question 2 of 3'), findsOneWidget);

      // Student navigates BACK to Q1 via Previous button
      final prevBtnFinder = find.widgetWithText(OutlinedButton, 'Previous');
      expect(prevBtnFinder, findsOneWidget);
      await tester.tap(prevBtnFinder);
      await tester.pumpAndSettle();
      expect(find.textContaining('Question 1 of 3'), findsOneWidget);

      // Tap top pill Q3 directly to jump
      final pillQ3 = find.text('Q3');
      expect(pillQ3, findsOneWidget);
      await tester.tap(pillQ3);
      await tester.pumpAndSettle();
      expect(find.textContaining('Question 3 of 3'), findsOneWidget);

      // On Q3, since Q2 and Q3 are unanswered, submit button must show 'Submit (2 Left)'
      final disabledSubmitFinder = find.textContaining('Submit (2 Left)');
      expect(disabledSubmitFinder, findsOneWidget);

      // Tap Q2 and answer it
      await tester.tap(find.text('Q2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Question 2 of 3'), findsOneWidget);
      await tester.tap(find.text('False'));
      await tester.pumpAndSettle();

      // Return to Q3
      await tester.tap(find.text('Q3'));
      await tester.pumpAndSettle();

      // On Q3, now only Q3 is left
      expect(find.textContaining('Submit (1 Left)'), findsOneWidget);

      // Answer Q3
      await tester.enterText(find.byType(TextField), 'DNA');
      await tester.pumpAndSettle();

      // Submit button is now enabled and says 'Submit Assessment'
      final enabledSubmitFinder = find.text('Submit Assessment');
      expect(enabledSubmitFinder, findsOneWidget);
    });
  });
}
