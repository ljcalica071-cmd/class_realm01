import 'package:class_realm/models/attendance_workspace_models.dart';

class AttendanceAnalyticsCalculator {
  const AttendanceAnalyticsCalculator._();

  static bool isAtRisk({required int absentCount}) {
    if (absentCount < 0) {
      throw ArgumentError.value(
        absentCount,
        'absentCount',
        'Absence count must be nonnegative.',
      );
    }
    return absentCount >= 3;
  }

  static AttendancePresenceMetrics calculatePresenceMetrics({
    required int present,
    required int late,
    required int absent,
    required int excused,
  }) {
    final counts = {
      'present': present,
      'late': late,
      'absent': absent,
      'excused': excused,
    };
    for (final entry in counts.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Attendance counts must be nonnegative.',
        );
      }
    }

    final presenceCount = present + late;
    final denominator = presenceCount + absent;
    return AttendancePresenceMetrics(
      presenceRate: denominator == 0 ? null : presenceCount / denominator,
      absencesAndExcuses: absent + excused,
    );
  }
}
