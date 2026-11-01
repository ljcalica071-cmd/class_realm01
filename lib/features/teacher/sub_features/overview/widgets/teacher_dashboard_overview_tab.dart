import 'dart:async';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/teacher/shared/widgets/teacher_top_summary_card.dart';

import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

enum _ScheduleSessionStatus {
  upcoming,
  ongoing,
  completed,
}

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
  Timer? _autoClockTimer;

  @override
  void initState() {
    super.initState();
    _hydrateOverviewStats();
    _loadDashboardStats();
    _autoClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _autoClockTimer?.cancel();
    super.dispose();
  }

  void _hydrateOverviewStats() {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return;
    final cachedSubjects = AppDataCache.instance.getCached<List<Map<String, dynamic>>>(
      'teacher_subjects_${currentUser.id}_2026-2027_false',
      (json) => (json as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    final cachedStudents = AppDataCache.instance.getCached<List<UserModel>>(
      'teacher_students_${currentUser.id}_all_false',
      (json) => (json as List).map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
    if (cachedSubjects != null || cachedStudents != null) {
      if (cachedSubjects != null) {
        totalSubjects = cachedSubjects.map((e) => e['subject_name']).toSet().length;
        totalSections = cachedSubjects.map((e) => '${e['subject_name']}-${e['section_name']}').toSet().length;
      }
      if (cachedStudents != null) {
        totalStudents = cachedStudents.map((s) => s.id).toSet().length;
      } else if (widget.activeStudents.isNotEmpty) {
        totalStudents = widget.activeStudents.length;
      }
      isLoadingStats = false;
    }
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
    required _ScheduleSessionStatus status,
  }) {
    final theme = Theme.of(context);

    final Color iconBg;
    final Color iconFg;
    final IconData statusIcon;
    final String statusLabel;
    final Color badgeBg;
    final Color badgeFg;
    final Border border;

    switch (status) {
      case _ScheduleSessionStatus.upcoming:
        iconBg = Colors.amber.withValues(alpha: 0.12);
        iconFg = Colors.amber.shade800;
        statusIcon = LucideIcons.clock;
        statusLabel = 'Upcoming';
        badgeBg = Colors.amber.withValues(alpha: 0.1);
        badgeFg = Colors.amber.shade800;
        border = Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        );
        break;
      case _ScheduleSessionStatus.ongoing:
        iconBg = Colors.teal.withValues(alpha: 0.16);
        iconFg = Colors.teal.shade700;
        statusIcon = LucideIcons.presentation;
        statusLabel = 'In Session';
        badgeBg = Colors.teal.withValues(alpha: 0.15);
        badgeFg = Colors.teal.shade800;
        border = Border.all(
          color: Colors.teal.withValues(alpha: 0.45),
          width: 1.5,
        );
        break;
      case _ScheduleSessionStatus.completed:
        iconBg = theme.colorScheme.onSurface.withValues(alpha: 0.06);
        iconFg = theme.colorScheme.onSurface.withValues(alpha: 0.45);
        statusIcon = LucideIcons.checkCheck;
        statusLabel = 'Done';
        badgeBg = theme.colorScheme.onSurface.withValues(alpha: 0.06);
        badgeFg = theme.colorScheme.onSurface.withValues(alpha: 0.5);
        border = Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        );
        break;
    }

    final isMuted = status == _ScheduleSessionStatus.completed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status == _ScheduleSessionStatus.ongoing
            ? theme.colorScheme.primary.withValues(alpha: 0.03)
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              statusIcon,
              color: iconFg,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isMuted
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  sectionAndRoom,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isMuted ? 0.45 : 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(
                alpha: isMuted ? 0.45 : 0.65,
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
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
    final todayIndex = now.weekday;
    final todayName = ScheduleModel.dayFromIndex(todayIndex);
    final nowInMinutes = now.hour * 60 + now.minute;

    // Filter strictly for classes scheduled today
    final todaySchedules = _schedules.where((s) {
      return s.dayOfWeekIndex == todayIndex ||
          s.dayOfWeek.trim().toLowerCase() == todayName.toLowerCase();
    }).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final todayScheduleTitle =
        'My Classes Today';

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

          // 3 TOP STAT CARDS (Skeleton Shimmer while loading)
          if (isLoadingStats)
            if (MediaQuery.of(context).size.width < 900)
              Column(
                children: const [
                  ShimmerTeacherStatCard(),
                  SizedBox(height: 16),
                  ShimmerTeacherStatCard(),
                  SizedBox(height: 16),
                  ShimmerTeacherStatCard(),
                ],
              )
            else
              Row(
                children: const [
                  Expanded(child: ShimmerTeacherStatCard()),
                  SizedBox(width: 20),
                  Expanded(child: ShimmerTeacherStatCard()),
                  SizedBox(width: 20),
                  Expanded(child: ShimmerTeacherStatCard()),
                ],
              )
          else if (MediaQuery.of(context).size.width < 900)
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
                              todayScheduleTitle,
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: ShimmerLoading(
                              child: Column(
                                children: List.generate(
                                  3,
                                  (_) => Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: theme.scaffoldBackgroundColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                        ),
                                      ),
                                      child: Row(
                                        children: const [
                                          ShimmerBox(width: 36, height: 36, borderRadius: 10),
                                          SizedBox(width: 14),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ShimmerBox(width: 160, height: 14, borderRadius: 4),
                                              SizedBox(height: 6),
                                              ShimmerBox(width: 110, height: 12, borderRadius: 4),
                                            ],
                                          ),
                                          Spacer(),
                                          ShimmerBox(width: 80, height: 14, borderRadius: 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (todaySchedules.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.calendarCheck2,
                                      size: 32,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No classes scheduled for today',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You have no teaching sessions scheduled for $todayName. Check "View All Schedule" to see your weekly timetable.',
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
                          ...todaySchedules.map((schedule) {
                            final _ScheduleSessionStatus status;
                            if (nowInMinutes < schedule.startMinutes) {
                              status = _ScheduleSessionStatus.upcoming;
                            } else if (nowInMinutes <= schedule.endMinutes) {
                              status = _ScheduleSessionStatus.ongoing;
                            } else {
                              status = _ScheduleSessionStatus.completed;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _buildClassItem(
                                context,
                                subject: schedule.subject,
                                sectionAndRoom: [
                                  schedule.section.toLowerCase().startsWith('section') ? schedule.section : 'Section ${schedule.section}',
                                  if (schedule.room.trim().isNotEmpty)
                                    'Room ${schedule.room}',
                                ].join(' • '),
                                time: '${schedule.startTime} - ${schedule.endTime}',
                                status: status,
                              ),
                            );
                          }),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Icon(
                              LucideIcons.sparkles,
                              size: 16,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.25,
                          children: [
                            _buildQuickActionCard(
                              context,
                              title: 'Attendance',
                              subtitle: 'RFID & Roster',
                              icon: LucideIcons.checkSquare,
                              accentColor: Colors.teal,
                              onTap: () => widget.onNavigateTo(5),
                            ),
                            _buildQuickActionCard(
                              context,
                              title: 'Create',
                              subtitle: 'WW, PT, Exam',
                              icon: LucideIcons.filePlus2,
                              accentColor: theme.colorScheme.primary,
                              onTap: widget.onCreateChooser,
                            ),
                            _buildQuickActionCard(
                              context,
                              title: 'Gradebook',
                              subtitle: 'DepEd Grades',
                              icon: LucideIcons.bookOpenCheck,
                              accentColor: Colors.deepPurple,
                              onTap: () => widget.onNavigateTo(18),
                            ),
                            _buildQuickActionCard(
                              context,
                              title: 'Schedule',
                              subtitle: 'Timetable',
                              icon: LucideIcons.calendarDays,
                              accentColor: Colors.amber.shade800,
                              onTap: () => widget.onNavigateTo(14),
                            ),
                          ],
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
