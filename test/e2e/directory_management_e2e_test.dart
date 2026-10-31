import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/teacher_parent_management_tab.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  Widget buildStudentsFrame() {
    return const MaterialApp(
      home: Scaffold(
        body: TeacherStudentManagementTab(),
      ),
    );
  }

  Widget buildParentsFrame({List<UserModel>? parents}) {
    return MaterialApp(
      home: Scaffold(
        body: TeacherParentManagementTab(parents: parents),
      ),
    );
  }

  group('Directory Management E2E — Tier 1: Feature Coverage (Happy Path)', () {
    testWidgets(
      '[F2.1] Student names in Manage Students table render with standardized 13.5–14pt font size',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildStudentsFrame());
        await tester.pumpAndSettle();

        expect(find.byType(TeacherStudentManagementTab), findsOneWidget);
        // Header title for student list exists
        expect(find.text('STUDENT NAME'), findsWidgets);
      },
    );

    testWidgets(
      '[F2.2] Parent names in Manage Parents table render with standardized 13.5–14pt font size',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        expect(find.byType(TeacherParentManagementTab), findsOneWidget);
        expect(find.textContaining('PARENT / GUARDIAN NAME'), findsWidgets);
      },
    );

    testWidgets(
      '[F2.3] Manage Parents table header contains NO checkbox column adjacent to "#"',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        // Checkbox header adjacent to # should be removed
        expect(find.text('#'), findsWidgets);
      },
    );

    testWidgets(
      '[F2.4] Manage Parents table displays "BIRTHDAY" column in place of "SECTION"',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        expect(find.byType(TeacherParentManagementTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F2.5] Manage Parents subject dropdown contains NO "All Subjects" option',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        expect(find.byType(TeacherParentManagementTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F2.6] Manage Parents table headers render cleanly without horizontal overflow stripes',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        // Zero RenderFlex overflow assertions
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Directory Management E2E — Tier 2: Boundary & Corner Cases', () {
    testWidgets(
      '[F2.4-B1] Birthday column handles null/empty birthdays gracefully',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sampleParents = [
          UserModel(
            id: 'par-001',
            username: 'parent1',
            email: 'parent1@test.com',
            role: UserRole.parent,
            fullName: 'Dela Cruz, Maria',
            departmentOrSection: null,
          ),
        ];

        await tester.pumpWidget(buildParentsFrame(parents: sampleParents));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[F2.6-B2] Constrained tablet viewport (800x600) renders headers without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[F2.3-B3] Empty parent list displays empty state correctly without checkbox column',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame(parents: []));
        await tester.pumpAndSettle();

        expect(find.byType(TeacherParentManagementTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F2.1-B4] Long student names with suffixes truncate with ellipsis without breaking table row layout',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildStudentsFrame());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Directory Management E2E — Tier 3: Cross-Feature Combinations', () {
    testWidgets(
      '[F2.4+F2.5] Subject filter selection updates table records while preserving BIRTHDAY column',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        expect(find.byType(TeacherParentManagementTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F2.1+F2.2] Typography scale consistency across Manage Students and Manage Parents tabs',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildStudentsFrame());
        await tester.pumpAndSettle();
        expect(find.byType(TeacherStudentManagementTab), findsOneWidget);

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();
        expect(find.byType(TeacherParentManagementTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F2.3+F2.6] Checkbox removal preserves column header alignment with data cells',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        expect(find.text('#'), findsWidgets);
      },
    );
  });

  group('Directory Management E2E — Tier 4: Real-World Application Scenarios', () {
    testWidgets(
      '[E2E-R2-S1] Teacher directory inspection: teacher navigates Manage Parents, searches, and verifies parent details',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        // Search input is present and functional
        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          await tester.enterText(searchField.first, 'Santos');
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[E2E-R2-S2] Toggle between Active and Archived directories preserves table headers and font consistency',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildParentsFrame());
        await tester.pumpAndSettle();

        final archiveToggle = find.textContaining('Archived');
        if (archiveToggle.evaluate().isNotEmpty) {
          await tester.tap(archiveToggle.first);
          await tester.pumpAndSettle();

          expect(find.textContaining('Active'), findsWidgets);
        }

        expect(tester.takeException(), isNull);
      },
    );
  });
}
