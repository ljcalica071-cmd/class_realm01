import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/widgets/teacher_unified_assessments_tab.dart';

class MockClassworkRepo implements TeacherClassworkRepository {
  List<ActivityModel> items = [];
  bool deleteCalled = false;
  String? deletedId;

  MockClassworkRepo(this.items);

  @override
  Future<List<ActivityModel>> getActivities({String? subjectOfferingId}) async {
    return items;
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
    return activity;
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    deleteCalled = true;
    deletedId = activityId;
    items.removeWhere((i) => i.id == activityId);
  }

  @override
  Future<bool> isGradebookSlotOccupied({
    required String subjectOfferingId,
    required String gradingCategory,
    required int termNumber,
    required int gradebookColumnIndex,
    String? excludeClassworkId,
  }) async {
    return false;
  }
}

void main() {
  group('TeacherUnifiedAssessmentsTab classwork persistence', () {
    testWidgets('renders activities loaded from repository', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockClassworkRepo([
        ActivityModel(
          id: 'persisted-1',
          title: 'Persisted Activity Title',
          description: '',
          instructions: 'Full instructions here',
          subject: 'General Mathematics',
          section: 'Section Einstein',
          gradeLevel: 'Grade 11',
          deadline: DateTime.now().add(const Duration(days: 3)),
          maxScore: 50,
          isRequirement: false,
          subjectOfferingId: 'offering-1',
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TeacherUnifiedAssessmentsTab(
            activities: repo.items,
            assessments: const [],
            repository: repo,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Persisted Activity Title'), findsOneWidget);
    });

    testWidgets('deleting an activity invokes repository.deleteActivity', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockClassworkRepo([
        ActivityModel(
          id: 'persisted-delete-me',
          title: 'To Be Deleted',
          description: '',
          instructions: 'Delete this task',
          subject: 'Science',
          section: 'Section Newton',
          gradeLevel: 'Grade 11',
          deadline: DateTime.now().add(const Duration(days: 1)),
          maxScore: 40,
          isRequirement: false,
          subjectOfferingId: 'offering-2',
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TeacherUnifiedAssessmentsTab(
            activities: repo.items,
            assessments: const [],
            repository: repo,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('To Be Deleted'), findsOneWidget);

      // Find delete button
      final deleteBtn = find.byIcon(Icons.delete_outline);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm delete dialog appeared
      expect(find.text('Delete Item'), findsOneWidget);
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Delete');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(repo.deleteCalled, isTrue);
      expect(repo.deletedId, 'persisted-delete-me');
    });
  });
}
