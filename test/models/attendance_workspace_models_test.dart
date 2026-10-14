import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';

void main() {
  group('AttendanceWorkspaceRecord source parsing', () {
    test('maps a missing legacy source to manual', () {
      final record = AttendanceWorkspaceRecord.fromJson({
        'id': 'record-1',
        'student_id': 'student-1',
        'subject_offering_id': 'offering-1',
        'attendance_date': '2026-10-11',
        'status': 'present',
        'source': null,
        'created_at': null,
      });

      expect(record.source, AttendanceSource.manual);
      expect(record.createdAt, isNull);
    });

    test('rejects unsupported source values', () {
      expect(
        () => AttendanceWorkspaceRecord.fromJson({
          'id': 'record-1',
          'student_id': 'student-1',
          'subject_offering_id': 'offering-1',
          'attendance_date': '2026-10-11',
          'status': 'present',
          'source': 'RFID (ESP32)',
        }),
        throwsFormatException,
      );
    });

    test('round trips record fields without inventing a creation time', () {
      final createdAt = DateTime.utc(2026, 10, 11, 9, 30);
      final original = AttendanceWorkspaceRecord(
        id: null,
        studentId: 'student-1',
        subjectOfferingId: 'offering-1',
        attendanceDate: DateTime(2026, 10, 11),
        status: AttendanceStatus.late,
        source: AttendanceSource.manual,
        remarks: 'Arrived after start',
        recordedBy: 'teacher-1',
        createdAt: createdAt,
        modifiedBy: null,
      );

      final decoded = AttendanceWorkspaceRecord.fromJson(original.toJson());

      expect(decoded.id, isNull);
      expect(decoded.studentId, original.studentId);
      expect(decoded.subjectOfferingId, original.subjectOfferingId);
      expect(decoded.attendanceDate, original.attendanceDate);
      expect(decoded.status, original.status);
      expect(decoded.source, original.source);
      expect(decoded.remarks, original.remarks);
      expect(decoded.recordedBy, original.recordedBy);
      expect(decoded.createdAt, createdAt);
      expect(decoded.modifiedBy, isNull);
    });
  });

  group('attendance workspace value models', () {
    test('validates and represents inclusive date ranges', () {
      final range = AttendanceDateRange(
        startDate: DateTime(2026, 10, 1, 18),
        endDate: DateTime(2026, 10, 11, 8),
      );

      expect(range.startDate, DateTime(2026, 10, 1));
      expect(range.endDate, DateTime(2026, 10, 11));
      expect(
        () => AttendanceDateRange(
          startDate: DateTime(2026, 10, 12),
          endDate: DateTime(2026, 10, 11),
        ),
        throwsArgumentError,
      );
    });

    test('uses the stable history page size by default', () {
      final filter = AttendanceHistoryFilter(
        subjectOfferingId: 'offering-1',
        dateRange: AttendanceDateRange(
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 31),
        ),
      );
      final page = AttendancePage<String>(
        rows: const ['row-1', 'row-2'],
        nextOffset: 2,
        hasMore: true,
      );

      expect(filter.offset, 0);
      expect(filter.pageSize, 20);
      expect(page.rows, ['row-1', 'row-2']);
      expect(page.nextOffset, 2);
      expect(page.hasMore, isTrue);
    });

    test('serializes and deserializes AttendanceStudentSummary', () {
      final summary = AttendanceStudentSummary(
        studentId: 'student-42',
        presentCount: 18,
        totalDays: 20,
        presenceRate: 0.9,
      );

      final json = summary.toJson();
      final decoded = AttendanceStudentSummary.fromJson(json);

      expect(decoded.studentId, 'student-42');
      expect(decoded.presentCount, 18);
      expect(decoded.totalDays, 20);
      expect(decoded.presenceRate, 0.9);
    });

    test('formats student display name as Surname, First Name M.I.', () {
      const studentWithMiddle = AttendanceRosterStudent(
        studentId: 's1',
        firstName: 'Juan',
        middleName: 'Hernandez',
        lastName: 'Dela Cruz',
        gender: 'male',
      );
      expect(studentWithMiddle.displayName, 'Dela Cruz, Juan H.');

      const studentWithoutMiddle = AttendanceRosterStudent(
        studentId: 's2',
        firstName: 'Maria',
        middleName: null,
        lastName: 'Santos',
        gender: 'female',
      );
      expect(studentWithoutMiddle.displayName, 'Santos, Maria');
    });

    test('supports const AttendanceAnalyticsSummary and trend points with periodLabel', () {
      const trendPoint = AttendanceTrendPoint(
        periodLabel: '10/12',
        presentCount: 20,
        absentOrExcusedCount: 2,
      );
      expect(trendPoint.periodLabel, '10/12');
      expect(trendPoint.bucketStart, isNull);
      expect(trendPoint.presentCount, 20);
      expect(trendPoint.absentOrExcusedCount, 2);

      const summary = AttendanceAnalyticsSummary(
        presenceRate: 0.9,
        absencesAndExcuses: 2,
        warningCount: 0,
        presentCount: 20,
        lateCount: 1,
        absentCount: 1,
        excusedCount: 1,
        trendPoints: [trendPoint],
      );
      expect(summary.presenceRate, 0.9);
      expect(summary.trendPoints.first.periodLabel, '10/12');
      expect(summary.atRiskStudents, isEmpty);
    });
  });
}
