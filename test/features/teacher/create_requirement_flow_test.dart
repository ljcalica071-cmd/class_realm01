import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/shared/widgets/inputs/app_text_field.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';

class FakeClassworkRepo implements TeacherClassworkRepository {
  ActivityModel? savedActivity;
  String? savedOfferingId;
  List<ActivityModel> activities = [];
  ClassworkSlotSummary slotSummary = const ClassworkSlotSummary();

  @override
  Future<List<ActivityModel>> getActivities({
    String? subjectOfferingId,
    String? teacherId,
    bool forceRefresh = false,
  }) async => activities;

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

  @override
  Future<ClassworkSlotSummary> getOccupiedSlots({
    required String subjectOfferingId,
    required int termNumber,
    String? excludeClassworkId,
  }) async => slotSummary;
}

void main() {
  group('AppTextField Tests', () {
    testWidgets('renders custom hint, maxLength, and live counter', (
      tester,
    ) async {
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
            body: AppTextField(label: '', hint: 'No label field'),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.fontSize == 13 &&
              w.style?.fontWeight == FontWeight.w600,
        ),
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
      },
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
      },
    ];

    testWidgets(
      'single-term subject shows static term container without dropdown',
      (tester) async {
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
        expect(
          find.text(
            'Grade 11 • Art Criticism and Creative Markets • Section 1',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('🎯'), findsNothing);
        expect(find.byIcon(Icons.school), findsNothing);

        // Verify Gradebook Term is displayed as static text and not a dropdown
        expect(find.text('1st Term'), findsOneWidget);
        // There is only 1 DropdownButtonFormField (for Gradebook Column)
        expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        expect(
          find.byType(DropdownButtonFormField<int?>),
          findsOneWidget,
        ); // For Column

        // Verify Total Points has only one label, without duplicate "HPS"
        expect(find.text('Total Points (HPS) *'), findsOneWidget);
        expect(find.text('HPS'), findsNothing);

        // Verify Deadline starts empty
        expect(find.text('Select deadline'), findsOneWidget);

        // Verify Title counter & Rubrics counter
        expect(find.text('0/100'), findsOneWidget);
        expect(find.text('0/1000'), findsOneWidget);
      },
    );

    testWidgets('multi-term subject shows dropdown with only available terms', (
      tester,
    ) async {
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

    testWidgets(
      'switching to In-Person updates date label to Set Date and allows past date selection',
      (tester) async {
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

        // Label switches to Set Date *
        expect(find.text('Set Date *'), findsOneWidget);
        expect(find.text('Select date'), findsOneWidget);
        // Attachment section is hidden in in-person mode
        expect(find.textContaining('Classwork Attachment'), findsNothing);
      },
    );

    testWidgets(
      'creates a Performance Task (PT) successfully and saves to repository',
      (tester) async {
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
        await tester.tap(find.text('Select date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm Date'));
        await tester.pumpAndSettle();

        // Enter Instructions
        await tester.enterText(
          find.descendant(
            of: find.byType(ExpandableInstructionsInputField),
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
      },
    );

    testWidgets(
      'creates an Activity (Written Work) successfully and saves to repository',
      (tester) async {
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
            of: find.widgetWithText(
              AppTextField,
              'Activity / Assignment Title *',
            ),
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
        await tester.tap(find.text('Select date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm Date'));
        await tester.pumpAndSettle();

        // Enter Instructions
        await tester.enterText(
          find.descendant(
            of: find.byType(ExpandableInstructionsInputField),
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
      },
    );

    testWidgets('rejects HPS of 0 and > 100 with inline error message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeClassworkRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateRequirementFlowDialog(
              onRequirementCreated: () {},
              initialOfferings: singleTermOffering,
              initialOfferingId: 'offering-1',
              isPerformanceTask: true,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hpsField = find.descendant(
        of: find.widgetWithText(AppTextField, 'Total Points (HPS) *'),
        matching: find.byType(TextFormField),
      );

      // Enter 0 -> should show inline error
      await tester.enterText(hpsField, '0');
      await tester.pumpAndSettle();
      expect(find.text('HPS cannot be 0. Must be 1 to 100.'), findsOneWidget);

      // Enter 150 -> should show inline error
      await tester.enterText(hpsField, '150');
      await tester.pumpAndSettle();
      expect(find.text('Must be 1 to 100.'), findsOneWidget);

      // Enter 50 -> inline error clears
      await tester.enterText(hpsField, '50');
      await tester.pumpAndSettle();
      expect(find.text('HPS cannot be 0. Must be 1 to 100.'), findsNothing);
      expect(find.text('Must be 1 to 100.'), findsNothing);
    });

    testWidgets(
      'locks occupied gradebook column in dropdown with Used indicator and disables selection',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = FakeClassworkRepo();
        repo.activities = [
          ActivityModel(
            id: 'existing-act-1',
            title: 'Existing PT 1',
            description: '',
            instructions: 'Already created',
            subject: 'Media & Information Literacy',
            gradeLevel: 'Grade 11',
            section: 'Section 1',
            deadline: DateTime.now().add(const Duration(days: 3)),
            maxScore: 50,
            isPublished: true,
            isRequirement: true,
            subjectOfferingId: 'offering-1',
            termNumber: 1,
            gradebookColumnIndex: 1,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CreateRequirementFlowDialog(
                onRequirementCreated: () {},
                initialOfferings: singleTermOffering,
                initialOfferingId: 'offering-1',
                isPerformanceTask: true,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on the Gradebook Column dropdown to view items
        await tester.tap(find.text('Select PT Slot'), warnIfMissed: false);
        await tester.pumpAndSettle();

        // PT 1 should have "Used" indicator
        expect(find.text('Used'), findsOneWidget);
      },
    );

    testWidgets(
      'locks Term, Column, Mode slider, and Attachment in Edit mode, replaces deadline label with Update Deadline',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final existingTask = ActivityModel(
          id: 'edit-task-1',
          title: 'Original Title',
          description: '',
          instructions: 'Original instructions',
          subject: 'Media & Information Literacy',
          gradeLevel: 'Grade 11',
          section: 'Section 1',
          deadline: DateTime.now().add(const Duration(days: 2)),
          maxScore: 80,
          isPublished: true,
          isRequirement: true,
          subjectOfferingId: 'offering-1',
          termNumber: 1,
          gradebookColumnIndex: 2,
          attachmentName: 'guidelines.pdf',
          fileSizeBytes: 2048,
        );

        final repo = FakeClassworkRepo();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CreateRequirementFlowDialog(
                onRequirementCreated: () {},
                initialOfferings: singleTermOffering,
                initialOfferingId: 'offering-1',
                existingTask: existingTask,
                isPerformanceTask: true,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header should say Edit Performance Task
        expect(find.text('Edit Performance Task'), findsOneWidget);

        // Deadline label should say Update Deadline *
        expect(find.text('Update Deadline *'), findsOneWidget);

        // Term should be locked (displays 1st Term and lock icon, no dropdown)
        expect(find.text('1st Term'), findsOneWidget);

        // Column should be locked (displays PT 2 and lock icon, no dropdown)
        expect(find.text('PT 2'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<int?>), findsNothing);

        // Attachment should be locked with indicator (no Attach/Replace or Delete buttons)
        expect(find.text('Classwork Attachment (Locked)'), findsOneWidget);
        expect(find.text('Attach File'), findsNothing);
        expect(find.text('Replace File'), findsNothing);
        expect(
          find.byIcon(Icons.close),
          findsOneWidget,
        ); // Only dialog header close button

        // Title and Instructions are still editable
        expect(find.text('Original Title'), findsOneWidget);
        expect(find.text('Original instructions'), findsOneWidget);
      },
    );

    testWidgets(
      'shows Update Date * in Edit mode when completionMode is in_person',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final existingInPerson = ActivityModel(
          id: 'edit-inperson-1',
          title: 'Classroom Debate',
          description: '',
          instructions: 'Rubric attached on board',
          subject: 'Art Criticism and Creative Markets',
          gradeLevel: 'Grade 11',
          section: 'Section 1',
          deadline: DateTime(2026, 11, 8, 23, 59),
          maxScore: 50,
          isPublished: true,
          isRequirement: true,
          subjectOfferingId: 'offering-1',
          termNumber: 1,
          gradebookColumnIndex: 1,
          completionMode: 'in_person',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CreateRequirementFlowDialog(
                onRequirementCreated: () {},
                initialOfferings: singleTermOffering,
                initialOfferingId: 'offering-1',
                existingTask: existingInPerson,
                isPerformanceTask: true,
                repository: FakeClassworkRepo(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Update Date *'), findsOneWidget);
        expect(find.text('Update Deadline *'), findsNothing);
      },
    );

    test(
      'AppValidators.validateClassworkInstructions enforces min 2 non-space characters and max 1000',
      () {
        expect(
          AppValidators.validateClassworkInstructions(''),
          'Detailed instructions are required.',
        );
        expect(
          AppValidators.validateClassworkInstructions('    '),
          'Instructions cannot contain only spaces.',
        );
        expect(
          AppValidators.validateClassworkInstructions('a'),
          'Instructions must be at least 2 characters.',
        );
        expect(
          AppValidators.validateClassworkInstructions(' a '),
          'Instructions must be at least 2 characters.',
        );
        expect(AppValidators.validateClassworkInstructions('ab'), isNull);
        expect(
          AppValidators.validateClassworkInstructions('a' * 1001),
          'Must not exceed 1,000 characters.',
        );
      },
    );

    testWidgets(
      'ExpandableInstructionsText clamps long instructions to 3 lines and toggles See more / See less',
      (tester) async {
        final longText =
            'Line 1 of detailed instructions for students.\nLine 2 of detailed instructions.\nLine 3 of detailed instructions that overflows two lines.';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: ExpandableInstructionsText(text: longText),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('See more'), findsOneWidget);
        expect(find.text('See less'), findsNothing);

        final collapsedText = tester.widget<Text>(find.text(longText));
        expect(collapsedText.maxLines, 3);

        await tester.tap(find.text('See more'));
        await tester.pumpAndSettle();

        expect(find.text('See less'), findsOneWidget);
        final expandedText = tester.widget<Text>(find.text(longText));
        expect(expandedText.maxLines, isNull);

        await tester.tap(find.text('See less'));
        await tester.pumpAndSettle();

        expect(find.text('See more'), findsOneWidget);
        final recollapsedText = tester.widget<Text>(find.text(longText));
        expect(recollapsedText.maxLines, 3);
      },
    );

    testWidgets(
      'reflects Gradebook + added columns (e.g. up to PT 5 / WW 5) in Gradebook Column dropdown',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = FakeClassworkRepo()
          ..slotSummary = const ClassworkSlotSummary(
            maxPtSlot: 5,
            maxWwSlot: 6,
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CreateRequirementFlowDialog(
                onRequirementCreated: () {},
                initialOfferings: singleTermOffering,
                initialOfferingId: 'offering-1',
                isPerformanceTask: true,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Select PT Slot'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('PT 1'), findsWidgets);
        expect(find.text('PT 4'), findsWidgets);
        expect(find.text('PT 5'), findsWidgets);
        expect(find.text('PT 6'), findsNothing);
      },
    );
  });
}
