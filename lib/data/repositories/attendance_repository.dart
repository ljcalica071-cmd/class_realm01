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
    List<String>? deletedStudentIds,
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

  // Schedule, Holiday & Cutoff Configuration (R3)
  Future<AttendanceScheduleStatus> getScheduleAndCutoffStatus({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    return AttendanceScheduleStatus(
      hasPlottedScheduleAnyDay: false,
      isScheduledOnDate: true,
      cutoffConfig: AttendanceCutoffConfig(subjectOfferingId: subjectOfferingId),
    );
  }

  Future<void> saveCutoffConfig(AttendanceCutoffConfig config) async {}

  // RFID Card Management & Atomic Scan Operations (R2, R4, R5)
  Future<RfidCardConflictCheck> checkRfidUidConflict({
    required String rfidUid,
    String? excludeStudentId,
  }) async {
    return const RfidCardConflictCheck(isTaken: false);
  }

  Future<void> assignStudentRfid({
    required String studentId,
    required String? rfidUid,
    bool forceReassign = false,
  }) async {}

  Future<RfidScanOutcome> recordRfidScan({
    required String rfidUid,
    required String subjectOfferingId,
    DateTime? scanTimestamp,
    String deviceId = 'USB_SCANNER',
  }) async {
    return const RfidScanOutcome(
      success: false,
      code: 'UNIMPLEMENTED',
      message: 'RFID scan handler is not configured.',
    );
  }

  Future<int> syncOfflineAttendanceQueue() async => 0;

  // Student self methods
  Future<AttendanceStudentSummary> getMyAttendanceSummary();

  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  });
}
