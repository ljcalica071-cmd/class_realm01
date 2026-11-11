import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/widgets/timetable_grid_widget.dart';

void main() {
  testWidgets('TimetableGridWidget renders schedule blocks with teacherName and collision layout', (tester) async {
    final s1 = ScheduleModel(
      id: 'sched-1',
      subject: 'General Mathematics',
      section: 'Section Emerald',
      room: 'Room 301',
      dayOfWeek: 'Monday',
      startTime: '08:00 AM',
      endTime: '09:30 AM',
      teacherId: 'teacher-me',
      teacherName: 'Sir Juan Dela Cruz',
      gradeLevel: 11,
    );

    final s2 = ScheduleModel(
      id: 'sched-2',
      subject: 'Oral Communication',
      section: 'Section Diamond',
      room: 'Room 302',
      dayOfWeek: 'Monday',
      startTime: '08:00 AM',
      endTime: '09:00 AM',
      teacherId: 'teacher-other',
      teacherName: 'Ma\'am Maria Santos',
      gradeLevel: 11,
    );

    ScheduleModel? tappedSchedule;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: TimetableGridWidget(
              schedules: [s1, s2],
              currentTeacherId: 'teacher-me',
              onEdit: (s) {
                tappedSchedule = s;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both subjects are visible
    expect(find.text('General Mathematics'), findsOneWidget);
    expect(find.text('Oral Communication'), findsOneWidget);

    // Verify teacher names and ownership indicators
    expect(find.text('Sir Juan Dela Cruz (You)'), findsOneWidget);
    expect(find.text('Ma\'am Maria Santos'), findsOneWidget);

    // Verify rooms and sections
    expect(find.text('Section Emerald • Room 301'), findsOneWidget);
    expect(find.text('Section Diamond • Room 302'), findsOneWidget);

    // Tap on s2 to verify callback
    await tester.tap(find.text('Oral Communication'));
    expect(tappedSchedule?.id, 'sched-2');
  });
}
