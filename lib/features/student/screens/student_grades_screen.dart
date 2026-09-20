import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/academic_models.dart';
import '../../../widgets/common/status_badge.dart';

class StudentGradesScreen extends StatelessWidget {
  const StudentGradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studentId = MockDatabase.instance.currentUser?.studentId ?? 'A01';

    final submissions = MockDatabase.instance.submissionsForStudent(studentId);
    final assessmentResults = MockDatabase.instance.assessmentResults
        .where((r) => r.studentId == studentId)
        .toList();

    final quarterlyGrade = MockDatabase.instance.quarterlyGradeFor(studentId);

    // Grouping logic (since we only have General Mathematics for now, it's simple)
    // But we'll structure it to support multiple subjects in theory.
    final subjects = {'General Mathematics'};

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Grades'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'ESTIMATED QUARTERLY GRADE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quarterlyGrade.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const StatusBadge(
                      text: 'STANDING: EXCELLENT',
                      backgroundColor: Colors.white24,
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ...subjects.map((subject) {
                final subjectActivities =
                    MockDatabase.instance.activities
                        .where((a) => a.subject == subject)
                        .toList();
                final subjectQuizzes =
                    MockDatabase.instance.quizzesAndExams
                        .where((q) => q.subject == subject && q.id != 'WW3')
                        .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGradeSection(
                      'Written Works (WW)',
                      subjectActivities.where((a) => !a.isRequirement).toList(),
                      submissions,
                    ),
                    const SizedBox(height: 16),
                    _buildGradeSection(
                      'Performance Task (PT)',
                      subjectActivities.where((a) => a.isRequirement).toList(),
                      submissions,
                    ),
                    const SizedBox(height: 16),
                    _buildAssessmentSection(
                      'Examinations (EX)',
                      subjectQuizzes,
                      assessmentResults,
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeSection(
    String title,
    List<ActivityModel> items,
    List<StudentSubmission> submissions,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) {
            final submission = submissions.firstWhere(
              (s) => s.activityOrExamId == item.id,
              orElse:
                  () => StudentSubmission(
                    id: '',
                    activityOrExamId: '',
                    studentId: '',
                    studentName: '',
                    submittedAt: DateTime.now(),
                    maxScore: 0,
                  ),
            );

            final isGraded = submission.status == ActivityStatus.graded;

            return ListTile(
              title: Text(item.title, style: const TextStyle(fontSize: 14)),
              trailing: Text(
                isGraded
                    ? '${submission.score?.toInt() ?? 0} / ${item.maxScore.toInt()}'
                    : submission.id.isNotEmpty
                    ? 'Submitted'
                    : 'Pending',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isGraded ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAssessmentSection(
    String title,
    List<QuizOrExamModel> items,
    List<AssessmentResultModel> results,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) {
            final result = results.firstWhere(
              (r) => r.assessmentId == item.id,
              orElse:
                  () => AssessmentResultModel(
                    id: '',
                    assessmentId: '',
                    studentId: '',
                    studentName: '',
                    submittedAt: DateTime.now(),
                    durationTakenMinutes: 0,
                    answers: {},
                    scoreEarned: 0,
                    totalPoints: 0,
                  ),
            );

            final isRecorded = result.id.isNotEmpty;
            final isReleased = item.resultsReleased || result.isReleased;

            return ListTile(
              title: Text(item.title, style: const TextStyle(fontSize: 14)),
              trailing: Text(
                isReleased
                    ? '${result.scoreEarned.toInt()} / ${result.totalPoints.toInt()}'
                    : isRecorded
                    ? 'Submitted'
                    : 'Scheduled',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isReleased ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
