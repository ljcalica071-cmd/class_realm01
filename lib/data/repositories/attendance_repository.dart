import 'package:class_realm/models/academic_models.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId);
  Future<List<AttendanceRecord>> getAllAttendanceRecords();
  Future<void> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
  });
  Future<void> toggleOfflineSync();
  SyncStatus getSyncStatus();
}
