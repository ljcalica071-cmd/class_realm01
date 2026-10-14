import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';

abstract class AttendanceRepository {
  // Legacy compatibility methods
  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId);
  Future<List<AttendanceRecord>> getAllAttendanceRecords();
  Future<void> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
  });
  Future<void> toggleOfflineSync();
  SyncStatus getSyncStatus();

  // Teacher Workspace methods
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  });

  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records,
  });

  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  );

  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  });

  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  });

  // Student self methods
  Future<AttendanceStudentSummary> getMyAttendanceSummary();

  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  });
}
