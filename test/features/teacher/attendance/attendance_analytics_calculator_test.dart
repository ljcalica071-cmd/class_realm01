import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/utils/attendance_analytics_calculator.dart';

void main() {
  group('AttendanceAnalyticsCalculator.calculatePresenceMetrics', () {
    test('counts Late as present', () {
      final metrics = AttendanceAnalyticsCalculator.calculatePresenceMetrics(
        present: 6,
        late: 2,
        absent: 2,
        excused: 1,
      );

      expect(metrics.presenceRate, 0.8);
    });

    test(
      'excludes Excused from rate but includes it in absences and excuses',
      () {
        final metrics = AttendanceAnalyticsCalculator.calculatePresenceMetrics(
          present: 6,
          late: 2,
          absent: 2,
          excused: 3,
        );

        expect(metrics.presenceRate, 0.8);
        expect(metrics.absencesAndExcuses, 5);
      },
    );

    test('returns a null rate when the denominator is zero', () {
      final metrics = AttendanceAnalyticsCalculator.calculatePresenceMetrics(
        present: 0,
        late: 0,
        absent: 0,
        excused: 4,
      );

      expect(metrics.presenceRate, isNull);
      expect(metrics.absencesAndExcuses, 4);
    });
  });

  group('AttendanceAnalyticsCalculator.isAtRisk', () {
    test('flags a student with three explicit absences', () {
      expect(AttendanceAnalyticsCalculator.isAtRisk(absentCount: 3), isTrue);
    });

    test('does not flag a student with fewer than three absences', () {
      expect(AttendanceAnalyticsCalculator.isAtRisk(absentCount: 2), isFalse);
    });
  });
}
