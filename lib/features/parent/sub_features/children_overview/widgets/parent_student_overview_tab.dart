import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_schedule_view.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_subject_details_sheet.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ParentStudentOverviewTab extends StatefulWidget {
  final UserModel? linkedStudent;
  final UserModel? teacher;
  final List<UserModel>? allChildren;
  final Function(UserModel)? onSelectChild;
  final List<AttendanceRecord> attendance;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenGrades;
  final Future<void> Function()? onRefresh;

  const ParentStudentOverviewTab({
    super.key,
    required this.linkedStudent,
    this.teacher,
    this.allChildren,
    this.onSelectChild,
    this.attendance = const [],
    this.onOpenAttendance,
    this.onOpenGrades,
    this.onRefresh,
  });

  @override
  State<ParentStudentOverviewTab> createState() =>
      _ParentStudentOverviewTabState();
}

class _ParentStudentOverviewTabState extends State<ParentStudentOverviewTab> {
  List<Map<String, dynamic>> _offerings = const [];
  List<ScheduleModel> _schedules = const [];
  Map<String, Map<int, Map<String, dynamic>>> _termGrades = const {};
  bool _isLoadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _loadSubjectAndScheduleData();
  }

  @override
  void didUpdateWidget(covariant ParentStudentOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.linkedStudent?.id != widget.linkedStudent?.id) {
      _loadSubjectAndScheduleData();
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  Future<void> _loadSubjectAndScheduleData({bool silent = false}) async {
    final studentId = widget.linkedStudent?.id;
    if (studentId == null || studentId.isEmpty) {
      if (mounted) setState(() => _isLoadingSubjects = false);
      return;
    }

    final cacheKey = 'parent_student_overview_data_$studentId';
    if (!silent) {
      final cached = AppDataCache.instance.getCached<Map<String, dynamic>>(
        cacheKey,
        (json) => Map<String, dynamic>.from(json as Map),
      );
      if (cached != null) {
        _offerings = (cached['offerings'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoadingSubjects = false;
      }
    }

    try {
      final client = SupabaseService().client;
      final sec = widget.linkedStudent?.departmentOrSection;

      final results = await Future.wait<dynamic>([
        // 1. Enrolled Subjects
        client
            .from('student_enrollments')
            .select('''
              subject_offerings!inner (
                id,
                ww_weight,
                pt_weight,
                ex_weight,
                terms_taught,
                term_block,
                subjects ( id, subject_name, subject_code, grade_level ),
                sections ( id, section_name, grade_level ),
                teacher_profiles ( teacher_id, first_name, last_name, gender )
              )
            ''')
            .eq('student_id', studentId)
            .ilike('status', 'enrolled'),

        // 2. Schedule
        sec != null && sec.isNotEmpty
            ? SupabaseScheduleRepository.instance.getSchedules(section: sec)
            : Future.value(<ScheduleModel>[]),

        // 3. Term Grades
        client
            .from('term_grades')
            .select(
              'subject_offering_id, term_number, initial_grade, transmuted_grade, remarks, is_finalized',
            )
            .eq('student_id', studentId),
      ]);

      final offeringRows = (results[0] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => _asMap(row['subject_offerings']))
          .where((offering) => offering.isNotEmpty)
          .toList();

      final scheduleRows = results[1] as List<ScheduleModel>;

      final gradesByOffering = <String, Map<int, Map<String, dynamic>>>{};
      for (final row in results[2] as List) {
        final grade = Map<String, dynamic>.from(row as Map);
        final offeringId = grade['subject_offering_id']?.toString();
        final termNumber = (grade['term_number'] as num?)?.toInt();
        if (offeringId == null ||
            termNumber == null ||
            termNumber < 1 ||
            termNumber > 3) {
          continue;
        }
        gradesByOffering.putIfAbsent(
          offeringId,
          () => <int, Map<String, dynamic>>{},
        )[termNumber] = grade;
      }

      if (!mounted) return;
      setState(() {
        _offerings = offeringRows;
        _schedules = scheduleRows;
        _termGrades = gradesByOffering;
        _isLoadingSubjects = false;
      });

      AppDataCache.instance.set(cacheKey, {
        'offerings': offeringRows,
      });
    } catch (e) {
      debugPrint('Error loading parent student overview details: $e');
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      if (widget.onRefresh != null) widget.onRefresh!(),
      _loadSubjectAndScheduleData(silent: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final student = widget.linkedStudent;

    if (student == null) {
      return AppPullToRefresh(
        onRefresh: _handleRefresh,
        child: AppPullToRefresh.scrollableState(
          child: const AppEmptyState(
            icon: Icons.family_restroom_outlined,
            title: 'No Linked Student Found',
            message:
                'Your account has not been connected to a student yet. Please coordinate with the teacher or school admin.',
          ),
        ),
      );
    }

    final presentCount = widget.attendance
        .where((r) => r.status == AttendanceStatus.present)
        .length;
    final lateCount = widget.attendance
        .where((r) => r.status == AttendanceStatus.late)
        .length;
    final absentCount = widget.attendance
        .where((r) => r.status == AttendanceStatus.absent)
        .length;
    final excusedCount = widget.attendance
        .where((r) => r.status == AttendanceStatus.excused)
        .length;

    final totalAccounted = presentCount + lateCount + absentCount;
    final rate = totalAccounted > 0
        ? (((presentCount + lateCount) / totalAccounted) * 100).round()
        : (excusedCount > 0 ? 100 : 0);

    // Compute Overall General Average across finalized term grades
    double totalGrades = 0;
    int gradedSubjectsCount = 0;
    for (final off in _offerings) {
      final offId = off['id']?.toString() ?? '';
      final terms = _termGrades[offId];
      if (terms != null && terms.isNotEmpty) {
        final finalizedGrades = terms.values
            .map((g) => (g['transmuted_grade'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        if (finalizedGrades.isNotEmpty) {
          final avg =
              finalizedGrades.reduce((a, b) => a + b) / finalizedGrades.length;
          totalGrades += avg;
          gradedSubjectsCount++;
        }
      }
    }
    final generalAverage = gradedSubjectsCount > 0
        ? (totalGrades / gradedSubjectsCount).round()
        : null;

    // Resolve today's attendance status
    final today = DateTime.now();
    final todayRecords = widget.attendance.where((r) {
      return r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day;
    }).toList();

    AttendanceRecord? latestToday =
        todayRecords.isNotEmpty ? todayRecords.first : null;

    return AppPullToRefresh(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. SENIOR HIGH SCHOOL HERO CARD ──
            _buildShsStudentHero(theme, isDark, student, latestToday),

            const SizedBox(height: 16),

            // ── 2. SARDO EARLY WARNING ALERT (IF >= 3 ABSENCES) ──
            if (absentCount >= 3)
              _buildAbsenceAlert(theme, isDark, absentCount),

            // ── 3. ATTENDANCE & GWA PULSE METRICS ──
            Row(
              children: [
                _buildStatCard(
                  theme,
                  isDark,
                  'Attendance Rate',
                  '$rate%',
                  AppTheme.catGreen,
                  caption: '$presentCount of $totalAccounted days',
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  theme,
                  isDark,
                  'SSHS GWA',
                  generalAverage != null ? '$generalAverage' : 'Pending',
                  AppTheme.catBlue,
                  caption: generalAverage != null
                      ? (generalAverage >= 75 ? 'Passing' : 'Needs Help')
                      : 'Finalizing',
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  theme,
                  isDark,
                  'Unexcused',
                  '$absentCount',
                  absentCount >= 3 ? AppTheme.catRed : AppTheme.catOrange,
                  caption: absentCount == 0 ? 'Good Standing' : 'Absences',
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── 4. QUICK ACTIONS ROW ──
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionTile(
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.calendar_view_week_rounded,
                    color: AppTheme.catBlue,
                    title: 'Class Schedule',
                    subtitle: 'Weekly timetable',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ParentScheduleView(linkedStudent: student),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionTile(
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.fact_check_rounded,
                    color: AppTheme.catGreen,
                    title: 'Attendance Logs',
                    subtitle: 'Daily records',
                    onTap: widget.onOpenAttendance ?? () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionTile(
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.grade_rounded,
                    color: AppTheme.catTeal,
                    title: 'Report Card',
                    subtitle: '3-Term grades',
                    onTap: widget.onOpenGrades ?? () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ── 5. ENROLLED SUBJECTS SECTION ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ENROLLED SUBJECTS (${_offerings.length})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  'Tap subject for teacher & schedule',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoadingSubjects)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
              )
            else if (_offerings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isDark ? 0.16 : 0.12,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No Enrolled Subjects',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enrolled subjects will be visible once scheduled by the teacher.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._offerings.map((offering) {
                return _buildEnrolledSubjectCard(
                  theme: theme,
                  isDark: isDark,
                  offering: offering,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildShsStudentHero(
    ThemeData theme,
    bool isDark,
    UserModel student,
    AttendanceRecord? latestToday,
  ) {
    final gradeSection =
        student.departmentOrSection?.isNotEmpty == true
            ? student.departmentOrSection!
            : 'Senior High School';

    final lrnDisplay = student.lrn?.isNotEmpty == true
        ? student.lrn!
        : (student.studentId?.isNotEmpty == true ? student.studentId! : 'N/A');

    // Today's status pill properties
    final String todayStatusText;
    final Color todayStatusColor;
    final IconData todayStatusIcon;

    if (latestToday == null) {
      todayStatusText = 'No attendance recorded today';
      todayStatusColor = Colors.white.withValues(alpha: 0.85);
      todayStatusIcon = Icons.schedule_rounded;
    } else {
      switch (latestToday.status) {
        case AttendanceStatus.present:
          final timeStr = latestToday.timeIn.isNotEmpty
              ? ' at ${latestToday.timeIn}'
              : '';
          todayStatusText = 'Present today$timeStr';
          todayStatusColor = const Color(0xFF34D399); // Crisp Emerald
          todayStatusIcon = Icons.check_circle_rounded;
          break;
        case AttendanceStatus.late:
          todayStatusText = 'Marked Late today';
          todayStatusColor = const Color(0xFFFBBF24); // Amber
          todayStatusIcon = Icons.access_time_filled_rounded;
          break;
        case AttendanceStatus.absent:
          todayStatusText = 'Marked Absent today';
          todayStatusColor = const Color(0xFFF87171); // Soft Red
          todayStatusIcon = Icons.cancel_rounded;
          break;
        case AttendanceStatus.excused:
          todayStatusText = 'Excused today';
          todayStatusColor = const Color(0xFF60A5FA); // Soft Blue
          todayStatusIcon = Icons.info_rounded;
          break;
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -24,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        radius: 26,
                        child: Text(
                          student.firstName?.isNotEmpty == true
                              ? student.firstName![0].toUpperCase()
                              : (student.fullName.isNotEmpty
                                  ? student.fullName[0].toUpperCase()
                                  : 'S'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                                  student.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  student.parentGuardianRelationship ?? 'Child',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$gradeSection · LRN: $lrnDisplay',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Today's Live Attendance Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        todayStatusIcon,
                        size: 15,
                        color: todayStatusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        todayStatusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: todayStatusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledSubjectCard({
    required ThemeData theme,
    required bool isDark,
    required Map<String, dynamic> offering,
  }) {
    final offId = offering['id']?.toString() ?? '';
    final subjectsMap = _asMap(offering['subjects']);
    final subjectName = subjectsMap['subject_name']?.toString() ?? 'Subject';
    final subjectCode = subjectsMap['subject_code']?.toString() ?? '';

    final teacherMap = _asMap(offering['teacher_profiles']);
    final teacherFirstName = teacherMap['first_name']?.toString() ?? '';
    final teacherLastName = teacherMap['last_name']?.toString() ?? '';
    final teacherGender = teacherMap['gender']?.toString() ?? '';
    final teacherFullName = [teacherFirstName, teacherLastName]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final teacherTitle =
        teacherGender.toLowerCase() == 'female' ? 'Ms.' : 'Mr.';
    final teacherDisplayName = teacherFullName.isNotEmpty
        ? '$teacherTitle $teacherFullName'
        : 'Assigned Teacher';

    final termsTaught = (offering['terms_taught'] as num?)?.toInt() ?? 3;
    final termBlock = offering['term_block']?.toString();

    // Matching schedules
    ScheduleModel? matchingSchedule;
    for (final s in _schedules) {
      final sSub = s.subject.toLowerCase();
      if ((subjectCode.isNotEmpty && sSub.contains(subjectCode.toLowerCase())) ||
          sSub.contains(subjectName.toLowerCase()) ||
          subjectName.toLowerCase().contains(sSub)) {
        matchingSchedule = s;
        break;
      }
    }

    final hasSchedule = matchingSchedule != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.16 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ParentSubjectDetailsSheet.show(
              context,
              offering: offering,
              schedules: _schedules,
              termGrades: _termGrades[offId] ?? const {},
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (subjectCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subjectCode,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              termsTaught == 1
                                  ? '1 Term${termBlock != null ? " ($termBlock)" : ""}'
                                  : '3 Terms',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSchedule
                            ? '${matchingSchedule.dayOfWeek} · ${matchingSchedule.startTime} · $teacherDisplayName'
                            : 'Teacher: $teacherDisplayName',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    bool isDark,
    String label,
    String value,
    Color color, {
    String? caption,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.32 : 0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? 0.16 : 0.1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbsenceAlert(ThemeData theme, bool isDark, int absentCount) {
    final Color bannerColor;
    final Color borderColor;
    final Color textColor;
    final String title;
    final String subtitle;
    final IconData icon;

    if (absentCount >= 10) {
      bannerColor = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFDC2626);
      textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      icon = Icons.error_rounded;
      title = 'Critical Notice: $absentCount Absences (SARDO Policy)';
      subtitle = 'Urgent conference with class adviser required.';
    } else if (absentCount >= 5) {
      bannerColor = isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFEA580C);
      textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412);
      icon = Icons.warning_amber_rounded;
      title = 'Attendance Alert: $absentCount Recorded Absences';
      subtitle = 'Intervention required. Coordinate with class adviser.';
    } else {
      bannerColor = isDark ? const Color(0xFF422006) : const Color(0xFFFEFCE8);
      borderColor = const Color(0xFFCA8A04);
      textColor = isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E);
      icon = Icons.info_outline_rounded;
      title = 'Early Warning: $absentCount Recorded Absences';
      subtitle =
          'Please ensure regular attendance to maintain academic standing.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
