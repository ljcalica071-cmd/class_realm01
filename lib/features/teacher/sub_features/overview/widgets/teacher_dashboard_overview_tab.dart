import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/teacher/shared/widgets/teacher_top_summary_card.dart';

import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class TeacherDashboardOverviewTab extends StatefulWidget {
  final List<UserModel> activeStudents;
  final List<QuizOrExamModel> quizzesAndExams;
  final ValueChanged<int> onNavigateTo;
  final VoidCallback onCreateChooser;

  const TeacherDashboardOverviewTab({
    super.key,
    required this.activeStudents,
    required this.quizzesAndExams,
    required this.onNavigateTo,
    required this.onCreateChooser,
  });

  @override
  State<TeacherDashboardOverviewTab> createState() =>
      _TeacherDashboardOverviewTabState();
}

class _TeacherDashboardOverviewTabState
    extends State<TeacherDashboardOverviewTab> {
  int totalSubjects = 0;
  int totalSections = 0;
  int totalStudents = 0;
  bool isLoadingStats = true;
  List<ScheduleModel> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          isLoadingStats = false;
        });
      }
      return;
    }

    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        currentUser.id,
      );
      final uniqueSubjects = subjects
          .map((e) => e['subject_name'])
          .toSet()
          .length;
      final uniqueSections = subjects
          .map((e) => '${e['subject_name']}-${e['section_name']}')
          .toSet()
          .length;

      final students = await SupabaseStudentRepository().getStudentsForTeacher(
        currentUser.id,
      );
      final uniqueStudents = students
          .map((student) => student.id)
          .toSet()
          .length;
      final schedules = await SupabaseScheduleRepository.instance.getSchedules(
        teacherId: currentUser.id,
      );

      if (mounted) {
        setState(() {
          totalSubjects = uniqueSubjects;
          totalSections = uniqueSections;
          totalStudents = uniqueStudents;
          _schedules = schedules;
          isLoadingStats = false;
        });
      }
    } catch (error) {
      debugPrint('Dashboard stats notice: $error');
      if (mounted) {
        setState(() {
          totalSubjects = 0;
          totalSections = 0;
          totalStudents = 0;
          _schedules = [];
          isLoadingStats = false;
        });
      }
    }
  }

  Widget _buildClassItem(
    BuildContext context, {
    required String subject,
    required String sectionAndRoom,
    required String time,
    required bool isDone,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Inherits 60% for contrast inside 30% card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.teal.withValues(alpha: 0.1)
                  : Colors.amber.withValues(alpha: 0.1),
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

  Widget _buildQuickActionTile(
    BuildContext context, {
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
    final currentUser = AuthRepository.instance.currentUser;
    final displayName = currentUser?.fullName ?? 'Teacher';
    final nameTitle = currentUser?.honorific.isNotEmpty == true
        ? currentUser!.honorific
        : ((currentUser?.gender?.trim().toLowerCase() == 'female' ||
                currentUser?.gender?.trim().toLowerCase() == 'f')
            ? "Ma'am"
            : "Sir");

    // Loading state for the top cards
    final mainValueSubjects = isLoadingStats ? '-' : '$totalSubjects';
    final mainValueSections = isLoadingStats ? '-' : '$totalSections';
    final mainValueStudents = isLoadingStats ? '-' : '$totalStudents';
    final now = DateTime.now();
    final todayName = ScheduleModel.dayFromIndex(now.weekday);
    final nowInMinutes = now.hour * 60 + now.minute;
    final sortedSchedules = List<ScheduleModel>.from(_schedules)
      ..sort((a, b) {
        final dayCompare = a.dayOfWeekIndex.compareTo(b.dayOfWeekIndex);
        return dayCompare != 0
            ? dayCompare
            : a.startMinutes.compareTo(b.startMinutes);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $nameTitle $displayName!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Here's your academic summary for Eduardo Barretto Senior Integrated School today.",
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),

          // 3 TOP STAT CARDS
          if (MediaQuery.of(context).size.width < 900)
            Column(
              children: [
                TeacherTopSummaryCard(
                  title: "Total Subjects",
                  mainValue: mainValueSubjects,
                  subText: 'Subjects handled',
                  baseColor: Colors.teal,
                  icon: LucideIcons.bookOpen,
                ),
                const SizedBox(height: 16),
                TeacherTopSummaryCard(
                  title: 'Total Sections',
                  mainValue: mainValueSections,
                  subText: 'Sections handled',
                  baseColor: Colors.amber.shade700,
                  icon: LucideIcons.users,
                ),
                const SizedBox(height: 16),
                TeacherTopSummaryCard(
                  title: 'Total Students',
                  mainValue: mainValueStudents,
                  subText: 'Active students',
                  baseColor: theme.colorScheme.primary,
                  icon: LucideIcons.graduationCap,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TeacherTopSummaryCard(
                    title: "Total Subjects",
                    mainValue: mainValueSubjects,
                    subText: 'Subjects handled',
                    baseColor: Colors.teal,
                    icon: LucideIcons.bookOpen,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TeacherTopSummaryCard(
                    title: 'Total Sections',
                    mainValue: mainValueSections,
                    subText: 'Sections handled',
                    baseColor: Colors.amber.shade700,
                    icon: LucideIcons.users,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TeacherTopSummaryCard(
                    title: 'Total Students',
                    mainValue: mainValueStudents,
                    subText: 'Active students',
                    baseColor: theme.colorScheme.primary,
                    icon: LucideIcons.graduationCap,
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
                              'My Class Schedule',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            TextButton(
                              onPressed: () => widget.onNavigateTo(14),
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
                        if (isLoadingStats)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: LoadingAnimationWidget.staggeredDotsWave(
                                color: theme.colorScheme.primary,
                                size: 36,
                              ),
                            ),
                          )
                        else if (sortedSchedules.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.calendarX2,
                                      size: 32,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No classes scheduled yet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Configure your subjects in Classroom Setup and set up your weekly schedule.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...sortedSchedules.map(
                            (schedule) => Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _buildClassItem(
                                context,
                                subject: schedule.subject,
                                sectionAndRoom: [
                                  schedule.dayOfWeek,
                                  'Section ${schedule.section}',
                                  if (schedule.room.trim().isNotEmpty)
                                    'Room ${schedule.room}',
                                ].join(' • '),
                                time:
                                    '${schedule.startTime} - ${schedule.endTime}',
                                isDone:
                                    schedule.dayOfWeek == todayName &&
                                    nowInMinutes >= schedule.endMinutes,
                              ),
                            ),
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
                          onTap: () => widget.onNavigateTo(5),
                        ),
                        Divider(
                          height: 1,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                        _buildQuickActionTile(
                          context,
                          title: 'Create Classwork',
                          icon: LucideIcons.fileText,
                          onTap: widget.onCreateChooser,
                        ),
                        Divider(
                          height: 1,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                        _buildQuickActionTile(
                          context,
                          title: 'View Schedule',
                          icon: LucideIcons.calendarDays,
                          onTap: () => widget.onNavigateTo(14),
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
