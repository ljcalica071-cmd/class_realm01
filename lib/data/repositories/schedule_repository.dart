import 'package:class_realm/models/academic_models.dart';

abstract class ScheduleRepository {
  Future<List<ScheduleModel>> getSchedules({String? section});
  Future<void> addSchedule(ScheduleModel schedule);
  Future<void> updateSchedule(ScheduleModel schedule);
  Future<void> deleteSchedule(String id);
}
