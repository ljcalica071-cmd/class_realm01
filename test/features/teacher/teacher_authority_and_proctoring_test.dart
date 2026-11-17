import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/gemini_service.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/models/proctor_violation_log.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/models/student_live_proctor_state.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/services/teacher_proctor_channel_service.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/widgets/proctoring_roster_table.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/widgets/student_proctor_card.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/item_analysis/item_difficulty_stat.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
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

      proctorService.dispose();
    });
  });

  group('3. Teacher Student Proctor Card Widget Interaction Test', () {
    testWidgets('Renders Reset & Kick action buttons (and no Force Auto-Submit) for in-progress student', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool resetTapped = false;
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

      // Verify Force Auto-Submit was removed
      expect(find.byTooltip('Force Auto-Submit'), findsNothing);

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

      // Verify reset back to Question 1 & student UI hides Violations and 1 Point
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.textContaining('Violations:'), findsNothing);
      expect(find.text('1 Point'), findsNothing);
    });
  });

  group('5. QuestionDraft Delete & Renumber Integrity Test', () {
    test('Deleting Q5 decrements only that type, renumbers 1..N sequentially, and preserves >= 1 item', () {
      final drafts = <QuestionDraft>[
        for (int i = 1; i <= 5; i++)
          QuestionDraft(position: i, type: QuestionType.multipleChoice, statement: 'MC $i'),
        for (int i = 6; i <= 10; i++)
          QuestionDraft(position: i, type: QuestionType.trueFalse, statement: 'TF $i'),
        for (int i = 11; i <= 15; i++)
          QuestionDraft(position: i, type: QuestionType.identification, statement: 'ID $i'),
      ];

      final deletedType = QuestionDraft.deleteAndRenumber(drafts, 4); // Q5
      expect(deletedType, equals(QuestionType.multipleChoice));
      expect(drafts.length, equals(14));
      for (int i = 0; i < drafts.length; i++) {
        expect(drafts[i].position, equals(i + 1));
      }
      expect(drafts[4].statement, equals('TF 6'));
      expect(drafts[4].position, equals(5));

      final singleList = [QuestionDraft(position: 1, type: QuestionType.multipleChoice)];
      expect(QuestionDraft.deleteAndRenumber(singleList, 0), isNull);
      expect(singleList.length, equals(1));
    });
  });

  group('6. Anti-Cheating Violation Deduplication Tests', () {
    test('Lifecycle violation only counts once per away transition and never on resumed', () {
      final t0 = DateTime(2026, 11, 14, 10, 0, 0);
      expect(
        StudentAssessmentScreenState.shouldCountLifecycleViolation(
          state: AppLifecycleState.inactive,
          isAwayFromScreen: false,
          lastRecordedAt: null,
          now: t0,
        ),
        isTrue,
      );
      expect(
        StudentAssessmentScreenState.shouldCountLifecycleViolation(
          state: AppLifecycleState.paused,
          isAwayFromScreen: true,
          lastRecordedAt: t0,
          now: t0.add(const Duration(milliseconds: 200)),
        ),
        isFalse,
      );
      expect(
        StudentAssessmentScreenState.shouldCountLifecycleViolation(
          state: AppLifecycleState.resumed,
          isAwayFromScreen: false,
          lastRecordedAt: t0,
          now: t0.add(const Duration(seconds: 5)),
        ),
        isFalse,
      );
    });

    test('TeacherProctorChannelService deduplicates twin violations within 2 seconds', () {
      final proctorService = TeacherProctorChannelService(assessmentId: 'exam-dedup');
      proctorService.initializeRoster([
        {'id': 'stu_001', 'name': 'Juan Dela Cruz', 'lrn': '123', 'section': 'Sec A'},
      ]);

      final t0 = DateTime(2026, 11, 14, 10, 0, 0);
      proctorService.recordViolation(ProctorViolationLog(
        id: 'v1',
        attemptId: 'att_1',
        studentId: 'stu_001',
        studentName: 'Juan Dela Cruz',
        violationType: ProctorViolationType.tabSwitch,
        durationSeconds: 0,
        timestamp: t0,
      ));
      proctorService.recordViolation(ProctorViolationLog(
        id: 'v2',
        attemptId: 'att_1',
        studentId: 'stu_001',
        studentName: 'Juan Dela Cruz',
        violationType: ProctorViolationType.windowBlur,
        durationSeconds: 0,
        timestamp: t0.add(const Duration(seconds: 1)),
      ));
      proctorService.recordViolation(ProctorViolationLog(
        id: 'v3',
        attemptId: 'att_1',
        studentId: 'stu_001',
        studentName: 'Juan Dela Cruz',
        violationType: ProctorViolationType.tabSwitch,
        durationSeconds: 0,
        timestamp: t0.add(const Duration(seconds: 3)),
      ));

      final state = proctorService.currentStates.first;
      expect(state.violationCount, equals(2));
      proctorService.dispose();
    });
  });

  group('7. Gemini User-Friendly Assessment Error Test', () {
    test('Formats quota/429 error cleanly without technical jargon', () {
      final msg = GeminiService.formatUserFriendlyErrorMessage(
        'QuotaExceeded: 429 Too Many Requests for Gemini API key',
        isAssessment: true,
      );
      expect(msg.toLowerCase(), isNot(contains('gemini')));
      expect(msg.toLowerCase(), isNot(contains('api')));
      expect(msg, isNot(contains('429')));
      expect(msg.toLowerCase(), isNot(contains('.env')));
    });
  });

  group('8. Retake Score Clearing & Sub-View Browser Refresh Persistence Test', () {
    test('Retake immediately clears student score and prevents stale score resurrection during inProgress', () async {
      final proctorService = TeacherProctorChannelService(assessmentId: 'quiz_3_live');
      proctorService.initializeRoster([
        {
          'id': 'stu_ljay',
          'name': 'Calica, Ljay M.',
          'lrn': '999999999991',
          'section': 'B2',
          'status': ProctorSessionStatus.submitted,
          'score': 5.0,
          'total_points': 9.0,
          'violation_count': 4,
        },
        {
          'id': 'stu_rex',
          'name': 'San Juan, Rex G.',
          'lrn': '123412341111',
          'section': 'B2',
          'status': ProctorSessionStatus.submitted,
          'score': 2.0,
          'total_points': 9.0,
          'violation_count': 5,
        },
      ]);

      // Verify initial submitted scores
      var ljay = proctorService.currentStates.firstWhere((s) => s.studentId == 'stu_ljay');
      expect(ljay.status, equals(ProctorSessionStatus.submitted));
      expect(ljay.score, equals(5.0));

      // Teacher clicks Retake on Ljay
      await proctorService.authorizeRetake('stu_ljay', writeToDb: false);
      ljay = proctorService.currentStates.firstWhere((s) => s.studentId == 'stu_ljay');
      expect(ljay.status, equals(ProctorSessionStatus.retakeRequested));
      expect(ljay.score, isNull, reason: 'Retake must immediately clear previous score.');
      expect(ljay.violationCount, equals(0), reason: 'Retake must clear previous violations.');

      // Even if a background poll passes stale submitted status/score within the reset guard window, score stays null
      proctorService.initializeRoster([
        {
          'id': 'stu_ljay',
          'name': 'Calica, Ljay M.',
          'lrn': '999999999991',
          'section': 'B2',
          'status': ProctorSessionStatus.submitted,
          'score': 5.0,
          'total_points': 9.0,
          'violation_count': 4,
        },
      ]);
      ljay = proctorService.currentStates.firstWhere((s) => s.studentId == 'stu_ljay');
      expect(ljay.status, equals(ProctorSessionStatus.retakeRequested));
      expect(ljay.score, isNull);

      // Student starts retaking the quiz (inProgress)
      proctorService.registerStudentStarted('stu_ljay', forceRestart: true);
      ljay = proctorService.currentStates.firstWhere((s) => s.studentId == 'stu_ljay');
      expect(ljay.status, equals(ProctorSessionStatus.inProgress));
      expect(ljay.score, isNull, reason: 'Score must remain null while student is In Progress.');

      proctorService.dispose();
    });

    testWidgets('ProctoringRosterTable hides score when student is In Progress or Retake', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final students = [
        const StudentLiveProctorState(
          studentId: 'stu_1',
          studentName: 'Calica, Ljay M.',
          lastName: 'Calica',
          firstName: 'Ljay',
          middleName: 'M',
          lrn: '999999999991',
          section: 'B2',
          status: ProctorSessionStatus.inProgress,
          violationCount: 0,
          score: null,
          totalPoints: 9.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProctoringRosterTable(
              students: students,
              searchQuery: '',
              onSearchChanged: (_) {},
              onReset: (_) {},
              onToggleAllow: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('pts'), findsNothing);
    });

    test('All Quiz, Exam, and Activity sub-view routes are recognized and persist JSON state for F5 refresh', () async {
      await LocalStorageService.init();

      expect(AppRoutes.isTeacherClassworkSubViewRoute(AppRoutes.teacherClassworkWwProctoring), isTrue);
      expect(AppRoutes.isTeacherClassworkSubViewRoute(AppRoutes.teacherClassworkExProctoring), isTrue);
      expect(AppRoutes.isTeacherClassworkSubViewRoute(AppRoutes.teacherClassworkWwItemAnalysis), isTrue);
      expect(AppRoutes.isTeacherClassworkSubViewRoute(AppRoutes.teacherClassworkExItemAnalysis), isTrue);
      expect(AppRoutes.isTeacherClassworkSubViewRoute(AppRoutes.teacherClassworkWwSubmissions), isTrue);
      expect(AppRoutes.isTeacherClassworkSubViewRoute(AppRoutes.teacherClassworkPtSubmissions), isTrue);

      final sampleExam = createSampleExam();
      await LocalStorageService.saveTeacherClassworkNavState(
        categoryTabIndex: 2,
        activeAssessmentId: sampleExam.id,
        activeAssessmentJson: sampleExam.toJson(),
      );

      final navState = LocalStorageService.getTeacherClassworkNavState();
      expect(navState['activeAssessmentId'], equals(sampleExam.id));
      expect(navState['activeAssessmentJson'], isA<Map>());
      final restored = QuizOrExamModel.fromJson(
        Map<String, dynamic>.from(navState['activeAssessmentJson'] as Map),
      );
      expect(restored.id, equals(sampleExam.id));
      expect(restored.title, equals(sampleExam.title));
      expect(restored.isExam, isTrue);
    });

    test('ItemDifficultyStat categorizes questions and groups them by category in standard DepEd order', () {
      // Create 6 sample items matching the user's exam
      final items = [
        ItemDifficultyStat(
          itemNumber: 1,
          questionText: "According to Erik Erikson's psychosocial theory...",
          totalAttempts: 2,
          correctCount: 0,
          questionType: ItemDifficultyStat.parseQuestionType('multiple_choice'),
        ),
        ItemDifficultyStat(
          itemNumber: 2,
          questionText: 'Which theorist developed the Life-Span model...',
          totalAttempts: 2,
          correctCount: 0,
          questionType: ItemDifficultyStat.parseQuestionType('multiple_choice'),
        ),
        ItemDifficultyStat(
          itemNumber: 3,
          questionText: 'Self-awareness means recognizing your own strengths...',
          totalAttempts: 2,
          correctCount: 2,
          questionType: ItemDifficultyStat.parseQuestionType('true_false'),
        ),
        ItemDifficultyStat(
          itemNumber: 4,
          questionText: 'Career planning should only begin after graduating...',
          totalAttempts: 2,
          correctCount: 0,
          questionType: ItemDifficultyStat.parseQuestionType('true_false'),
        ),
        ItemDifficultyStat(
          itemNumber: 5,
          questionText: 'The ability to resolve disagreements peacefully...',
          totalAttempts: 2,
          correctCount: 1,
          questionType: ItemDifficultyStat.parseQuestionType('identification'),
        ),
        ItemDifficultyStat(
          itemNumber: 6,
          questionText: 'The core SHS subject designed to prepare Grade 11...',
          totalAttempts: 2,
          correctCount: 2,
          questionType: ItemDifficultyStat.parseQuestionType('identification'),
        ),
      ];

      // Verify category parsing
      expect(items[0].questionType, equals(QuestionType.multipleChoice));
      expect(items[0].categoryLabel, equals('Multiple Choice'));
      expect(items[0].classification, equals('Very Difficult'));

      expect(items[2].questionType, equals(QuestionType.trueFalse));
      expect(items[2].categoryLabel, equals('True or False'));
      expect(items[2].classification, equals('Very Easy'));

      expect(items[4].questionType, equals(QuestionType.identification));
      expect(items[4].categoryLabel, equals('Identification'));
      expect(items[4].classification, equals('Moderate / Ideal'));

      // Group by category in standard DepEd order
      const orderedCategories = [
        QuestionType.multipleChoice,
        QuestionType.trueFalse,
        QuestionType.identification,
        QuestionType.matching,
      ];

      final Map<QuestionType, List<ItemDifficultyStat>> grouped = {};
      for (final it in items) {
        if (it.questionType != null) {
          grouped.putIfAbsent(it.questionType!, () => []).add(it);
        }
      }

      final activeCategories = orderedCategories.where((c) => grouped.containsKey(c)).toList();
      expect(activeCategories, equals([
        QuestionType.multipleChoice,
        QuestionType.trueFalse,
        QuestionType.identification,
      ]));

      // Verify item counts in each category
      expect(grouped[QuestionType.multipleChoice]!.length, equals(2));
      expect(grouped[QuestionType.trueFalse]!.length, equals(2));
      expect(grouped[QuestionType.identification]!.length, equals(2));

      // Verify item numbers in each category
      expect(grouped[QuestionType.multipleChoice]!.map((e) => e.itemNumber).toList(), equals([1, 2]));
      expect(grouped[QuestionType.trueFalse]!.map((e) => e.itemNumber).toList(), equals([3, 4]));
      expect(grouped[QuestionType.identification]!.map((e) => e.itemNumber).toList(), equals([5, 6]));
    });

    test('Realtime attempt in_progress transitions student out of Retake and records tab switch violations', () async {
      final proctorService = TeacherProctorChannelService(assessmentId: 'quiz_realtime_test');
      proctorService.initializeRoster([
        {
          'id': 'stu_banana',
          'name': 'Bear, Banana V.',
          'lrn': '100000001234',
          'section': 'Avocado',
          'status': ProctorSessionStatus.retakeRequested,
          'score': null,
          'total_points': 10.0,
          'violation_count': 0,
        },
      ]);

      var banana = proctorService.currentStates.firstWhere((s) => s.studentId == 'stu_banana');
      expect(banana.status, equals(ProctorSessionStatus.retakeRequested));

      // Student starts attempt: Realtime attempt broadcast arrives with status: 'in_progress'
      // Simulated via Supabase Realtime broadcast payload
      proctorService.registerStudentStarted('stu_banana', forceRestart: true);

      banana = proctorService.currentStates.firstWhere((s) => s.studentId == 'stu_banana');
      expect(banana.status, equals(ProctorSessionStatus.inProgress));
      expect(proctorService.currentStates.where((s) => s.status == ProctorSessionStatus.inProgress).length, equals(1));

      // Student switches tabs on web, firing anti-cheating violation log
      proctorService.recordViolation(
        ProctorViolationLog(
          id: 'v_banana_1',
          attemptId: 'att_banana_1',
          studentId: 'stu_banana',
          studentName: 'Bear, Banana V.',
          violationType: ProctorViolationType.appBackgrounded,
          durationSeconds: 0,
          timestamp: DateTime.now(),
        ),
      );

      banana = proctorService.currentStates.firstWhere((s) => s.studentId == 'stu_banana');
      expect(banana.violationCount, equals(1));
      expect(banana.violations.length, equals(1));
      expect(banana.violations.first.violationType, equals(ProctorViolationType.appBackgrounded));

      proctorService.dispose();
    });
  });
}
