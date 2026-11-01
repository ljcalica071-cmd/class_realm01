import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_subject_details_sheet.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ParentGradesTab extends StatefulWidget {
  final UserModel? student;

  const ParentGradesTab({super.key, required this.student});

  @override
  State<ParentGradesTab> createState() => _ParentGradesTabState();
}

class _ParentGradesTabState extends State<ParentGradesTab> {
  List<Map<String, dynamic>> _offerings = const [];
  List<ScheduleModel> _schedules = const [];
  Map<String, Map<int, Map<String, dynamic>>> _termGrades = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  @override
  void didUpdateWidget(covariant ParentGradesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student?.id != widget.student?.id) {
      _loadGrades();
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  Future<void> _loadGrades({bool silent = false}) async {
    final studentId = widget.student?.id;
    if (studentId == null || studentId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!silent) {
      final cacheKey = 'parent_child_grades_$studentId';
      final cached = AppDataCache.instance.getCached<Map<String, dynamic>>(
        cacheKey,
        (json) => Map<String, dynamic>.from(json as Map),
      );
      if (cached != null) {
        final offerings = (cached['offerings'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _offerings = offerings;
        _isLoading = false;
      }
    }

    try {
      final client = SupabaseService().client;
      final sec = widget.student?.departmentOrSection;

      final responses = await Future.wait<dynamic>([
        // 1. Enrolled Offerings
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

        // 2. Term Grades (Strictly 3 Terms)
        client
            .from('term_grades')
            .select(
              'subject_offering_id, term_number, initial_grade, transmuted_grade, remarks, is_finalized',
            )
            .eq('student_id', studentId),

        // 3. Schedules
        sec != null && sec.isNotEmpty
            ? SupabaseScheduleRepository.instance.getSchedules(section: sec)
            : Future.value(<ScheduleModel>[]),
      ]);

      final offeringRows = (responses[0] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => _asMap(row['subject_offerings']))
          .where((offering) => offering.isNotEmpty)
          .toList();

      final gradesByOffering = <String, Map<int, Map<String, dynamic>>>{};
      for (final row in responses[1] as List) {
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

      final scheduleRows = responses[2] as List<ScheduleModel>;

      if (!mounted) return;
      setState(() {
        _offerings = offeringRows;
        _termGrades = gradesByOffering;
        _schedules = scheduleRows;
        _isLoading = false;
      });

      AppDataCache.instance.set('parent_child_grades_$studentId', {
        'offerings': offeringRows,
      });
    } catch (e) {
      debugPrint('Error loading parent grades: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final student = widget.student;

    if (student == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppEmptyState(
            icon: Icons.person_off_outlined,
            title: 'No Student Selected',
            message: 'Please select a child to view their academic report card.',
          ),
        ),
      );
    }

    if (_isLoading && _offerings.isEmpty) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: theme.colorScheme.primary,
          size: 40,
        ),
      );
    }

    if (_offerings.isEmpty) {
      return AppPullToRefresh(
        onRefresh: () => _loadGrades(silent: true),
        child: AppPullToRefresh.scrollableState(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No Enrolled Subjects',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Subject enrollments for ${student.fullName} will appear once plotted by teachers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Compute Overall General Weighted Average (GWA) from finalized term grades
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

    return AppPullToRefresh(
      onRefresh: () => _loadGrades(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── GWA & Summary Banner Card ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.16 : 0.12,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: generalAverage != null
                        ? (generalAverage >= 75
                            ? AppTheme.catGreen.withValues(alpha: 0.15)
                            : AppTheme.catRed.withValues(alpha: 0.15))
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      generalAverage != null ? '$generalAverage' : '—',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: generalAverage != null
                            ? (generalAverage >= 75
                                ? AppTheme.catGreen
                                : AppTheme.catRed)
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SSHS Report Card (${_offerings.length} Subjects)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        generalAverage != null
                            ? 'General Weighted Average (GWA) computed across finalized 3-terms.'
                            : 'Senior High School standing for ${student.firstName ?? student.fullName}.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Subject Grade Cards List ──
          ..._offerings.map((offering) {
            final offId = offering['id']?.toString() ?? '';
            final subjectsMap = _asMap(offering['subjects']);
            final subjectName =
                subjectsMap['subject_name']?.toString() ?? 'Subject';
            final subjectCode = subjectsMap['subject_code']?.toString() ?? '';
            final termsTaught = (offering['terms_taught'] as num?)?.toInt() ?? 3;
            final termBlock = offering['term_block']?.toString();

            final teacherMap = _asMap(offering['teacher_profiles']);
            final teacherFirstName = teacherMap['first_name']?.toString() ?? '';
            final teacherLastName = teacherMap['last_name']?.toString() ?? '';
            final teacherGender = teacherMap['gender']?.toString() ?? '';
            final teacherName = [teacherFirstName, teacherLastName]
                .where((s) => s.isNotEmpty)
                .join(' ');
            final teacherTitle =
                teacherGender.toLowerCase() == 'female' ? 'Ms.' : 'Mr.';
            final teacherDisplayName = teacherName.isNotEmpty
                ? '$teacherTitle $teacherName'
                : 'Assigned Teacher';

            final terms = _termGrades[offId] ?? {};
            final t1 = terms[1]?['transmuted_grade']?.toString() ?? '—';
            final t2 = terms[2]?['transmuted_grade']?.toString() ?? '—';
            final t3 = terms[3]?['transmuted_grade']?.toString() ?? '—';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.16 : 0.12,
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
                      termGrades: terms,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                subjectName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (subjectCode.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  subjectCode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Teacher: $teacherDisplayName',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              termsTaught == 1
                                  ? '1 Term${termBlock != null ? " ($termBlock)" : ""}'
                                  : '3 Terms',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildTermGradeBox(theme, isDark, 'Term 1', t1),
                            const SizedBox(width: 8),
                            _buildTermGradeBox(theme, isDark, 'Term 2', t2),
                            const SizedBox(width: 8),
                            _buildTermGradeBox(theme, isDark, 'Term 3', t3),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTermGradeBox(
    ThemeData theme,
    bool isDark,
    String termLabel,
    String gradeValue,
  ) {
    final hasGrade = gradeValue != '—';
    final numGrade = num.tryParse(gradeValue);
    final isPassing = numGrade != null && numGrade >= 75;

    final Color badgeColor = !hasGrade
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : (isPassing
            ? (isDark ? const Color(0xFF2DD4BF) : AppTheme.catTeal)
            : AppTheme.catRed);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: hasGrade
              ? badgeColor.withValues(alpha: isDark ? 0.14 : 0.08)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasGrade
                ? badgeColor.withValues(alpha: isDark ? 0.35 : 0.22)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Text(
              gradeValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              termLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            if (hasGrade) ...[
              const SizedBox(height: 1),
              Text(
                isPassing ? 'Passed' : 'Needs Help',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
