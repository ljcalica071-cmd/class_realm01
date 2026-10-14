import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/features/student/shared/widgets/student_classwork_card.dart';

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
  });
}
