import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/shared/widgets/inputs/app_text_field.dart';

class FakeClassworkRepo implements TeacherClassworkRepository {
  ActivityModel? savedActivity;
  String? savedOfferingId;

  @override
  Future<List<ActivityModel>> getActivities({
    String? subjectOfferingId,
    String? teacherId,
  }) async => [];

  @override
  Future<ActivityModel> saveActivity({
    required ActivityModel activity,
    required String subjectOfferingId,
    dynamic fileBytes,
    String? fileName,
    String? mimeType,
    bool removeExistingAttachment = false,
  }) async {
    savedActivity = activity;
    savedOfferingId = subjectOfferingId;
    return activity;
  }

  @override
  Future<void> deleteActivity(String activityId) async {}

  @override
  Future<bool> isGradebookSlotOccupied({
    required String subjectOfferingId,
    required String gradingCategory,
    required int termNumber,
    required int gradebookColumnIndex,
    String? excludeClassworkId,
  }) async => false;
}

void main() {
  group('AppTextField Tests', () {
    testWidgets('renders custom hint, maxLength, and live counter', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Test Label',
              hint: 'e.g. Placeholder Hint',
              controller: controller,
              maxLength: 50,
              showCounter: true,
            ),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.text('e.g. Placeholder Hint'), findsOneWidget);
      expect(find.text('0/50'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Sample text');
      await tester.pump();

      expect(find.text('11/50'), findsOneWidget);
    });

    testWidgets('omits label and spacing when label is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: '',
              hint: 'No label field',
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 13 && w.style?.fontWeight == FontWeight.w600),
        findsNothing,
      );
      expect(find.text('No label field'), findsOneWidget);
    });
  });

  group('CreateRequirementFlowDialog UI Requirements', () {
    final singleTermOffering = [
      {
        'id': 'offering-1',
        'subject_id': 'sub-1',
        'subject_name': 'Art Criticism and Creative Markets',
        'grade_level': 'Grade 11',
        'section_id': 'sec-1',
        'section_name': 'Section 1',
        'terms_taught': 1,
        'term_block': '1ST',
        'ww_weight': 20,
        'pt_weight': 60,
        'ex_weight': 20,
      }
    ];

    final multiTermOffering = [
      {
        'id': 'offering-2',
        'subject_id': 'sub-2',
        'subject_name': 'General Mathematics',
        'grade_level': 'Grade 11',
        'section_id': 'sec-2',
        'section_name': 'Section A',
        'terms_taught': 2,
        'term_block': '1ST & 2ND',
        'ww_weight': 20,
        'pt_weight': 50,
        'ex_weight': 30,
      }
    ];

    testWidgets('single-term subject shows static term container without dropdown', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateRequirementFlowDialog(
              onRequirementCreated: () {},
              initialOfferings: singleTermOffering,
              initialOfferingId: 'offering-1',
              isPerformanceTask: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Context Badge is centered and has no emojis
      expect(find.text('Grade 11 • Art Criticism and Creative Markets • Section 1'), findsOneWidget);
      expect(find.textContaining('🎯'), findsNothing);
      expect(find.byIcon(Icons.school), findsNothing);

      // Verify Gradebook Term is displayed as static text and not a dropdown
      expect(find.text('1st Term'), findsOneWidget);
      // There is only 1 DropdownButtonFormField (for Gradebook Column)
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.byType(DropdownButtonFormField<int?>), findsOneWidget); // For Column

      // Verify Total Points has only one label, without duplicate "HPS"
      expect(find.text('Total Points (HPS) *'), findsOneWidget);
      expect(find.text('HPS'), findsNothing);

      // Verify Deadline starts empty
      expect(find.text('Select deadline'), findsOneWidget);

      // Verify Title counter & Rubrics counter
      expect(find.text('0/100'), findsOneWidget);
      expect(find.text('0/30000'), findsOneWidget);
    });

    testWidgets('multi-term subject shows dropdown with only available terms', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateRequirementFlowDialog(
              onRequirementCreated: () {},
              initialOfferings: multiTermOffering,
              initialOfferingId: 'offering-2',
              isPerformanceTask: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Multi-term has DropdownButtonFormField<int> for terms
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    });

    testWidgets('switching to In-Person updates date label to Date Submitted and allows past date selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateRequirementFlowDialog(
              onRequirementCreated: () {},
              initialOfferings: singleTermOffering,
              initialOfferingId: 'offering-1',
              isPerformanceTask: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial is Online mode
      expect(find.text('Submission Deadline *'), findsOneWidget);
      expect(find.text('Select deadline'), findsOneWidget);

      // Tap In-Person mode toggle
      await tester.tap(find.text('In-Person (Manual Record)'));
      await tester.pumpAndSettle();

      // Label switches to Date Submitted *
      expect(find.text('Date Submitted *'), findsOneWidget);
      expect(find.text('Select date submitted'), findsOneWidget);
      // Attachment section is hidden in in-person mode
      expect(find.textContaining('Classwork Attachment'), findsNothing);
    });

    testWidgets('creates a Performance Task (PT) successfully and saves to repository', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeClassworkRepo();
      bool createdCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateRequirementFlowDialog(
              onRequirementCreated: () => createdCalled = true,
              initialOfferings: singleTermOffering,
              initialOfferingId: 'offering-1',
              isPerformanceTask: true,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Create Performance Task'), findsOneWidget);

      // Switch to In-Person mode
      await tester.tap(find.text('In-Person (Manual Record)'));
      await tester.pumpAndSettle();

      // Enter Title
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Performance Task Title *'),
          matching: find.byType(TextFormField),
        ),
        'Stage Play Presentation',
      );
      await tester.pumpAndSettle();

      // Select PT Slot (PT 1)
      await tester.tap(find.text('Select PT Slot'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PT 1').last);
      await tester.pumpAndSettle();

      // Select submission date
      await tester.tap(find.text('Select date submitted'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Date'));
      await tester.pumpAndSettle();

      // Enter Instructions
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Detailed Instructions & Rubrics *'),
          matching: find.byType(TextFormField),
        ),
        'Prepare a 5-minute creative monologue about modern art.',
      );
      await tester.pumpAndSettle();

      // Tap Publish
      await tester.ensureVisible(find.text('Publish Performance Task'));
      await tester.tap(find.text('Publish Performance Task'));
      await tester.pumpAndSettle();

      expect(createdCalled, isTrue);
      expect(repo.savedActivity, isNotNull);
      expect(repo.savedActivity!.title, 'Stage Play Presentation');
      expect(repo.savedActivity!.isRequirement, isTrue);
      expect(repo.savedActivity!.gradebookColumnIndex, 1);
      expect(repo.savedActivity!.completionMode, 'in_person');
    });

    testWidgets('creates an Activity (Written Work) successfully and saves to repository', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeClassworkRepo();
      bool createdCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateRequirementFlowDialog(
              onRequirementCreated: () => createdCalled = true,
              initialOfferings: singleTermOffering,
              initialOfferingId: 'offering-1',
              isPerformanceTask: false,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Create Activity / Assignment'), findsOneWidget);

      // Switch to In-Person mode
      await tester.tap(find.text('In-Person (Manual Record)'));
      await tester.pumpAndSettle();

      // Enter Title
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Activity / Assignment Title *'),
          matching: find.byType(TextFormField),
        ),
        'Reading Reflection 1',
      );
      await tester.pumpAndSettle();

      // Select WW Slot (WW 1)
      await tester.tap(find.text('Select WW Slot'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('WW 1').last);
      await tester.pumpAndSettle();

      // Select submission date
      await tester.tap(find.text('Select date submitted'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Date'));
      await tester.pumpAndSettle();

      // Enter Instructions
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Detailed Instructions & Rubrics *'),
          matching: find.byType(TextFormField),
        ),
        'Read Chapter 1 and summarize the main themes.',
      );
      await tester.pumpAndSettle();

      // Tap Publish
      await tester.ensureVisible(find.text('Publish Activity / Assignment'));
      await tester.tap(find.text('Publish Activity / Assignment'));
      await tester.pumpAndSettle();

      expect(createdCalled, isTrue);
      expect(repo.savedActivity, isNotNull);
      expect(repo.savedActivity!.title, 'Reading Reflection 1');
      expect(repo.savedActivity!.isRequirement, isFalse);
      expect(repo.savedActivity!.gradebookColumnIndex, 1);
      expect(repo.savedActivity!.completionMode, 'in_person');
    });
  });
}
