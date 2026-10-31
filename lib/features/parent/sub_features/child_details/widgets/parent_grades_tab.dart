import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/models/user_model.dart';
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
      final responses = await Future.wait<dynamic>([
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
                subjects ( subject_name, subject_code, grade_level ),
                sections ( section_name, grade_level ),
                teacher_profiles ( first_name, last_name, gender )
              )
            ''')
            .eq('student_id', studentId)
            .ilike('status', 'enrolled'),
        client
            .from('term_grades')
            .select(
              'subject_offering_id, term_number, initial_grade, transmuted_grade, remarks, is_finalized',
            )
            .eq('student_id', studentId),
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
            termNumber > 4) {
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
        _termGrades = gradesByOffering;
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
          child: Text(
            'No linked student found. Please contact the school administrator.',
            textAlign: TextAlign.center,
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
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
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

    // Compute Overall General Average from finalized term grades
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
          // ── General Average & Summary Banner Card ──
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
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: (generalAverage != null && generalAverage >= 75)
                        ? AppTheme.catGreen.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          )
                        : theme.colorScheme.primary.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (generalAverage != null && generalAverage >= 75)
                          ? AppTheme.catGreen.withValues(alpha: 0.4)
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      generalAverage != null ? '$generalAverage' : '—',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: (generalAverage != null && generalAverage >= 75)
                            ? AppTheme.catGreen
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Official Report Card (${_offerings.length} Subjects)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        generalAverage != null
                            ? 'General Average computed based on finalized grading periods.'
                            : 'DepEd SHS Quarterly standing for ${student.firstName ?? student.fullName}.',
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
            final teacherMap = _asMap(offering['teacher_profiles']);
            final teacherName = [
              teacherMap['first_name']?.toString() ?? '',
              teacherMap['last_name']?.toString() ?? '',
            ].where((s) => s.isNotEmpty).join(' ');

            final terms = _termGrades[offId] ?? {};
            final q1 = terms[1]?['transmuted_grade']?.toString() ?? '—';
            final q2 = terms[2]?['transmuted_grade']?.toString() ?? '—';
            final q3 = terms[3]?['transmuted_grade']?.toString() ?? '—';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.16 : 0.12,
                  ),
                ),
              ),
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
                  if (teacherName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Teacher: $teacherName',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTermGradeBox(theme, isDark, 'Quarter 1', q1),
                      const SizedBox(width: 8),
                      _buildTermGradeBox(theme, isDark, 'Quarter 2', q2),
                      const SizedBox(width: 8),
                      _buildTermGradeBox(theme, isDark, 'Quarter 3', q3),
                    ],
                  ),
                ],
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: hasGrade
              ? AppTheme.catTeal.withValues(alpha: isDark ? 0.14 : 0.08)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasGrade
                ? AppTheme.catTeal.withValues(alpha: isDark ? 0.35 : 0.22)
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
                color: hasGrade
                    ? (isDark ? const Color(0xFF2DD4BF) : AppTheme.catTeal)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
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
          ],
        ),
      ),
    );
  }
}
