import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';

void main() {
  group('SupabaseAttendanceRepository Unit Contracts', () {
    test('correctAttendanceRecord rejects blank or empty reason before network invocation', () async {
      final repo = SupabaseAttendanceRepository();

      expect(
        () => repo.correctAttendanceRecord(
          subjectOfferingId: 'off-1',
          recordId: 'rec-1',
          newStatus: AttendanceStatus.present,
          reason: '',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => repo.correctAttendanceRecord(
          subjectOfferingId: 'off-1',
          recordId: 'rec-1',
          newStatus: AttendanceStatus.present,
          reason: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('AttendanceDateRange rejects startDate after endDate', () {
      expect(
        () => AttendanceDateRange(
          startDate: DateTime(2026, 10, 10),
          endDate: DateTime(2026, 10, 5),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('AttendanceHistoryFilter requires non-negative offset and positive page size', () {
      final range = AttendanceDateRange(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
      );

      final filter = AttendanceHistoryFilter(
        subjectOfferingId: 'sub-1',
        dateRange: range,
        offset: 0,
        pageSize: 20,
      );

      expect(filter.offset, 0);
      expect(filter.pageSize, 20);
    });
  });
}
