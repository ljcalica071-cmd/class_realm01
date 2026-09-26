import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/teacher/shared/widgets/teacher_top_summary_card.dart';

class TeacherDashboardOverviewTab extends StatelessWidget {
  final List<UserModel> activeStudents;
  final List<QuizOrExamModel> quizzesAndExams;
  final List<ScheduleModel> schedules;
  final ValueChanged<int> onNavigateTo;
  final VoidCallback onCreateChooser;

  const TeacherDashboardOverviewTab({
    super.key,
    required this.activeStudents,
    required this.quizzesAndExams,
    required this.schedules,
    required this.onNavigateTo,
    required this.onCreateChooser,
  });

  Widget _buildClassItem(BuildContext context, {
    required String subject,
    required String sectionAndRoom,
    required String time,
    required bool isDone,
    required String attendanceStats,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Inherits 60% for contrast inside 30% card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDone ? Colors.teal.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDone ? LucideIcons.checkCircle : LucideIcons.clock,
              color: isDone ? Colors.teal : Colors.amber.shade800,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sectionAndRoom,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attendanceStats,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quizzesCount = quizzesAndExams.where((q) => !q.isExam).length;
    final examsCount = quizzesAndExams.where((q) => q.isExam).length;
    final totalAssessments = quizzesAndExams.length;
    const todaysClassesCount = 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, Ma\'am Karen!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Here's your academic summary for Eduardo Barretto Senior Integrated School today.",
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // 3 TOP STAT CARDS
          Row(
            children: [
              Expanded(
                child: TeacherTopSummaryCard(
                  title: "Today's Classes",
                  mainValue: '$todaysClassesCount',
                  subText: '↑ 2 completed, 2 remaining',
                  subColor: Colors.teal,
                  icon: LucideIcons.bookOpen,
                  iconColor: Colors.teal,
                  iconBgColor: Colors.teal.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: TeacherTopSummaryCard(
                  title: 'Students',
                  mainValue: '${activeStudents.length}',
                  subText: 'Across 2 sections (Grade 11)',
                  subColor: theme.colorScheme.primary,
                  icon: LucideIcons.graduationCap,
                  iconColor: theme.colorScheme.primary,
                  iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: TeacherTopSummaryCard(
                  title: 'Upcoming Assessments',
                  mainValue: '$totalAssessments',
                  subText:
                      '$quizzesCount Quizzes • $examsCount Periodical Exams',
                  subColor: theme.colorScheme.primary,
                  icon: LucideIcons.fileQuestion,
                  iconColor: Colors.amber.shade800,
                  iconBgColor: Colors.amber.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // LOWER SECTION: Today's Classes & Quick Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's Classes",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            TextButton(
                              onPressed: () => onNavigateTo(14),
                              child: Text(
                                'View All Schedule',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildClassItem(
                          context,
                          subject: 'General Mathematics',
                          sectionAndRoom: 'Grade 11 - Section A • Room 304',
                          time: '07:30 AM - 09:00 AM',
                          isDone: true,
                          attendanceStats: 'Attendance: 4 / 5 present',
                        ),
                        const SizedBox(height: 12),
                        _buildClassItem(
                          context,
                          subject: 'General Mathematics',
                          sectionAndRoom: 'Grade 11 - Section B • Room 305',
                          time: '09:15 AM - 10:45 AM',
                          isDone: true,
                          attendanceStats: 'Attendance: 5 / 5 present',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right: Quick Actions Menu
              Expanded(
                flex: 4,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActionTile(
                          context,
                          title: 'Record Attendance',
                          icon: LucideIcons.checkSquare,
                          onTap: () => onNavigateTo(5),
                        ),
                        Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
                        _buildQuickActionTile(
                          context,
                          title: 'Create Classwork',
                          icon: LucideIcons.fileText,
                          onTap: onCreateChooser,
                        ),
                        Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
                        _buildQuickActionTile(
                          context,
                          title: 'Add Assessment',
                          icon: LucideIcons.filePlus,
                          onTap: onCreateChooser,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
