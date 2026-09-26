import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/status_badge.dart';

class StudentGradesScreen extends StatelessWidget {
  const StudentGradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
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
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGradeSection(
                      context,
                      'Written Works (WW)',
                      subjectActivities.where((a) => !a.isRequirement).toList(),
                      submissions,
                    ),
                    const SizedBox(height: 16),
                    _buildGradeSection(
                      context,
                      'Performance Task (PT)',
                      subjectActivities.where((a) => a.isRequirement).toList(),
                      submissions,
                    ),
                    const SizedBox(height: 16),
                    _buildAssessmentSection(
                      context,
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
    BuildContext context,
    String title,
    List<ActivityModel> items,
    List<StudentSubmission> submissions,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
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
                  color: isGraded ? AppTheme.catGreen : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAssessmentSection(
    BuildContext context,
    String title,
    List<QuizOrExamModel> items,
    List<AssessmentResultModel> results,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
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
                      isReleased ? AppTheme.catGreen : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
