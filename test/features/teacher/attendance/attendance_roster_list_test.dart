import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_roster_list.dart';

void main() {
  group('AttendanceRosterList', () {
    final sampleMale1 = AttendanceRosterStudent(
      studentId: 'm1',
      firstName: 'Juan',
      middleName: 'Hernandez',
      lastName: 'Dela Cruz',
      gender: 'male',
    );
    final sampleMale2 = AttendanceRosterStudent(
      studentId: 'm2',
      firstName: 'alan',
      middleName: 'bautista',
      lastName: 'alvarez',
      gender: 'male',
    );
    final sampleFemale1 = AttendanceRosterStudent(
      studentId: 'f1',
      firstName: 'Maria',
      middleName: 'Santos',
      lastName: 'Aquino',
      gender: 'female',
    );
    final sampleUnspecified1 = AttendanceRosterStudent(
      studentId: 'u1',
      firstName: 'Alex',
      lastName: 'Reyes',
      gender: 'other',
    );

    testWidgets('renders surname-first display name with middle initial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceRosterList(
              students: [sampleMale1],
              statuses: const {},
              onStatusChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Dela Cruz, Juan H.'), findsOneWidget);
    });

    testWidgets('sorts students case-insensitively within gender groups', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceRosterList(
              students: [sampleMale1, sampleMale2],
              statuses: const {},
              onStatusChanged: (_) {},
            ),
          ),
        ),
      );

      // 'alvarez, alan B.' should appear before 'Dela Cruz, Juan H.'
      final alvarezFinder = find.text('alvarez, alan B.');
      final delaCruzFinder = find.text('Dela Cruz, Juan H.');
      expect(alvarezFinder, findsOneWidget);
      expect(delaCruzFinder, findsOneWidget);

      final alvarezTop = tester.getTopLeft(alvarezFinder).dy;
      final delaCruzTop = tester.getTopLeft(delaCruzFinder).dy;
      expect(alvarezTop, lessThan(delaCruzTop));
    });

    testWidgets('displays Male before Female, and keeps Unspecified group visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceRosterList(
              students: [sampleFemale1, sampleMale1, sampleUnspecified1],
              statuses: const {},
              onStatusChanged: (_) {},
            ),
          ),
        ),
      );

      final maleHeader = find.textContaining('Male');
      final femaleHeader = find.textContaining('Female');
      final unspecifiedHeader = find.textContaining('Unspecified');

      expect(maleHeader, findsOneWidget);
      expect(femaleHeader, findsOneWidget);
      expect(unspecifiedHeader, findsOneWidget);

      final maleTop = tester.getTopLeft(maleHeader).dy;
      final femaleTop = tester.getTopLeft(femaleHeader).dy;
      final unspecifiedTop = tester.getTopLeft(unspecifiedHeader).dy;

      expect(maleTop, lessThan(femaleTop));
      expect(femaleTop, lessThan(unspecifiedTop));
    });

    testWidgets('paginates 30 combined students across gender boundaries without resetting count', (tester) async {
      // 25 male + 20 female students = 45 total students
      final males = List.generate(
        25,
        (i) => AttendanceRosterStudent(
          studentId: 'm_$i',
          firstName: 'MaleFirst$i',
          lastName: 'MaleLast${i.toString().padLeft(2, '0')}',
          gender: 'male',
        ),
      );
      final females = List.generate(
        20,
        (i) => AttendanceRosterStudent(
          studentId: 'f_$i',
          firstName: 'FemaleFirst$i',
          lastName: 'FemaleLast${i.toString().padLeft(2, '0')}',
          gender: 'female',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceRosterList(
                students: [...males, ...females],
                statuses: const {},
                onStatusChanged: (_) {},
                pageSize: 30,
              ),
            ),
          ),
        ),
      );

      // Page 1 should contain 30 total students: all 25 males and first 5 females (00 to 04)
      expect(find.text('MaleLast00, MaleFirst0'), findsOneWidget);
      expect(find.text('MaleLast24, MaleFirst24'), findsOneWidget);
      expect(find.text('FemaleLast00, FemaleFirst0'), findsOneWidget);
      expect(find.text('FemaleLast04, FemaleFirst4'), findsOneWidget);
      // 6th female should not be in page 1
      expect(find.text('FemaleLast05, FemaleFirst5'), findsNothing);

      // Tapping load more reveals the remaining 15 females
      final loadMoreBtn = find.textContaining('Load More');
      expect(loadMoreBtn, findsOneWidget);
      await tester.ensureVisible(loadMoreBtn);
      await tester.pumpAndSettle();
      await tester.tap(loadMoreBtn);
      await tester.pumpAndSettle();

      // Now female 05 should be visible
      expect(find.text('FemaleLast05, FemaleFirst5'), findsOneWidget);
      expect(find.text('FemaleLast19, FemaleFirst19'), findsOneWidget);
    });

    testWidgets('shows load failure error and retry button, distinguishable from empty roster', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceRosterList(
              students: const [],
              statuses: const {},
              onStatusChanged: (_) {},
              errorMessage: 'Failed to connect to attendance service',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to connect to attendance service'), findsOneWidget);
      expect(find.text('No students are enrolled in this subject and section yet.'), findsNothing);

      final retryBtn = find.text('Retry');
      expect(retryBtn, findsOneWidget);
      await tester.tap(retryBtn);
      expect(retried, isTrue);
    });

    testWidgets('invokes onStatusChanged when marking student status', (tester) async {
      MapEntry<String, AttendanceStatus?>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceRosterList(
              students: [sampleMale1],
              statuses: const {},
              onStatusChanged: (entry) => changed = entry,
            ),
          ),
        ),
      );

      final presentBtn = find.byTooltip('Mark Present');
      expect(presentBtn, findsOneWidget);
      await tester.tap(presentBtn);

      expect(changed?.key, 'm1');
      expect(changed?.value, AttendanceStatus.present);
    });
  });
}
