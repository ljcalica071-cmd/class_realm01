import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';

class TestAttendanceRepository extends AttendanceRepository {
  bool correctRecordCalled = false;
  String? passedRecordId;
  AttendanceStatus? passedNewStatus;
  String? passedReason;
  bool shouldThrow = false;

  @override
  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Correction reason must not be blank.');
    }
    if (shouldThrow) {
      throw Exception('Database constraint violation or unauthorized');
    }
    correctRecordCalled = true;
    passedRecordId = recordId;
    passedNewStatus = newStatus;
    passedReason = reason;
  }

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async => throw UnimplementedError();

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async => throw UnimplementedError();

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async => throw UnimplementedError();

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records,
    List<String>? deletedStudentIds,
  }) async => throw UnimplementedError();

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async =>
      throw UnimplementedError();

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async => throw UnimplementedError();

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async => [];

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId) async =>
      [];

  @override
  SyncStatus getSyncStatus() => SyncStatus.online;

  @override
  Future<void> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
  }) async {}

  @override
  Future<void> toggleOfflineSync() async {}
}

void main() {
  group('Attendance Correction Unit Contract', () {
    late TestAttendanceRepository repo;

    setUp(() {
      repo = TestAttendanceRepository();
    });

    test('rejects blank correction reason with ArgumentError', () async {
      expect(
        () => repo.correctAttendanceRecord(
          subjectOfferingId: 'off-1',
          recordId: 'rec-1',
          newStatus: AttendanceStatus.present,
          reason: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(repo.correctRecordCalled, isFalse);
    });

    test('submits valid correction parameters successfully', () async {
      await repo.correctAttendanceRecord(
        subjectOfferingId: 'off-1',
        recordId: 'rec-1',
        newStatus: AttendanceStatus.present,
        reason: 'Excused due to approved medical leave',
      );

      expect(repo.correctRecordCalled, isTrue);
      expect(repo.passedRecordId, 'rec-1');
      expect(repo.passedNewStatus, AttendanceStatus.present);
      expect(repo.passedReason, 'Excused due to approved medical leave');
    });

    test('propagates repository error on failure', () async {
      repo.shouldThrow = true;
      expect(
        () => repo.correctAttendanceRecord(
          subjectOfferingId: 'off-1',
          recordId: 'rec-1',
          newStatus: AttendanceStatus.present,
          reason: 'Valid reason',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
