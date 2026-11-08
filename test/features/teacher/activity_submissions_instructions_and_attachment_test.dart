import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/activity_submissions_screen.dart';

void main() {
  group('ActivitySubmissionsScreen Layout & Attachment Controls', () {
    testWidgets('renders "View Attached File" rectangular box when material is attached', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activityWithAttachment = ActivityModel(
        id: 'act-with-file',
        title: 'Activity 1',
        description: 'Brief description',
        instructions: 'Follow the guidelines carefully.',
        subject: 'Art Criticism',
        section: 'Section 1',
        gradeLevel: 'Grade 11',
        deadline: DateTime.now().add(const Duration(days: 2)),
        maxScore: 100,
        isRequirement: false,
        subjectOfferingId: 'offering-1',
        storagePath: 'materials/sample_guideline.pdf',
        attachmentName: 'sample_guideline.pdf',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivitySubmissionsScreen(
            activity: activityWithAttachment,
            embedded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('View Attached File'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.text('No Attached File'), findsNothing);
    });

    testWidgets('renders "No Attached File" rectangular box when no material is attached', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activityWithoutAttachment = ActivityModel(
        id: 'act-no-file',
        title: 'Activity 2',
        description: 'No files needed for this',
        instructions: 'Read chapter 3.',
        subject: 'History',
        section: 'Section 1',
        gradeLevel: 'Grade 11',
        deadline: DateTime.now().add(const Duration(days: 1)),
        maxScore: 50,
        isRequirement: false,
        subjectOfferingId: 'offering-2',
        storagePath: null,
        attachmentName: null,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivitySubmissionsScreen(
            activity: activityWithoutAttachment,
            embedded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Attached File'), findsOneWidget);
      expect(find.byIcon(Icons.attachment_outlined), findsOneWidget);
      expect(find.text('View Attached File'), findsNothing);
    });

    testWidgets('expanding very long instructions inside dedicated card does NOT overflow layout', (tester) async {
      // Testing with a standard desktop viewport height of 768px (common laptop screen where overflow previously occurred)
      tester.view.physicalSize = const Size(1280, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final veryLongInstructions = List.generate(
        40,
        (i) => 'Step $i: Detailed instructions and requirements for solving the mystery behind the artwork using logic.',
      ).join('\n');

      final activityWithLongInstructions = ActivityModel(
        id: 'act-long-instructions',
        title: 'Activity 1 Online Submission',
        description: 'Mission Brief: The Art Detective Agency',
        instructions: veryLongInstructions,
        subject: 'Art Criticism and Creative Markets',
        section: 'Section 1',
        gradeLevel: 'Grade 11',
        deadline: DateTime.now().add(const Duration(days: 3)),
        maxScore: 100,
        isRequirement: false,
        subjectOfferingId: 'offering-3',
        storagePath: 'materials/brief.pdf',
        attachmentName: 'brief.pdf',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivitySubmissionsScreen(
            activity: activityWithLongInstructions,
            embedded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Dedicated instructions section exists below header
      expect(find.text('Instructions'), findsOneWidget);
      expect(find.text('Show More'), findsOneWidget);

      // Tap to expand long instructions
      await tester.tap(find.text('Show More'));
      await tester.pumpAndSettle();

      // Expanded instructions shows 'Hide' and renders the text
      expect(find.text('Hide'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);

      // Verify no overflow errors occurred
      expect(tester.takeException(), isNull);

      // Tap to hide instructions again
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(find.text('Show More'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in-person mode omits (PDF / DOC) from table header', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final inPersonActivity = ActivityModel(
        id: 'act-in-person',
        title: 'Activity 2 In-Person',
        description: 'Physical',
        instructions: 'Submit physical paper.',
        subject: 'Art',
        section: 'Section 1',
        gradeLevel: 'Grade 11',
        deadline: DateTime.now().add(const Duration(days: 2)),
        maxScore: 20,
        completionMode: 'in_person',
        subjectOfferingId: 'offering-in-person',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivitySubmissionsScreen(
            activity: inPersonActivity,
            embedded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('SUBMISSION'), findsOneWidget);
      expect(find.text('SUBMITTED WORK (PDF / DOC)'), findsNothing);
    });

    testWidgets('online mode displays SUBMITTED WORK (PDF / DOC) in table header', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final onlineActivity = ActivityModel(
        id: 'act-online',
        title: 'Activity 1 Online',
        description: 'Online submission',
        instructions: 'Upload PDF.',
        subject: 'Art',
        section: 'Section 1',
        gradeLevel: 'Grade 11',
        deadline: DateTime.now().add(const Duration(days: 2)),
        maxScore: 100,
        completionMode: 'online',
        subjectOfferingId: 'offering-online',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivitySubmissionsScreen(
            activity: onlineActivity,
            embedded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('SUBMITTED WORK (PDF / DOC)'), findsOneWidget);
    });
  });
}
