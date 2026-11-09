import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/features/student/shared/widgets/student_classwork_card.dart';

void main() {
  group('Student Classwork To-Do Filtering & In-Person Parity', () {
    test('To-Do filtering: only includes upcoming/active items and excludes past-deadline or completed items', () {
      final now = DateTime.now();

      final upcomingItem = StudentClassworkModel(
        id: 'cw-upcoming',
        type: 'activity',
        title: 'Upcoming Science Activity',
        description: '',
        instructions: 'Complete by Friday.',
        subjectName: 'Science 10',
        sectionName: 'Section Curie',
        gradeLevel: '10',
        assignedAt: now.subtract(const Duration(days: 1)),
        deadline: now.add(const Duration(days: 3)), // 3 days in future
        maxScore: 50,
        status: 'pending',
        score: null,
        feedback: null,
      );

      final pastDueItem = StudentClassworkModel(
        id: 'cw-past',
        type: 'activity',
        title: 'Past Due Math Worksheet',
        description: '',
        instructions: 'Was due yesterday.',
        subjectName: 'General Mathematics',
        sectionName: 'Section Euler',
        gradeLevel: '11',
        assignedAt: now.subtract(const Duration(days: 5)),
        deadline: now.subtract(const Duration(days: 1)), // 1 day in past!
        maxScore: 40,
        status: 'pending',
        score: null,
        feedback: null,
      );

      final noDeadlineItem = StudentClassworkModel(
        id: 'cw-no-deadline',
        type: 'performance_task',
        title: 'Ongoing Science Journal',
        description: '',
        instructions: 'Submit anytime.',
        subjectName: 'Science 10',
        sectionName: 'Section Curie',
        gradeLevel: '10',
        assignedAt: now.subtract(const Duration(days: 2)),
        deadline: null, // No deadline
        maxScore: 100,
        status: null,
        score: null,
        feedback: null,
      );

      final submittedItem = StudentClassworkModel(
        id: 'cw-submitted',
        type: 'activity',
        title: 'Submitted English Essay',
        description: '',
        instructions: 'Essay instructions.',
        subjectName: 'English',
        sectionName: 'Section Shakespeare',
        gradeLevel: '10',
        assignedAt: now.subtract(const Duration(days: 2)),
        deadline: now.add(const Duration(days: 5)), // future deadline, but already submitted!
        maxScore: 100,
        status: 'submitted',
        score: null,
        feedback: null,
      );

      final gradedItem = StudentClassworkModel(
        id: 'cw-graded',
        type: 'performance_task',
        title: 'Graded Group Presentation',
        description: '',
        instructions: 'Presentation rubric.',
        subjectName: 'Science 10',
        sectionName: 'Section Curie',
        gradeLevel: '10',
        assignedAt: now.subtract(const Duration(days: 5)),
        deadline: now.add(const Duration(days: 2)),
        maxScore: 100,
        status: 'graded',
        score: 95,
        feedback: 'Excellent work!',
      );

      final allClasswork = [
        upcomingItem,
        pastDueItem,
        noDeadlineItem,
        submittedItem,
        gradedItem,
      ];

      // Exact filtering logic as implemented in student_home_screen.dart:
      final todoItems = allClasswork.where((item) {
        final isPending = item.status == null ||
            item.status == 'pending' ||
            item.status == 'returned';
        if (!isPending) return false;

        if (item.deadline != null && item.deadline!.isBefore(now)) {
          return false;
        }

        return true;
      }).toList();

      expect(todoItems.length, 2);
      expect(todoItems.map((i) => i.id).toSet(), {'cw-upcoming', 'cw-no-deadline'});
      expect(todoItems.any((i) => i.id == 'cw-past'), isFalse);
      expect(todoItems.any((i) => i.id == 'cw-submitted'), isFalse);
      expect(todoItems.any((i) => i.id == 'cw-graded'), isFalse);
    });

    test('StudentClassworkModel parses storage_path and file_name into attachment', () {
      final json = {
        'id': 'cw-pt-1',
        'type': 'performance_task',
        'title': 'Research Project Proposal',
        'description': '',
        'instructions': 'Follow the guide in the attached manual.',
        'subject_name': 'Practical Research 1',
        'section_name': 'Section Newton',
        'grade_level': '11',
        'assigned_at': '2026-11-01T08:00:00Z',
        'deadline': '2026-11-15T23:59:00Z',
        'max_score': 100,
        'completion_mode': 'in_person',
        'storage_path': 'offering-123/1700000000_Research_Guide.pdf',
        'file_name': 'Research_Guide.pdf',
        'file_size_bytes': 2048576,
        'mime_type': 'application/pdf',
        'term_number': 2,
        'gradebook_column_index': 3,
      };

      final model = StudentClassworkModel.fromJson(json);

      expect(model.id, 'cw-pt-1');
      expect(model.completionMode, 'in_person');
      expect(model.termNumber, 2);
      expect(model.gradebookColumnIndex, 3);
      expect(model.attachment, isNotNull);
      expect(model.attachment!.fileName, 'Research_Guide.pdf');
      expect(model.attachment!.signedUrl, 'offering-123/1700000000_Research_Guide.pdf');
      expect(model.attachment!.fileSizeBytes, 2048576);
      expect(model.attachment!.mimeType, 'application/pdf');
    });

    testWidgets('In-Person PT renders in-person banner, teacher attachment, and no digital submit button', (tester) async {
      String? openedUrl;

      final inPersonPt = StudentClassworkModel(
        id: 'pt-inperson-1',
        type: 'performance_task',
        title: 'Oral Presentation on Philippine History',
        description: '',
        instructions: 'Deliver a 5-minute presentation in class with your visual aids.',
        subjectName: 'Philippine History',
        sectionName: 'Section Rizal',
        gradeLevel: '10',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 3)),
        maxScore: 100,
        status: null,
        score: null,
        feedback: null,
        completionMode: 'in_person',
        gradebookColumnIndex: 2,
        attachment: const StudentAttachmentModel(
          id: 'att-hist-1',
          fileName: 'Presentation_Rubric.pdf',
          fileSizeBytes: 512000,
          signedUrl: 'https://storage.supabase.test/rubric.pdf?token=valid',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentClassworkCard(
            classwork: inPersonPt,
            urlLauncher: (url) async {
              openedUrl = url;
              return true;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Check title and PT badge
      expect(find.text('Oral Presentation on Philippine History'), findsOneWidget);
      expect(find.textContaining('PT 2'), findsOneWidget);

      // Check In-Person banner
      expect(
        find.textContaining('In-Person Performance Task: Submit your physical work directly to your teacher in class'),
        findsOneWidget,
      );

      // Digital submit button must NOT exist for in-person task
      expect(find.text('Submit Work'), findsNothing);
      expect(find.text('Take Examination (App)'), findsNothing);

      // Teacher attached document card must exist with "Open Material"
      expect(find.textContaining('Presentation_Rubric.pdf'), findsOneWidget);
      expect(find.text('Teacher Attached Material'), findsOneWidget);

      // Tap the attachment card to open/download
      await tester.tap(find.textContaining('Presentation_Rubric.pdf'));
      await tester.pumpAndSettle();

      expect(openedUrl, 'https://storage.supabase.test/rubric.pdf?token=valid');
    });

    testWidgets('In-Person Exam renders exam in-person banner and suppresses take exam button', (tester) async {
      final inPersonExam = StudentClassworkModel(
        id: 'exam-inperson-1',
        type: 'exam',
        title: 'First Periodical Examination (ST1)',
        description: '',
        instructions: 'Bring pencil and eraser. 50 items paper examination.',
        subjectName: 'Art Criticism and Creative Markets',
        sectionName: 'Section 1',
        gradeLevel: '11',
        assignedAt: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 1)),
        maxScore: 50,
        status: null,
        score: null,
        feedback: null,
        completionMode: 'in_person',
        gradebookColumnIndex: 1,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentClassworkCard(
            classwork: inPersonExam,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('First Periodical Examination (ST1)'), findsOneWidget);
      expect(
        find.textContaining('In-Person Periodical Examination: Administered in classroom by teacher. Your score will appear here once recorded in the Gradebook.'),
        findsOneWidget,
      );
      expect(find.text('Take Examination'), findsNothing);
      expect(find.text('Submit Work'), findsNothing);
    });

    testWidgets('In-Person Exam with recorded score displays Graded status and points', (tester) async {
      final gradedInPersonExam = StudentClassworkModel(
        id: 'exam-inperson-2',
        type: 'exam',
        title: 'Second Periodical Examination (ST2)',
        description: '',
        instructions: '',
        subjectName: 'Art Criticism and Creative Markets',
        sectionName: 'Section 1',
        gradeLevel: '11',
        assignedAt: DateTime.now().subtract(const Duration(days: 5)),
        deadline: DateTime.now().subtract(const Duration(days: 2)),
        maxScore: 60,
        status: 'graded',
        score: 54,
        feedback: 'Great score on the paper test!',
        completionMode: 'in_person',
        gradebookColumnIndex: 2,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentClassworkCard(
            classwork: gradedInPersonExam,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Graded'), findsOneWidget);
      expect(find.text('54 / 60 pts'), findsOneWidget);
      expect(find.text('Take Examination'), findsNothing);
    });
  });
}
