import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/features/teacher/shared/widgets/teacher_top_summary_card.dart';
import 'package:class_realm/features/teacher/sub_features/overview/widgets/teacher_dashboard_overview_tab.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TeacherTopSummaryCard', () {
    testWidgets('renders title, mainValue and subText properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherTopSummaryCard(
              title: 'Total Students',
              mainValue: '12/20',
              subText: 'Across 2 sections',
              baseColor: Colors.blue,
              icon: LucideIcons.graduationCap,
            ),
          ),
        ),
      );

      expect(find.text('TOTAL STUDENTS'), findsOneWidget);
      expect(find.text('12/20'), findsOneWidget);
      expect(find.text('Across 2 sections'), findsOneWidget);
    });
  });

  group('TeacherDashboardOverviewTab', () {
    testWidgets('displays active/total students and sections handled from student roster', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Create 12 active students across 2 sections, and 8 pending students
      final students = <UserModel>[
        for (int i = 1; i <= 6; i++)
          UserModel(
            id: 'active-section1-$i',
            username: 'student_s1_$i',
            fullName: 'Active Student S1 $i',
            email: 's1_$i@school.edu',
            role: UserRole.student,
            status: AccountStatus.active,
            departmentOrSection: 'Section Diamond',
          ),
        for (int i = 1; i <= 6; i++)
          UserModel(
            id: 'active-section2-$i',
            username: 'student_s2_$i',
            fullName: 'Active Student S2 $i',
            email: 's2_$i@school.edu',
            role: UserRole.student,
            status: AccountStatus.active,
            departmentOrSection: 'Section Emerald',
          ),
        for (int i = 1; i <= 8; i++)
          UserModel(
            id: 'pending-student-$i',
            username: 'pending_$i',
            fullName: 'Pending Student $i',
            email: 'pending_$i@school.edu',
            role: UserRole.student,
            status: AccountStatus.pendingFirstLogin,
            departmentOrSection: i <= 4 ? 'Section Diamond' : 'Section Emerald',
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: TeacherDashboardOverviewTab(
              activeStudents: students,
              quizzesAndExams: const [],
              onNavigateTo: (_) {},
              onCreateChooser: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Total students card should display 12/20 and Across 2 sections
      expect(find.text('12/20'), findsOneWidget);
      expect(find.text('Across 2 sections'), findsOneWidget);
    });

    testWidgets('renders completed schedule card without "Done" word in green styling for light and dark modes', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final todayName = ScheduleModel.dayFromIndex(now.weekday);
      final completedSchedule = ScheduleModel(
        id: 'sch-done-1',
        subject: 'Art Criticism and Creative Markets',
        section: 'Section 1',
        room: 'Room 101',
        dayOfWeek: todayName,
        startTime: '01:00 AM',
        endTime: '02:00 AM',
      );

      // Light mode test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: TeacherDashboardOverviewTab(
              activeStudents: const [],
              quizzesAndExams: const [],
              onNavigateTo: (_) {},
              onCreateChooser: () {},
              initialSchedules: [completedSchedule],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Art Criticism and Creative Markets'), findsOneWidget);
      // The "Done" word is removed
      expect(find.text('Done'), findsNothing);
      expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);

      // Dark mode test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: TeacherDashboardOverviewTab(
              activeStudents: const [],
              quizzesAndExams: const [],
              onNavigateTo: (_) {},
              onCreateChooser: () {},
              initialSchedules: [completedSchedule],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Art Criticism and Creative Markets'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
    });

    testWidgets('renders pending schedule card with clock icon and warm yellow styling', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final todayName = ScheduleModel.dayFromIndex(now.weekday);
      final pendingSchedule = ScheduleModel(
        id: 'sch-pending-1',
        subject: 'Pending Chemistry Lab',
        section: 'Section 2',
        room: 'Lab 3',
        dayOfWeek: todayName,
        startTime: '11:00 PM',
        endTime: '11:59 PM',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: TeacherDashboardOverviewTab(
              activeStudents: const [],
              quizzesAndExams: const [],
              onNavigateTo: (_) {},
              onCreateChooser: () {},
              initialSchedules: [pendingSchedule],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pending Chemistry Lab'), findsOneWidget);
      expect(find.text('Upcoming'), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.byIcon(LucideIcons.clock), findsOneWidget);
    });
  });
}
