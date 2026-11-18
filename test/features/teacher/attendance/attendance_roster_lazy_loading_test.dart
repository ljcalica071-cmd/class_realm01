import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart';

void main() {
  group('AttendanceRosterTable Lazy Loading Pagination Tests', () {
    List<AttendanceRosterStudent> generateStudents(int count) {
      return List.generate(
        count,
        (i) => AttendanceRosterStudent(
          studentId: 'student-$i',
          firstName: 'Student',
          lastName: 'Number$i',
          gender: i % 2 == 0 ? 'male' : 'female',
        ),
      );
    }

    testWidgets('Displays all students badge when total count is <= 20 (e.g. 2 students)', (tester) async {
      final twoStudents = generateStudents(2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceRosterTable(
                students: twoStudents,
                statuses: const {},
                sources: const {},
                timesIn: const {},
                remarks: const {},
                searchQuery: '',
                onSearchChanged: (_) {},
                onStatusChanged: (_, _) {},
                onRemarkChanged: (_, _) {},
                onLinkRfidTap: (_) {},
                isLocked: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display "All 2 students loaded" badge matching Classwork design
      expect(find.text('All 2 students loaded'), findsOneWidget);
      // Should NOT display Load More button
      expect(find.textContaining('Load More'), findsNothing);
    });

    testWidgets('Lazy loads by 20 and automatically loads more when scrolling near bottom', (tester) async {
      final twentyFiveStudents = generateStudents(25);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceRosterTable(
                students: twentyFiveStudents,
                statuses: const {},
                sources: const {},
                timesIn: const {},
                remarks: const {},
                searchQuery: '',
                onSearchChanged: (_) {},
                onStatusChanged: (_, _) {},
                onRemarkChanged: (_, _) {},
                onLinkRfidTap: (_) {},
                isLocked: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows 20 of 25 students
      expect(find.text('Showing 20 of 25 students'), findsOneWidget);
      expect(find.text('Load More (Scroll to show 5 remaining)'), findsOneWidget);
      expect(find.text('All 25 students loaded'), findsNothing);

      // Scroll SingleChildScrollView downwards towards bottom
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Auto scroll-to-load triggered: all 25 students are loaded
      expect(find.text('All 25 students loaded'), findsOneWidget);
      expect(find.textContaining('Load More'), findsNothing);
    });

    testWidgets('Tapping Load More button directly loads the next batch', (tester) async {
      final twentyFiveStudents = generateStudents(25);

      // Set viewport high enough so button is on-screen without auto-scroll trigger
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceRosterTable(
                students: twentyFiveStudents,
                statuses: const {},
                sources: const {},
                timesIn: const {},
                remarks: const {},
                searchQuery: '',
                onSearchChanged: (_) {},
                onStatusChanged: (_, _) {},
                onRemarkChanged: (_, _) {},
                onLinkRfidTap: (_) {},
                isLocked: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Showing 20 of 25 students'), findsOneWidget);
      final loadMoreBtn = find.text('Load More (Scroll to show 5 remaining)');
      expect(loadMoreBtn, findsOneWidget);

      await tester.tap(loadMoreBtn);
      await tester.pumpAndSettle();

      expect(find.text('All 25 students loaded'), findsOneWidget);
      expect(find.textContaining('Load More'), findsNothing);
    });
  });
}
