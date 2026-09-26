import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';

abstract class TeacherRepository {
  Future<List<UserModel>> getTeachers();
  Future<void> updateTeacherStatus(String teacherId, AccountStatus newStatus);
  Future<List<LessonPlanModel>> getLessonPlans();
  Future<LessonPlanModel> generateLessonPlan({
    required String topic,
    required String gradeLevel,
    required String subject,
    required String duration,
  });
  Future<List<LearningMaterialModel>> getMaterials({String? section});
}
