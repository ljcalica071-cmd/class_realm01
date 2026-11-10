import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/utils/deped_grading_engine.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_subject_details_sheet.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ParentStudentOverviewTab extends StatefulWidget {
  final UserModel? linkedStudent;
  final UserModel? teacher;
  final List<UserModel>? allChildren;
  final Function(UserModel)? onSelectChild;
  final VoidCallback? onSwitchChildTap;
  final List<AttendanceRecord> attendance;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenGrades;
  final VoidCallback? onOpenTeachers;
  final Future<void> Function()? onRefresh;

  const ParentStudentOverviewTab({
    super.key,
    required this.linkedStudent,
    this.teacher,
    this.allChildren,
    this.onSelectChild,
    this.onSwitchChildTap,
    this.attendance = const [],
    this.onOpenAttendance,
    this.onOpenSchedule,
    this.onOpenGrades,
    this.onOpenTeachers,
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

  static List<int> _activeTerms(int termsTaught, String? termBlock) {
    try {
      return DepEdSubjectCatalog.getActiveTermsForBlock(
        termsTaught.clamp(1, 3),
        termBlock ?? '1ST, 2ND, 3RD',
      );
    } on ArgumentError {
      return switch (termsTaught) {
        1 => const [1],
        2 => const [1, 2],
        _ => const [1, 2, 3],
      };
    }
  }

  static int? _encodedTermGrade(Map<String, dynamic>? row) {
    if (row == null) return null;
    final raw = (row['transmuted_grade'] as num?)?.toInt();
    if (raw == null || raw <= 0) return null;
    final isFinalized = row['is_finalized'] == true;
    final remarks = (row['remarks']?.toString() ?? '').trim().toLowerCase();
    if (!isFinalized && remarks == 'incomplete') return null;
    return raw;
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
        // 1. Enrolled Subjects with Teacher Public Details
        SupabaseParentRepository().getEnrolledOfferingsWithTeachersForStudent(
          studentId,
        ),

        // 2. Schedule (directly from student's enrolled offerings + section fallback)
        SupabaseParentRepository().getSchedulesForStudent(
          studentId,
          fallbackSection: sec,
        ),

        // 3. Term Grades
        client
            .from('term_grades')
            .select(
              'subject_offering_id, term_number, initial_grade, transmuted_grade, remarks, is_finalized',
            )
            .eq('student_id', studentId),
      ]);

      final offeringRows = results[0] as List<Map<String, dynamic>>;
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

      AppDataCache.instance.set(cacheKey, {'offerings': offeringRows});
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

    final hideFinalGrades = student.effectiveHideFinalGradesFromParent;
    final hideTermGrades = student.effectiveHideTermGradesFromParent;

    // Compute Overall General Average across active encoded term grades
    double totalGrades = 0;
    int gradedSubjectsCount = 0;
    for (final off in _offerings) {
      final offId = off['id']?.toString() ?? '';
      final termsTaught = (off['terms_taught'] as num?)?.toInt() ?? 3;
      final termBlock = off['term_block']?.toString();
      final activeTerms = _activeTerms(termsTaught, termBlock);
      final terms = _termGrades[offId] ?? const {};
      final encodedMap = <int, int?>{
        for (final t in activeTerms) t: _encodedTermGrade(terms[t]),
      };
      final finalSubjGrade = DepEdGradingEngine.computeFinalGrade(
        termsTaught: activeTerms.length,
        activeTerms: activeTerms,
        termGrades: encodedMap,
      );
      if (finalSubjGrade != null) {
        totalGrades += finalSubjGrade;
        gradedSubjectsCount++;
      } else {
        final encodedActive = activeTerms
            .map((t) => _encodedTermGrade(terms[t]))
            .whereType<int>()
            .toList();
        if (encodedActive.isNotEmpty) {
          totalGrades +=
              encodedActive.reduce((a, b) => a + b) / encodedActive.length;
          gradedSubjectsCount++;
        }
      }
    }
    final generalAverage = (!hideFinalGrades && gradedSubjectsCount > 0)
        ? (totalGrades / gradedSubjectsCount).round()
        : null;

    final attendanceAccent = isDark
        ? const Color(0xFF4ADE80)
        : AppTheme.catGreen;
    final gwaAccent = (hideFinalGrades || hideTermGrades)
        ? (isDark ? const Color(0xFF94A3B8) : AppTheme.catSlate)
        : (isDark ? const Color(0xFF60A5FA) : AppTheme.catBlue);

    return AppPullToRefresh(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. SENIOR HIGH SCHOOL HERO CARD (WITH DOWNWARD CHILD SWITCHER BUTTON) ──
            _buildShsStudentHero(theme, isDark, student),

            const SizedBox(height: 16),

            // ── 2. SARDO EARLY WARNING ALERT (IF >= 3 ABSENCES) ──
            if (absentCount >= 3)
              _buildAbsenceAlert(theme, isDark, absentCount),

            // ── 3. ATTENDANCE & GWA PULSE METRICS (2 CARDS) ──
            Row(
              children: [
                _buildStatCard(
                  theme,
                  isDark,
                  'Attendance Rate',
                  '$rate%',
                  attendanceAccent,
                  caption:
                      '${presentCount + lateCount} of $totalAccounted days',
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  theme,
                  isDark,
                  'SSHS GWA',
                  (hideFinalGrades || hideTermGrades)
                      ? 'Protected'
                      : (generalAverage != null
                            ? '$generalAverage'
                            : 'Pending'),
                  gwaAccent,
                  caption: (hideFinalGrades || hideTermGrades)
                      ? '18+ Privacy'
                      : (generalAverage != null
                            ? (generalAverage >= 75 ? 'Passing' : 'Needs Help')
                            : 'Ongoing'),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ── 4. ENROLLED SUBJECTS SECTION ──
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
                Flexible(
                  child: Text(
                    'Tap subject for details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                  student: student,
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
  ) {
    final gradeSection = student.departmentOrSection?.isNotEmpty == true
        ? student.departmentOrSection!
        : 'Senior High School';

    final lrnDisplay = student.lrn?.isNotEmpty == true
        ? student.lrn!
        : (student.studentId?.isNotEmpty == true ? student.studentId! : 'N/A');

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                      student.lastFirstMi.isNotEmpty
                          ? student.lastFirstMi[0].toUpperCase()
                          : 'S',
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: widget.onSwitchChildTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    student.lastFirstMi,
                                    maxLines: 2,
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.onSwitchChildTap != null) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Switch Student',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: widget.onSwitchChildTap,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.38,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
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
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledSubjectCard({
    required ThemeData theme,
    required bool isDark,
    required Map<String, dynamic> offering,
    required UserModel student,
  }) {
    final offId = offering['id']?.toString() ?? '';
    final subjectsMap = _asMap(offering['subjects']);
    final subjectName = subjectsMap['subject_name']?.toString() ?? 'Subject';
    final subjectCode = subjectsMap['subject_code']?.toString() ?? '';

    final teacherMap = _asMap(offering['teacher_profiles']);
    final teacherFirstName = teacherMap['first_name']?.toString() ?? '';
    final teacherLastName = teacherMap['last_name']?.toString() ?? '';
    final teacherGender = teacherMap['gender']?.toString() ?? '';
    final teacherFullName = [
      teacherFirstName,
      teacherLastName,
    ].where((s) => s.isNotEmpty).join(' ');
    final gLower = teacherGender.toLowerCase();
    final teacherTitle = (gLower == 'female' || gLower == 'f')
        ? "Ma'am"
        : 'Sir';
    final teacherDisplayName = teacherFullName.isNotEmpty
        ? '$teacherTitle $teacherFullName'
        : 'Assigned Teacher';

    final termsTaught = (offering['terms_taught'] as num?)?.toInt() ?? 3;
    final termBlock = offering['term_block']?.toString();

    // Matching schedules
    ScheduleModel? matchingSchedule;
    for (final s in _schedules) {
      final sSub = s.subject.toLowerCase();
      if ((subjectCode.isNotEmpty &&
              sSub.contains(subjectCode.toLowerCase())) ||
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
              student: student,
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (subjectCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
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
