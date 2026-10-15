import 'package:flutter/material.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/utils/deped_grading_engine.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_academic_performance_screen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class StudentGradesScreen extends StatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  State<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  List<Map<String, dynamic>> _offerings = const [];
  Map<String, Map<int, Map<String, dynamic>>> _termGrades = const {};
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final student = AuthRepository.instance.currentUser;
      if (student == null ||
          student.role != UserRole.student ||
          student.id.isEmpty) {
        throw StateError(
          'A signed-in student account is required to load grades.',
        );
      }

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
                teacher_profiles ( first_name, last_name )
              )
            ''')
            .eq('student_id', student.id)
            .ilike('status', 'enrolled'),
        client
            .from('term_grades')
            .select(
              'subject_offering_id, term_number, initial_grade, transmuted_grade, remarks, is_finalized',
            )
            .eq('student_id', student.id),
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

      if (mounted) {
        setState(() {
          _offerings = offeringRows;
          _termGrades = gradesByOffering;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = AuthRepository.instance.currentUser;
    final body = _isLoading
        ? Center(
            child: LoadingAnimationWidget.staggeredDotsWave(
              color: theme.colorScheme.primary,
              size: 44,
            ),
          )
        : _loadError != null
        ? _buildErrorState(theme)
        : _offerings.isEmpty
        ? _buildEmptyState(theme)
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (student != null) _buildStudentHeader(theme, student),
              const SizedBox(height: 16),
              for (final offering in _offerings) ...[
                _StudentSubjectGradeCard(
                  offering: offering,
                  termGrades:
                      _termGrades[offering['id']?.toString()] ?? const {},
                ),
                const SizedBox(height: 12),
              ],
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Grades'),
        actions: [
          IconButton(
            tooltip: 'Refresh grades',
            icon: const Icon(Icons.refresh),
            onPressed: _loadGrades,
          ),
          IconButton(
            tooltip: 'Academic Performance',
            icon: const Icon(Icons.school_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StudentAcademicPerformanceScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(width: double.infinity, child: body),
        ),
      ),
    );
  }

  Widget _buildStudentHeader(ThemeData theme, UserModel student) {
    final schoolInfo = [
      if (student.gradeLevel?.isNotEmpty == true) 'Grade ${student.gradeLevel}',
      if (student.departmentOrSection?.isNotEmpty == true)
        student.departmentOrSection!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.84),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.onPrimary.withValues(
              alpha: 0.18,
            ),
            child: Text(
              student.fullName.trim().isEmpty
                  ? 'S'
                  : student.fullName.trim()[0].toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (schoolInfo.isNotEmpty)
                  Text(
                    schoolInfo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                if (student.lrn?.isNotEmpty == true)
                  Text(
                    'LRN: ${student.lrn}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Grades could not be loaded.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError.toString(),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadGrades,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grade_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No enrolled subjects found',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your subjects and posted grades will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentSubjectGradeCard extends StatelessWidget {
  const _StudentSubjectGradeCard({
    required this.offering,
    required this.termGrades,
  });

  final Map<String, dynamic> offering;
  final Map<int, Map<String, dynamic>> termGrades;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subject = _asMap(offering['subjects']);
    final section = _asMap(offering['sections']);
    final teacher = _asMap(offering['teacher_profiles']);
    final termsTaught = ((offering['terms_taught'] as num?)?.toInt() ?? 3)
        .clamp(1, 3);
    final termBlock = offering['term_block']?.toString() ?? '1ST, 2ND, 3RD';
    final activeTerms = _activeTerms(termsTaught, termBlock);
    final grades = <int, int?>{
      for (final term in activeTerms) term: _encodedTermGrade(termGrades[term]),
    };
    final finalGrade = DepEdGradingEngine.computeFinalGrade(
      termsTaught: activeTerms.length,
      activeTerms: activeTerms,
      termGrades: grades,
    );
    final teacherName = [teacher['first_name'], teacher['last_name']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' ');
    final sectionName = section['section_name']?.toString() ?? '';
    final gradeLevel = section['grade_level'] ?? subject['grade_level'];
    final schoolInfo = [
      if (sectionName.isNotEmpty) sectionName,
      if (gradeLevel != null) 'Grade $gradeLevel',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    subject['subject_name']?.toString() ?? 'Subject',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _InfoBadge(
                  label: subject['subject_code']?.toString() ?? '—',
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                ),
              ],
            ),
            if (schoolInfo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                schoolInfo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (teacherName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Teacher: $teacherName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoBadge(
                  label: 'WW ${_formatWeight(offering['ww_weight'])}%',
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
                _InfoBadge(
                  label: 'PT ${_formatWeight(offering['pt_weight'])}%',
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
                _InfoBadge(
                  label: 'EX ${_formatWeight(offering['ex_weight'])}%',
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Term Block  ·  $termBlock',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var term = 1; term <= 3; term++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: term < 3 ? 8 : 0),
                      child: _TermGradeTile(
                        term: term,
                        isActive: activeTerms.contains(term),
                        grade: termGrades[term],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINAL GRADE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.7,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        finalGrade?.toString() ?? '—',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (finalGrade case final grade?) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _InfoBadge(
                        label: DepEdGradingEngine.getDescriptor(grade),
                        background: scheme.primaryContainer,
                        foreground: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 6),
                      _InfoBadge(
                        label: DepEdGradingEngine.getRemarks(grade),
                        background: grade >= 75
                            ? scheme.tertiaryContainer
                            : scheme.errorContainer,
                        foreground: grade >= 75
                            ? scheme.onTertiaryContainer
                            : scheme.onErrorContainer,
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'Awaiting grades',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TermGradeTile extends StatelessWidget {
  const _TermGradeTile({
    required this.term,
    required this.isActive,
    required this.grade,
  });

  final int term;
  final bool isActive;
  final Map<String, dynamic>? grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final encodedGrade = isActive ? _encodedTermGrade(grade) : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'TERM $term',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            !isActive ? 'N/A' : encodedGrade?.toString() ?? '—',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return {};
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

String _formatWeight(dynamic value) {
  final weight = value is num ? value.toDouble() : double.tryParse('$value');
  if (weight == null) return '—';
  return weight == weight.roundToDouble()
      ? weight.toInt().toString()
      : weight.toString();
}
