import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/features/student/shared/widgets/student_classwork_card.dart';
import 'package:class_realm/features/student/shared/widgets/student_submit_work_dialog.dart';

void main() {
  group('StudentClassworkCard Attachment and Instructions Display', () {
    testWidgets('renders detailed instructions and attachment file button', (tester) async {
      String? launchedUrl;

      final classwork = StudentClassworkModel(
        id: 'cw-1',
        type: 'activity',
        title: 'Laboratory Experiment 1',
        description: '',
        instructions: 'Follow the procedures in the attached laboratory manual.',
        subjectName: 'General Physics',
        sectionName: 'Section Faraday',
        gradeLevel: '12',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 5)),
        maxScore: 100,
        status: null,
        score: null,
        feedback: null,
        attachment: const StudentAttachmentModel(
          id: 'att-1',
          fileName: 'Physics_Lab_Manual.pdf',
          mimeType: 'application/pdf',
          fileSizeBytes: 1048576,
          signedUrl: 'https://storage.supabase.test/lab.pdf?token=valid',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentClassworkCard(
            classwork: classwork,
            urlLauncher: (url) async {
              launchedUrl = url;
              return true;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Check instructions are visible
      expect(
        find.text('Follow the procedures in the attached laboratory manual.'),
        findsOneWidget,
      );

      // Check attachment file name is visible
      expect(find.textContaining('Physics_Lab_Manual.pdf'), findsOneWidget);

      // Tap attachment button
      final attachmentFinder = find.textContaining('Physics_Lab_Manual.pdf');
      await tester.tap(attachmentFinder);
      await tester.pumpAndSettle();

      expect(launchedUrl, 'https://storage.supabase.test/lab.pdf?token=valid');
    });

    testWidgets('shows error snackbar when opening attachment fails', (tester) async {
      final classwork = StudentClassworkModel(
        id: 'cw-2',
        type: 'activity',
        title: 'Essay Prompt',
        description: '',
        instructions: 'Read the rubric before writing.',
        subjectName: 'Creative Writing',
        sectionName: 'Section Shakespeare',
        gradeLevel: '12',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 2)),
        maxScore: 50,
        status: null,
        score: null,
        feedback: null,
        attachment: const StudentAttachmentModel(
          id: 'att-2',
          fileName: 'Rubric.docx',
          signedUrl: 'https://storage.supabase.test/rubric.docx',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentClassworkCard(
            classwork: classwork,
            urlLauncher: (url) async => false, // fails to open
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Rubric.docx'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to open attachment.'), findsOneWidget);
    });

    testWidgets('renders on narrow mobile viewport (360px) without any horizontal overflow and omits redundant section/grade', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final classwork = StudentClassworkModel(
        id: 'cw-mobile-1',
        type: 'activity',
        title: 'Activity 1',
        description: 'Mission Brief: The Art Detective Agency',
        instructions: 'Follow guidelines',
        subjectName: 'Art Criticism and Creative Markets',
        sectionName: 'Section 1',
        gradeLevel: '11',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 3)),
        maxScore: 100,
        status: 'assigned',
        score: null,
        feedback: null,
        gradebookColumnIndex: 1,
        attachment: const StudentAttachmentModel(
          id: 'att-mobile-1',
          fileName: 'iLAW_General_Mathematics_Representing_Real_Life_Situations_Us.pdf',
          fileSizeBytes: 19456,
          signedUrl: 'https://storage.supabase.test/doc.pdf?token=valid',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StudentClassworkCard(classwork: classwork),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify no overflow exception occurred
      expect(tester.takeException(), isNull);

      // Verify subtitle does NOT contain 'Section 1' or 'Grade 11'
      expect(find.textContaining('Section 1'), findsNothing);
      expect(find.textContaining('Grade 11'), findsNothing);

      // Verify clean subtitle format
      expect(find.text('Art Criticism and Creative Markets · Activity (WW 1)'), findsOneWidget);

      // Verify attachment card renders responsive 'View File' or 'View Attached File'
      expect(find.text('Teacher Attached Material'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('omits attachment section completely when teacher attached no file', (tester) async {
      final classwork = StudentClassworkModel(
        id: 'cw-no-att',
        type: 'activity',
        title: 'Activity Without Attachment',
        description: 'Just instructions',
        instructions: 'Answer questions 1-5 in your notebook.',
        subjectName: 'English for Academic Purposes',
        sectionName: 'Section 1',
        gradeLevel: '11',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 3)),
        maxScore: 50,
        status: 'assigned',
        score: null,
        feedback: null,
        attachment: null, // No attachment!
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StudentClassworkCard(classwork: classwork),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Teacher Attached Material'), findsNothing);
      expect(find.textContaining('View Attached File'), findsNothing);
      expect(find.textContaining('No attached file'), findsNothing);
    });

    testWidgets('displays Graded status and teacher score clearly when graded', (tester) async {
      final classwork = StudentClassworkModel(
        id: 'cw-graded-1',
        type: 'activity',
        title: 'Graded Essay Activity',
        description: '',
        instructions: 'Write a 500-word essay.',
        subjectName: 'Philosophy',
        sectionName: 'Section 1',
        gradeLevel: '11',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 3)),
        maxScore: 100,
        status: 'graded',
        score: 95.0,
        feedback: 'Excellent critical thinking!',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StudentClassworkCard(classwork: classwork),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Graded status pill
      expect(find.text('Graded'), findsOneWidget);

      // Score in metadata and banner
      expect(find.text('Score: 95 / 100 pts'), findsWidgets);
      expect(find.text('Score Recorded by Teacher'), findsOneWidget);

      // Teacher remarks
      expect(find.text('Teacher remarks: Excellent critical thinking!'), findsOneWidget);

      // No turn in or resubmit button when graded
      expect(find.text('Turn In Work (PDF/DOC)'), findsNothing);
      expect(find.text('Resubmit / Update File'), findsNothing);
    });

    testWidgets('StudentSubmitWorkDialog has NO remarks field and accepts only file attachment', (tester) async {
      final classwork = StudentClassworkModel(
        id: 'cw-submit-1',
        type: 'activity',
        title: 'Submit Test',
        description: '',
        instructions: 'Submit your paper.',
        subjectName: 'Science',
        sectionName: 'Section 1',
        gradeLevel: '11',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 3)),
        maxScore: 50,
        status: 'assigned',
        score: null,
        feedback: null,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                StudentSubmitWorkDialog.show(
                  context,
                  classwork: classwork,
                  onSubmitted: () {},
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Submit Work'), findsOneWidget);
      expect(find.text('Attach Your File *'), findsOneWidget);
      expect(find.text('Turn In Work'), findsOneWidget);

      // No Student Notes / Remarks
      expect(find.text('Student Notes / Remarks (Optional)'), findsNothing);
      expect(find.text('Add an optional note or explanation for your teacher...'), findsNothing);
    });
  });
}
