import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/utils/deped_grading_engine.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class StudentAcademicPerformanceScreen extends StatefulWidget {
  const StudentAcademicPerformanceScreen({super.key});

  @override
  State<StudentAcademicPerformanceScreen> createState() =>
      _StudentAcademicPerformanceScreenState();
}

class _StudentAcademicPerformanceScreenState
    extends State<StudentAcademicPerformanceScreen> {
  List<Map<String, dynamic>> _offerings = const [];
  Map<String, Map<int, Map<String, dynamic>>> _termGrades = const {};
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAcademicPerformance();
  }

  Future<void> _loadAcademicPerformance({bool silent = false}) async {
    setState(() {
      if (!silent || (_offerings.isEmpty && _loadError == null)) {
        _isLoading = true;
      }
      if (!silent) _loadError = null;
    });

    try {
      final student = AuthRepository.instance.currentUser;
      if (student == null ||
          student.role != UserRole.student ||
          student.id.isEmpty) {
        throw StateError('A signed-in student account is required.');
      }

      final client = SupabaseService().client;
      final responses = await Future.wait<dynamic>([
        client
            .from('student_enrollments')
            .select('''
              subject_offerings!inner (
                id,
                is_archived,
                is_final_grade_published,
                terms_taught,
                term_block,
                subjects ( id, title, code ),
                sections ( id, name )
              )
            ''')
            .eq('student_id', student.id),
        client
            .from('term_grades')
            .select('''
              id,
              subject_offering_id,
              term_number,
              transmuted_grade,
              is_published,
              is_finalized,
              remarks
            ''')
            .eq('student_id', student.id),
      ]);

      final enrollmentRows = (responses[0] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _asMap(row['subject_offerings']))
          .where(
            (offering) =>
                offering.isNotEmpty && offering['is_archived'] != true,
          )
          .toList();

      final gradeRows = (responses[1] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      final gradesByOffering = <String, Map<int, Map<String, dynamic>>>{};
      for (final row in gradeRows) {
        final offeringId = row['subject_offering_id']?.toString();
        final termNumber = (row['term_number'] as num?)?.toInt();
        if (offeringId == null || termNumber == null) continue;
        gradesByOffering.putIfAbsent(offeringId, () => {})[termNumber] = row;
      }

      if (mounted) {
        setState(() {
          _offerings = enrollmentRows;
          _termGrades = gradesByOffering;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading academic performance: $e');
      if (mounted) {
        setState(() {
          if (!silent || _offerings.isEmpty) _loadError = e;
          _isLoading = false;
        });
      }
    }
  }

  int? _getSubjectFinalGrade(Map<String, dynamic> offering) {
    final offeringId = offering['id']?.toString() ?? '';
    final termsTaught = ((offering['terms_taught'] as num?)?.toInt() ?? 3).clamp(
      1,
      3,
    );
    final termBlock = offering['term_block']?.toString() ?? '1ST, 2ND, 3RD';
    final activeTerms = _activeTerms(termsTaught, termBlock);
    final termsMap = _termGrades[offeringId] ?? const {};

    final grades = <int, int?>{};
    for (final term in activeTerms) {
      final row = termsMap[term];
      grades[term] = _encodedTermGrade(row);
    }

    final isFinalPublished = offering['is_final_grade_published'] == true;
    if (!isFinalPublished) return null;

    return DepEdGradingEngine.computeFinalGrade(
      termsTaught: activeTerms.length,
      activeTerms: activeTerms,
      termGrades: grades,
      unitsPerTerm: 1,
      totalUnitsEarned: activeTerms.length.toDouble(),
    );
  }

  DepEdHonorStatus _evaluateHonors(
    List<int> publishedGrades,
    int totalSubjects,
  ) {
    if (publishedGrades.isEmpty) {
      return const DepEdHonorStatus(
        title: 'Pending Evaluation',
        subtitle: 'Final grades have not been published by instructors yet.',
        isHonor: false,
        color: AppTheme.catSlate,
      );
    }

    final gwa =
        publishedGrades.reduce((a, b) => a + b) / publishedGrades.length;
    final lowestGrade = publishedGrades.reduce((a, b) => a < b ? a : b);
    final hasFailingGrade = lowestGrade < 75;
    final meetsGradeFloor = lowestGrade >= 85;
    final allSubjectsPublished = publishedGrades.length == totalSubjects;

    if (hasFailingGrade) {
      return const DepEdHonorStatus(
        title: 'Needs Remediation',
        subtitle:
            'One or more subjects require remedial intervention (grade below 75).',
        isHonor: false,
        color: AppTheme.catRed,
      );
    }

    if (gwa >= 98.0) {
      if (meetsGradeFloor) {
        return DepEdHonorStatus(
          title: 'With Highest Honors',
          subtitle: allSubjectsPublished
              ? 'Qualified for Academic Excellence (May Pinakamataas na Karangalan).'
              : 'Candidate for Highest Honors ($publishedGrades.length/$totalSubjects subjects evaluated).',
          isHonor: true,
          color: const Color(0xFFD97706),
        );
      } else {
        return const DepEdHonorStatus(
          title: 'Passed (Honors Disqualified)',
          subtitle:
              'GWA meets Highest Honors, but grade in one subject is below the 85 threshold (DepEd DO 36, s. 2016).',
          isHonor: false,
          color: AppTheme.catTeal,
        );
      }
    }

    if (gwa >= 95.0) {
      if (meetsGradeFloor) {
        return DepEdHonorStatus(
          title: 'With High Honors',
          subtitle: allSubjectsPublished
              ? 'Qualified for Academic Excellence (May Mataas na Karangalan).'
              : 'Candidate for High Honors ($publishedGrades.length/$totalSubjects subjects evaluated).',
          isHonor: true,
          color: const Color(0xFF2563EB),
        );
      } else {
        return const DepEdHonorStatus(
          title: 'Passed (Honors Disqualified)',
          subtitle:
              'GWA meets High Honors, but grade in one subject is below the 85 threshold (DepEd DO 36, s. 2016).',
          isHonor: false,
          color: AppTheme.catTeal,
        );
      }
    }

    if (gwa >= 90.0) {
      if (meetsGradeFloor) {
        return DepEdHonorStatus(
          title: 'With Honors',
          subtitle: allSubjectsPublished
              ? 'Qualified for Academic Excellence (May Karangalan).'
              : 'Candidate for Honors ($publishedGrades.length/$totalSubjects subjects evaluated).',
          isHonor: true,
          color: const Color(0xFF059669),
        );
      } else {
        return const DepEdHonorStatus(
          title: 'Passed (Honors Disqualified)',
          subtitle:
              'GWA meets Honors, but grade in one subject is below the 85 threshold (DepEd DO 36, s. 2016).',
          isHonor: false,
          color: AppTheme.catTeal,
        );
      }
    }

    if (gwa >= 75.0) {
      return const DepEdHonorStatus(
        title: 'Passed',
        subtitle: 'Satisfactory academic standing across all evaluated subjects.',
        isHonor: false,
        color: AppTheme.catTeal,
      );
    }

    return const DepEdHonorStatus(
      title: 'Needs Remediation',
      subtitle: 'General Weighted Average is below the 75 passing mark.',
      isHonor: false,
      color: AppTheme.catRed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dashboard = StudentDashboardRepository.instance.currentDashboard;
    final student =
        dashboard?.student ??
        AuthRepository.instance.currentUser ??
        UserModel(
          id: '',
          username: '',
          fullName: 'Student',
          email: '',
          role: UserRole.student,
        );

    final schoolInfo = [
      if (student.gradeLevel?.isNotEmpty == true) 'Grade ${student.gradeLevel}',
      if (student.departmentOrSection?.isNotEmpty == true)
        student.departmentOrSection!,
    ].join(' · ');

    final publishedGrades = <int>[];
    for (final offering in _offerings) {
      final grade = _getSubjectFinalGrade(offering);
      if (grade != null) publishedGrades.add(grade);
    }

    final double? gwa = publishedGrades.isNotEmpty
        ? (publishedGrades.reduce((a, b) => a + b) / publishedGrades.length)
        : null;

    final honorStatus = _evaluateHonors(publishedGrades, _offerings.length);
    final int passingCount = publishedGrades.where((g) => g >= 75).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Academic Performance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _isLoading
              ? _buildPerformanceSkeleton(theme, isDark)
              : AppPullToRefresh(
                  onRefresh: () => _loadAcademicPerformance(silent: true),
                  child: _loadError != null
                      ? AppPullToRefresh.scrollableState(
                          child: _buildErrorCard(theme),
                        )
                      : _offerings.isEmpty
                      ? AppPullToRefresh.scrollableState(
                          child: _buildEmptyCard(theme, isDark),
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            // ── Student Identity Header ──
                            _buildStudentHeader(theme, student, schoolInfo),
                            const SizedBox(height: 16),

                            // ── Overall DepEd Performance Hero ──
                            _buildHeroGwaCard(
                              theme,
                              isDark,
                              gwa: gwa,
                              honorStatus: honorStatus,
                              totalSubjects: _offerings.length,
                              evaluatedSubjects: publishedGrades.length,
                            ),
                            const SizedBox(height: 14),

                            // ── KPI Summary Cards Row ──
                            _buildKpiRow(
                              theme,
                              isDark,
                              totalSubjects: _offerings.length,
                              evaluatedSubjects: publishedGrades.length,
                              passingSubjects: passingCount,
                            ),
                            const SizedBox(height: 22),

                            // ── DepEd Section Title ──
                            Row(
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Curriculum Subjects Breakdown',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── Subjects List ──
                            for (final offering in _offerings)
                              _buildSubjectPerformanceCard(
                                theme,
                                isDark,
                                offering,
                              ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader(
    ThemeData theme,
    UserModel student,
    String schoolInfo,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              student.fullName.isNotEmpty
                  ? student.fullName.trim()[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (schoolInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    schoolInfo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (student.lrn?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    'LRN: ${student.lrn}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroGwaCard(
    ThemeData theme,
    bool isDark, {
    required double? gwa,
    required DepEdHonorStatus honorStatus,
    required int totalSubjects,
    required int evaluatedSubjects,
  }) {
    final gwaString = gwa != null ? gwa.toStringAsFixed(2) : '—';
    final descriptor =
        gwa != null ? DepEdGradingEngine.getDescriptor(gwa.round()) : 'Pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: honorStatus.color.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GENERAL WEIGHTED AVERAGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          gwaString,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (gwa != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '/ 100',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: honorStatus.color.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: honorStatus.color.withValues(
                      alpha: isDark ? 0.4 : 0.25,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (honorStatus.isHonor) ...[
                      const Icon(
                        Icons.military_tech_rounded,
                        size: 16,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      honorStatus.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: honorStatus.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'DepEd Descriptor: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                descriptor,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            honorStatus.subtitle,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(
    ThemeData theme,
    bool isDark, {
    required int totalSubjects,
    required int evaluatedSubjects,
    required int passingSubjects,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            theme,
            isDark,
            icon: Icons.auto_stories_rounded,
            title: 'Enrolled',
            value: '$totalSubjects',
            color: AppTheme.catBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            theme,
            isDark,
            icon: Icons.published_with_changes_rounded,
            title: 'Evaluated',
            value: '$evaluatedSubjects / $totalSubjects',
            color: AppTheme.catTeal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            theme,
            isDark,
            icon: Icons.check_circle_outline_rounded,
            title: 'Passed',
            value: '$passingSubjects',
            color: AppTheme.catGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.16 : 0.1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceCard(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> offering,
  ) {
    final subject = _asMap(offering['subjects']);
    final subjectTitle = subject['title']?.toString() ?? 'Subject';
    final subjectCode = subject['code']?.toString() ?? 'SHS';
    final offeringId = offering['id']?.toString() ?? '';
    final termsTaught = ((offering['terms_taught'] as num?)?.toInt() ?? 3).clamp(
      1,
      3,
    );
    final termBlock = offering['term_block']?.toString() ?? '1ST, 2ND, 3RD';
    final activeTerms = _activeTerms(termsTaught, termBlock);
    final termsMap = _termGrades[offeringId] ?? const {};

    final grades = <int, int?>{};
    for (final term in activeTerms) {
      grades[term] = _encodedTermGrade(termsMap[term]);
    }

    final isFinalPublished = offering['is_final_grade_published'] == true;
    final finalGrade = isFinalPublished
        ? DepEdGradingEngine.computeFinalGrade(
            termsTaught: activeTerms.length,
            activeTerms: activeTerms,
            termGrades: grades,
            unitsPerTerm: 1,
            totalUnitsEarned: activeTerms.length.toDouble(),
          )
        : null;

    final hasFinalGrade = finalGrade != null;
    final isPassing = finalGrade != null && finalGrade >= 75;
    final Color badgeColor = !hasFinalGrade
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : (isPassing ? AppTheme.catTeal : AppTheme.catRed);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.16 : 0.1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subjectTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  ),
                ),
                child: Text(
                  hasFinalGrade ? '$finalGrade' : 'Pending',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final term in activeTerms) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          grades[term] != null ? '${grades[term]}' : '—',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: grades[term] != null
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Term $term',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (term != activeTerms.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSkeleton(ThemeData theme, bool isDark) {
    return ShimmerLoading(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.16 : 0.1,
                ),
              ),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 48, height: 48, borderRadius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 140, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 180, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.16 : 0.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const ShimmerBox(width: 160, height: 16, borderRadius: 4),
          const SizedBox(height: 12),
          for (int i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.16 : 0.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.09,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              size: 26,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Academic Records Yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your official senior high school academic records and curriculum evaluations will appear here once subjects are plotted.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load academic records.',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_loadError',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class DepEdHonorStatus {
  final String title;
  final String subtitle;
  final bool isHonor;
  final Color color;

  const DepEdHonorStatus({
    required this.title,
    required this.subtitle,
    required this.isHonor,
    required this.color,
  });
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<int> _activeTerms(int termsTaught, String termBlock) {
  try {
    return DepEdSubjectCatalog.getActiveTermsForBlock(termsTaught, termBlock);
  } on ArgumentError {
    return switch (termsTaught) {
      1 => const [1],
      2 => const [1, 2],
      _ => const [1, 2, 3],
    };
  }
}

int? _encodedTermGrade(Map<String, dynamic>? row) {
  if (row == null) return null;
  if (row['is_published'] != true) return null;
  final grade = row['transmuted_grade'];
  final parsed = grade is num ? grade.toDouble() : double.tryParse('$grade');
  final remarks = row['remarks']?.toString().toLowerCase();
  final isFinalized = row['is_finalized'] == true;
  if (parsed == null ||
      (!isFinalized &&
          parsed == 0 &&
          (remarks == null || remarks == 'incomplete'))) {
    return null;
  }
  return parsed.round();
}
