import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_grades_screen.dart';

class StudentAcademicPerformanceScreen extends StatelessWidget {
  const StudentAcademicPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Academic Performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.grade_outlined),
            tooltip: 'My Grades',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StudentGradesScreen()),
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
            // Header Banner
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
                          Icons.school,
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
                              'My Academic Performance',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Student: ${student.fullName}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Senior High School — General Academic Strand',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Trimester Curriculum A.Y. 2026–2027',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 1st Trimester Table
            _buildTrimesterTable(
              context,
              title: 'Grade 11 — 1st Trimester',
              termText: '1st Trimester A.Y. 2026–2027',
              isDark: isDark,
              rows: [
                _buildCourseRow(
                  code: 'CC 3105',
                  title: 'General Mathematics',
                  units: '3',
                  statusText: '—',
                  prereq: '<none>',
                ),
                _buildCourseRow(
                  code: 'IT 3114',
                  title: 'Earth & Life Science',
                  units: '3',
                  statusText: '—',
                  prereq: '<none>',
                ),
                _buildCourseRow(
                  code: 'IT 3115',
                  title: 'Oral Communication',
                  units: '3',
                  statusText: '—',
                  prereq: '<none>',
                ),
                _buildCourseRow(
                  code: 'CS 1100',
                  title: 'Empowerment Technologies',
                  units: '3',
                  statusText: '—',
                  prereq: '<none>',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2nd Trimester Table
            _buildTrimesterTable(
              context,
              title: 'Grade 11 — 2nd Trimester',
              termText: '2nd Trimester A.Y. 2026–2027',
              isDark: isDark,
              rows: [
                _buildCourseRow(
                  code: 'IT 3217',
                  title: 'Information Assurance and Security 2',
                  units: '3',
                  statusText: '—',
                  prereq: 'IT 3114',
                ),
                _buildCourseRow(
                  code: 'IT 3218',
                  title: 'Platform Technologies',
                  units: '3',
                  statusText: '—',
                  prereq: 'IT 2102',
                ),
                _buildCourseRow(
                  code: 'IT 3219',
                  title: 'Capstone Project and Research 1',
                  units: '3',
                  statusText: '—',
                  prereq: '3rd Year Standing',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3rd Trimester Table
            _buildTrimesterTable(
              context,
              title: 'Grade 11 — 3rd Trimester',
              termText: '3rd Trimester A.Y. 2026–2027',
              isDark: isDark,
              rows: [
                _buildCourseRow(
                  code: 'SD 3203',
                  title: 'Software Engineering 2',
                  units: '3',
                  statusText: '—',
                  prereq: '3rd Year Standing',
                ),
                _buildCourseRow(
                  code: 'SD 3204',
                  title: 'IT Project Management',
                  units: '3',
                  statusText: '—',
                  prereq: '3rd Year Standing',
                ),
                _buildCourseRow(
                  code: 'PE 1101',
                  title: 'Physical Education & Health',
                  units: '2',
                  statusText: '—',
                  prereq: '<none>',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Jump button to My Grades
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
                icon: const Icon(Icons.grade_outlined),
                label: const Text(
                  'Switch to My Grades',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentGradesScreen(),
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

  static Widget _buildTrimesterTable(
    BuildContext context, {
    required String title,
    required String termText,
    required bool isDark,
    required List<DataRow> rows,
  }) {
    final theme = Theme.of(context);
    return Container(
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
          // Table Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  termText,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Data Table
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
                    'Grade/Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Prerequisites',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: rows,
            ),
          ),
        ],
      ),
    );
  }

  static DataRow _buildCourseRow({
    required String code,
    required String title,
    required String units,
    required String statusText,
    required String prereq,
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
        DataCell(
          Text(
            statusText,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        DataCell(
          Text(
            prereq,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
