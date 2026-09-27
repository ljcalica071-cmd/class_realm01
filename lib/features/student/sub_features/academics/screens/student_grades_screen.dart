import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_academic_performance_screen.dart';

class StudentGradesScreen extends StatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  String _selectedTerm = '2026-2027 : 1st Trimester';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentId = MockDatabase.instance.currentUser?.studentId ?? 'A01';
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );

    final submissions = MockDatabase.instance.submissionsForStudent(studentId);
    final assessmentResults = MockDatabase.instance.assessmentResults
        .where((r) => r.studentId == studentId)
        .toList();

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Grades'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: 'Academic Performance',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const StudentAcademicPerformanceScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Grades',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Student: ${student.fullName} (${student.departmentOrSection ?? "Section A"})',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Trimester Dropdown Selector (3 Trimesters)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTerm,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.black87,
                        ),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '2026-2027 : 1st Trimester',
                            child: Text('2026-2027 : 1st Trimester'),
                          ),
                          DropdownMenuItem(
                            value: '2026-2027 : 2nd Trimester',
                            child: Text('2026-2027 : 2nd Trimester'),
                          ),
                          DropdownMenuItem(
                            value: '2026-2027 : 3rd Trimester',
                            child: Text('2026-2027 : 3rd Trimester'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTerm = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Trimester Grades Table
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Grade 11 SHS — $_selectedTerm',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 28,
                      headingRowHeight: 44,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 52,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Course',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Units',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Prelim',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Midterm',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Finals',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: _getRowsForTerm(_selectedTerm),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Component Breakdown (Written Works, Performance Tasks, Exams)
            Text(
              'Component Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            _buildGradeSection(
              context,
              'Written Works (WW)',
              MockDatabase.instance.activities
                  .where((a) => !a.isRequirement)
                  .toList(),
              submissions,
            ),
            const SizedBox(height: 12),
            _buildGradeSection(
              context,
              'Performance Task (PT)',
              MockDatabase.instance.activities
                  .where((a) => a.isRequirement)
                  .toList(),
              submissions,
            ),
            const SizedBox(height: 12),
            _buildAssessmentSection(
              context,
              'Examinations (EX)',
              MockDatabase.instance.quizzesAndExams
                  .where((q) => q.id != 'WW3' && q.title != 'Functions Quiz')
                  .toList(),
              assessmentResults,
            ),
            const SizedBox(height: 24),

            // 4. Jump Button to Academic Performance
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.school_outlined),
                label: const Text(
                  'View Full Academic Performance Records',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentAcademicPerformanceScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataRow> _getRowsForTerm(String term) {
    if (term.contains('2nd')) {
      return [
        _buildGradeRow(
          code: 'IT 3217',
          title: 'Information Assurance 2',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
        _buildGradeRow(
          code: 'IT 3218',
          title: 'Platform Technologies',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
        _buildGradeRow(
          code: 'IT 3219',
          title: 'Capstone Project 1',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
      ];
    } else if (term.contains('3rd')) {
      return [
        _buildGradeRow(
          code: 'SD 3203',
          title: 'Software Engineering 2',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
        _buildGradeRow(
          code: 'SD 3204',
          title: 'IT Project Management',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
        _buildGradeRow(
          code: 'PE 1101',
          title: 'Physical Education',
          units: '2',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
      ];
    } else {
      return [
        _buildGradeRow(
          code: 'CC 3105',
          title: 'General Mathematics',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
        _buildGradeRow(
          code: 'IT 3114',
          title: 'Earth & Life Science',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
        _buildGradeRow(
          code: 'IT 3115',
          title: 'Oral Communication',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
        _buildGradeRow(
          code: 'CS 1100',
          title: 'Empowerment Tech',
          units: '3',
          prelim: '—',
          midterm: '—',
          finals: '—',
        ),
      ];
    }
  }

  static DataRow _buildGradeRow({
    required String code,
    required String title,
    required String units,
    required String prelim,
    required String midterm,
    required String finals,
  }) {
    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(units)),
        DataCell(Text(prelim)),
        DataCell(Text(midterm)),
        DataCell(
          Text(finals, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
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
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
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
              orElse: () => StudentSubmission(
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
                  color: isGraded
                      ? AppTheme.catGreen
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
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
              orElse: () => AssessmentResultModel(
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
                  color: isReleased
                      ? AppTheme.catGreen
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
