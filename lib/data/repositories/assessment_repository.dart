import 'package:class_realm/models/academic_models.dart';

abstract class AssessmentRepository {
  Future<List<ActivityModel>> getActivities({String? section});
  Future<void> addActivity(ActivityModel activity);
  Future<void> deleteActivity(String id);
  Future<List<QuizOrExamModel>> getQuizzesAndExams({String? section});
  Future<void> addQuizOrExam(QuizOrExamModel item);
  Future<void> deleteQuizOrExam(String id);
  Future<List<StudentSubmission>> getSubmissionsForActivity(String activityId);
  Future<List<StudentSubmission>> getSubmissionsForStudent(String studentId);
  Future<StudentSubmission?> getSubmission(String activityId, String studentId);
  Future<void> submitActivity({
    required String activityId,
    required String studentId,
    required String studentName,
    required String fileName,
  });
  Future<void> scoreSubmission({
    required String submissionId,
    required double score,
    required String feedback,
  });
  Future<List<AssessmentResultModel>> getAssessmentResults({
    String? assessmentId,
    String? studentId,
  });
  Future<AssessmentResultModel?> getAssessmentResult(
    String assessmentId,
    String studentId,
  );
  Future<double> getCategoryAverage(String studentId, String category);
  Future<double> getQuarterlyGrade(String studentId);
}
