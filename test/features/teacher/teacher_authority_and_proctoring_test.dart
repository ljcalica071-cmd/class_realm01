import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/models/student_live_proctor_state.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/services/teacher_proctor_channel_service.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/widgets/student_proctor_card.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_assessment_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppDataCache.instance.clearAll();
  });

  QuizOrExamModel createSampleExam({bool resultsReleased = false}) {
    return QuizOrExamModel(
      id: 'exam-poly-101',
      title: 'Midterm Assessment in Science',
      description: 'Summative Periodical Examination.',
      subject: 'Earth Science',
      section: 'Grade 10 - Bonifacio',
      isExam: true,
      examType: 'st1',
      durationMinutes: 40,
      scheduleDate: DateTime.now(),
      isPublished: true,
      resultsReleased: resultsReleased,
      questions: [
        QuestionModel(
          id: 'q1',
          questionText: 'What is the outermost layer of Earth?',
          type: QuestionType.multipleChoice,
          points: 1.0,
          choices: ['Crust', 'Mantle', 'Outer Core', 'Inner Core'],
          correctAnswer: 'A',
        ),
        QuestionModel(
          id: 'q2',
          questionText: 'The core consists primarily of nickel and iron.',
          type: QuestionType.trueFalse,
          points: 1.0,
          choices: ['True', 'False'],
          correctAnswer: 'True',
        ),
        QuestionModel(
          id: 'q3',
          questionText: 'Name the molten rock expelled by a volcano during an eruption.',
          type: QuestionType.identification,
          points: 1.0,
          correctAnswer: 'Lava',
        ),
      ],
    );
  }

  group('1. Deterministic Randomization & Option Shuffling Test', () {
    test('Student A and Student B receive distinct randomized orders, yet retake order for Student A is identical', () {
      const assessmentId = 'assessment_math_final_01';
      const studentAId = 'student_uuid_001_juan';
      const studentBId = 'student_uuid_002_maria';

      final originalQuestions = List.generate(
        10,
        (i) => QuestionModel(
          id: 'q_$i',
          questionText: 'Question number $i',
          type: QuestionType.multipleChoice,
          points: 1.0,
          choices: ['Option A', 'Option B', 'Option C', 'Option D'],
          correctAnswer: 'A',
        ),
      );

      // Student A Seed
      final seedA = studentAId.hashCode ^ assessmentId.hashCode;
      final studentAQuestions = List<QuestionModel>.from(originalQuestions);
      studentAQuestions.shuffle(Random(seedA));

      // Student B Seed
      final seedB = studentBId.hashCode ^ assessmentId.hashCode;
      final studentBQuestions = List<QuestionModel>.from(originalQuestions);
      studentBQuestions.shuffle(Random(seedB));

      // Verify that Student A and Student B have different question sequences (Anti-Peeking in physical exam halls)
      final studentAIds = studentAQuestions.map((q) => q.id).toList();
      final studentBIds = studentBQuestions.map((q) => q.id).toList();
      expect(studentAIds, isNot(equals(studentBIds)),
          reason: 'Adjacent students must have different question orderings.');

      // Verify Student A reloading / resuming has 100% deterministic identical order
      final studentARetryQuestions = List<QuestionModel>.from(originalQuestions);
      studentARetryQuestions.shuffle(Random(seedA));
      final studentARetryIds = studentARetryQuestions.map((q) => q.id).toList();
      expect(studentAIds, equals(studentARetryIds),
          reason: 'Deterministic seed guarantees persistent question sequence across retakes/resumes.');

      // Verify Multiple Choice Option Shuffling determinism
      final q = originalQuestions[0];
      final choiceSeedA = seedA ^ q.id.hashCode;
      final choiceSeedB = seedB ^ q.id.hashCode;
      final choicesA = List<String>.from(q.choices)..shuffle(Random(choiceSeedA));
      final choicesB = List<String>.from(q.choices)..shuffle(Random(choiceSeedB));
      expect(choicesB, isNotEmpty);

      // Option sequence must also remain consistent for Student A
      final choicesARetry = List<String>.from(q.choices)..shuffle(Random(choiceSeedA));
      expect(choicesA, equals(choicesARetry));
    });
  });

  group('2. Teacher Proctor Authority Actions & Student Isolation Test', () {
    test('Teacher resetting or auto-submitting Student A leaves Student B unaffected', () {
      final proctorService = TeacherProctorChannelService(assessmentId: 'exam_periodical_bio');
      proctorService.initializeRoster([
        {'id': 'stu_001', 'name': 'Juan Cruz', 'lrn': '123456789001', 'section': 'Grade 10 - Rizal'},
        {'id': 'stu_002', 'name': 'Maria Santos', 'lrn': '123456789002', 'section': 'Grade 10 - Rizal'},
      ]);

      // Both students start exam
      proctorService.registerStudentStarted('stu_001');
      proctorService.registerStudentStarted('stu_002');

      var states = proctorService.currentStates;
      var stuA = states.firstWhere((s) => s.studentId == 'stu_001');
      var stuB = states.firstWhere((s) => s.studentId == 'stu_002');
      expect(stuA.status, equals(ProctorSessionStatus.inProgress));
      expect(stuB.status, equals(ProctorSessionStatus.inProgress));

      // Action 1: Teacher resets Student A (e.g., student had a violation or system glitch)
      proctorService.authorizeRetake('stu_001', reason: 'Instructor granted test reset', writeToDb: false);

      states = proctorService.currentStates;
      stuA = states.firstWhere((s) => s.studentId == 'stu_001');
      stuB = states.firstWhere((s) => s.studentId == 'stu_002');

      expect(stuA.status, equals(ProctorSessionStatus.retakeRequested),
          reason: 'Student A status must be updated to retakeRequested / reset');
      expect(stuA.violationCount, equals(0), reason: 'Student A violations must be cleared on reset');
      expect(stuB.status, equals(ProctorSessionStatus.inProgress),
          reason: 'Student B MUST NOT be affected when Student A is reset!');

      // Action 2: Teacher force auto-submits Student A
      proctorService.forceSubmitStudent('stu_001', reason: 'Time expired or proctor submitted', writeToDb: false);

      states = proctorService.currentStates;
      stuA = states.firstWhere((s) => s.studentId == 'stu_001');
      stuB = states.firstWhere((s) => s.studentId == 'stu_002');

      expect(stuA.status, equals(ProctorSessionStatus.submitted),
          reason: 'Student A status must be submitted');
      expect(stuB.status, equals(ProctorSessionStatus.inProgress),
          reason: 'Student B MUST NOT be affected when Student A is auto-submitted!');

      proctorService.dispose();
    });
  });

  group('3. Teacher Student Proctor Card Widget Interaction Test', () {
    testWidgets('Renders 3 clean action buttons (Reset, Force Submit, Kick) for in-progress student', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool resetTapped = false;
      bool forceSubmitTapped = false;
      bool kickTapped = false;

      final inProgressState = StudentLiveProctorState(
        studentId: 'stu_100',
        studentName: 'Ana Reyes',
        lrn: '109283746501',
        section: 'Grade 10 - Bonifacio',
        status: ProctorSessionStatus.inProgress,
        violationCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StudentProctorCard(
                state: inProgressState,
                onRetake: () => resetTapped = true,
                onForceSubmit: () => forceSubmitTapped = true,
                onKick: () => kickTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Reyes'), findsOneWidget);
      expect(find.text('Taking Test'), findsOneWidget);
      expect(find.text('1 Violations'), findsOneWidget);

      // Verify Reset button
      final resetBtnFinder = find.byTooltip('Reset Student Attempt');
      expect(resetBtnFinder, findsOneWidget);
      await tester.tap(resetBtnFinder);
      expect(resetTapped, isTrue);

      // Verify Force Auto-Submit button
      final forceSubmitBtnFinder = find.byTooltip('Force Auto-Submit');
      expect(forceSubmitBtnFinder, findsOneWidget);
      await tester.tap(forceSubmitBtnFinder);
      expect(forceSubmitTapped, isTrue);

      // Verify Kick button
      final kickBtnFinder = find.byTooltip('Kick & Disqualify');
      expect(kickBtnFinder, findsOneWidget);
      await tester.tap(kickBtnFinder);
      expect(kickTapped, isTrue);
    });
  });

  group('4. Student Assessment Screen E2E Reset & Force Submit UI Feedback', () {
    testWidgets('Student receives prominent modal pop-up on instructor reset', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentAssessmentScreen(assessment: exam),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Agree to rules and start assessment
      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      final startBtn = find.widgetWithText(ElevatedButton, 'START ASSESSMENT');
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 3'), findsOneWidget);

      // Answer question 1
      final choiceCrust = find.text('Crust');
      expect(choiceCrust, findsOneWidget);
      await tester.tap(choiceCrust);
      await tester.pumpAndSettle();

      // Trigger Instructor Reset Dialog
      final state = tester.state<StudentAssessmentScreenState>(find.byType(StudentAssessmentScreen));
      state.handleTeacherResetForTesting('Violation detected: Tab switching unauthorized.');
      await tester.pumpAndSettle();

      // Verify modal dialog appears
      expect(find.text('Session Reset by Instructor'), findsOneWidget);
      expect(find.textContaining('Your examination session was reset by your instructor.'), findsOneWidget);
      expect(find.textContaining('All prior recorded answers have been wiped.'), findsOneWidget);

      final startOverBtn = find.widgetWithText(ElevatedButton, 'Start Over Fresh');
      expect(startOverBtn, findsOneWidget);

      // Tap Start Over Fresh
      await tester.tap(startOverBtn);
      await tester.pumpAndSettle();

      // Verify reset back to Question 1
      expect(find.text('Question 1 of 3'), findsOneWidget);
    });

    testWidgets('Student receives force submit action and transitions to Result View with score', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exam = createSampleExam(resultsReleased: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentAssessmentScreen(assessment: exam),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Agree and start
      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      final startBtn = find.widgetWithText(ElevatedButton, 'START ASSESSMENT');
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 3'), findsOneWidget);

      // Answer question 1 correctly
      await tester.tap(find.text('Crust'));
      await tester.pumpAndSettle();

      // Trigger Teacher Force Auto-Submit
      final state = tester.state<StudentAssessmentScreenState>(find.byType(StudentAssessmentScreen));
      state.handleTeacherForceSubmitForTesting('Periodical exam period ended.');
      await tester.pumpAndSettle();

      // Verify immediate transition to Result View
      expect(find.text('Examination Completed & Submitted!'), findsOneWidget);
      expect(find.textContaining('Score Obtained:'), findsOneWidget);
      expect(find.textContaining('1 / 3 pts'), findsOneWidget);

      // Answer Key locked notice displayed since resultsReleased is false
      expect(find.text('Answer Key Locked: Your teacher has not released the item-by-item answer key review yet.'), findsOneWidget);
    });
  });
}
