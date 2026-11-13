import 'package:class_realm/models/academic_models.dart';

abstract class ScheduleRepository {
  Future<List<ScheduleModel>> getSchedules({
    String? section,
    String? teacherId,
    int? gradeLevel,
  });
  Future<List<ScheduleModel>> getSchedulesForStudent(
    String studentId, {
    List<String>? offeringIds,
  });
  Future<void> addSchedule(ScheduleModel schedule);
  Future<void> updateSchedule(ScheduleModel schedule);
  Future<void> deleteSchedule(String id);
}
