import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';

class FakeTeacherClassworkRepo implements TeacherClassworkRepository {
  List<ActivityModel> activities = [];
  bool saveCalled = false;
  ActivityModel? lastSavedActivity;

  @override
  Future<List<ActivityModel>> getActivities({String? subjectOfferingId}) async {
    return activities;
  }

  @override
  Future<ActivityModel> saveActivity({
    required ActivityModel activity,
    required String subjectOfferingId,
    dynamic fileBytes,
    String? fileName,
    String? mimeType,
    bool removeExistingAttachment = false,
  }) async {
    saveCalled = true;
    lastSavedActivity = activity;
    return activity;
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    activities.removeWhere((a) => a.id == activityId);
  }
}

void main() {
  Widget buildTestWidget({
    required FakeTeacherClassworkRepo repo,
    List<Map<String, dynamic>> teacherOfferings = const [],
    ActivityModel? existingTask,
    bool isPerformanceTask = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 1000,
            height: 800,
            child: CreateRequirementFlowDialog(
              onRequirementCreated: () {},
              repository: repo,
              initialOfferings: teacherOfferings,
              existingTask: existingTask,
              isPerformanceTask: isPerformanceTask,
            ),
          ),
        ),
      ),
    );
  }

  group('CreateRequirementFlowDialog UI & Validation', () {
    testWidgets('renders required asterisk labels on Title, Total Points, and Instructions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeTeacherClassworkRepo();
      await tester.pumpWidget(buildTestWidget(
        repo: repo,
        teacherOfferings: [
          {
            'id': 'offering-1',
            'subject_name': 'Mathematics',
            'section_name': 'Section A',
            'grade_level': 'Grade 11',
          }
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Title *'), findsOneWidget);
      expect(find.textContaining('Total Points *'), findsOneWidget);
      expect(find.textContaining('Detailed Instructions *'), findsOneWidget);
    });

    testWidgets('shows simultaneous inline error messages when submitted empty, with NO modal dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeTeacherClassworkRepo();
      await tester.pumpWidget(buildTestWidget(
        repo: repo,
        teacherOfferings: [
          {
            'id': 'offering-1',
            'subject_name': 'Mathematics',
            'section_name': 'Section A',
            'grade_level': 'Grade 11',
          }
        ],
      ));
      await tester.pumpAndSettle();

      // Clear the default '100' points in the score field
      final pointsFinder = find.widgetWithText(TextFormField, '100');
      if (pointsFinder.evaluate().isNotEmpty) {
        await tester.enterText(pointsFinder, '');
      }

      // Tap Publish button
      final publishBtn = find.textContaining('Publish');
      expect(publishBtn, findsOneWidget);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      // Check inline errors appear
      expect(find.text('Title is required.'), findsOneWidget);
      expect(find.text('Total points is required.'), findsOneWidget);
      expect(find.text('Detailed instructions are required.'), findsOneWidget);

      // Verify no modal dialog popped up (AppModals was not shown)
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.saveCalled, isFalse);
    });

    testWidgets('validates score range 10 to 100 whole integers inline', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeTeacherClassworkRepo();
      await tester.pumpWidget(buildTestWidget(
        repo: repo,
        teacherOfferings: [
          {
            'id': 'offering-1',
            'subject_name': 'Mathematics',
            'section_name': 'Section A',
            'grade_level': 'Grade 11',
          }
        ],
      ));
      await tester.pumpAndSettle();

      // Find score field
      final scoreField = find.byType(TextFormField).at(1);

      // Score = 9
      await tester.enterText(scoreField, '9');
      final publishBtn = find.textContaining('Publish');
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(find.text('Total points must be a whole number from 10 to 100.'), findsOneWidget);

      // Score = 101
      await tester.enterText(scoreField, '101');
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(find.text('Total points must be a whole number from 10 to 100.'), findsOneWidget);

      // Score = 50 (valid)
      await tester.enterText(scoreField, '50');
      await tester.pumpAndSettle();

      expect(find.text('Total points must be a whole number from 10 to 100.'), findsNothing);
    });

    testWidgets('clears inline error when field is corrected', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeTeacherClassworkRepo();
      await tester.pumpWidget(buildTestWidget(
        repo: repo,
        teacherOfferings: [
          {
            'id': 'offering-1',
            'subject_name': 'Mathematics',
            'section_name': 'Section A',
            'grade_level': 'Grade 11',
          }
        ],
      ));
      await tester.pumpAndSettle();

      // Tap publish to trigger validation
      await tester.tap(find.textContaining('Publish'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required.'), findsOneWidget);

      // Enter valid title
      final titleField = find.byType(TextFormField).at(0);
      await tester.enterText(titleField, 'Algebra Practice');
      await tester.pumpAndSettle();

      // Error must clear immediately
      expect(find.text('Title is required.'), findsNothing);
    });
  });
}
