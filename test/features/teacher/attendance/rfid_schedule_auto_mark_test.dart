import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';

void main() {
  group('RFID Schedule Auto-Mark Evaluation Contract', () {
    test('parseTimeToMinutes parses HH:mm:ss and HH:mm correctly', () {
      expect(SupabaseAttendanceRepository.parseTimeToMinutes('08:00:00'), 480);
      expect(SupabaseAttendanceRepository.parseTimeToMinutes('09:00:00'), 540);
      expect(SupabaseAttendanceRepository.parseTimeToMinutes('10:14:00'), 614);
      expect(SupabaseAttendanceRepository.parseTimeToMinutes('18:30'), 1110);
      expect(SupabaseAttendanceRepository.parseTimeToMinutes(null), isNull);
      expect(SupabaseAttendanceRepository.parseTimeToMinutes('invalid'), isNull);
    });

    test('AttendanceScheduleStatus lock conditions', () {
      final statusScheduled = AttendanceScheduleStatus(
        hasPlottedScheduleAnyDay: true,
        isScheduledOnDate: true,
        startTime: '08:00:00',
        endTime: '09:00:00',
        cutoffConfig: AttendanceCutoffConfig(
          subjectOfferingId: 'sub-1',
          presentGraceMins: 20,
          lateCutoffMins: 45,
          absentCutoffMins: 60,
        ),
      );

      expect(statusScheduled.isLockedByDefault, isFalse);
      expect(statusScheduled.lockReason, isNull);

      final statusHoliday = AttendanceScheduleStatus(
        hasPlottedScheduleAnyDay: true,
        isScheduledOnDate: true,
        isHoliday: true,
        holidayName: 'Bonifacio Day',
        cutoffConfig: AttendanceCutoffConfig(subjectOfferingId: 'sub-1'),
      );

      expect(statusHoliday.isLockedByDefault, isTrue);
      expect(statusHoliday.lockReason, contains('Bonifacio Day'));

      final statusNoScheduleSet = AttendanceScheduleStatus(
        hasPlottedScheduleAnyDay: false,
        isScheduledOnDate: false,
        cutoffConfig: AttendanceCutoffConfig(subjectOfferingId: 'sub-1'),
      );

      expect(statusNoScheduleSet.isLockedByDefault, isTrue);
      expect(statusNoScheduleSet.lockReason, contains('My Schedule'));
    });
  });
}

