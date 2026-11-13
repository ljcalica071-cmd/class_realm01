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

/// Standalone screen wrapper for opening Report Card & Term Grades from the
/// Parent Side Panel (Drawer) or Quick Actions on Home.
class ParentGradesScreen extends StatefulWidget {
  final UserModel? initialStudent;
  final List<UserModel> allChildren;
  final ValueChanged<UserModel>? onSelectChild;

  const ParentGradesScreen({
    super.key,
    required this.initialStudent,
    this.allChildren = const [],
    this.onSelectChild,
  });

  @override
  State<ParentGradesScreen> createState() => _ParentGradesScreenState();
}

class _ParentGradesScreenState extends State<ParentGradesScreen> {
  late UserModel? _activeStudent;

  @override
  void initState() {
    super.initState();
    _activeStudent =
        widget.initialStudent ??
        (widget.allChildren.isNotEmpty ? widget.allChildren.first : null);
  }

  void _showChildSwitcherSheet() {
    if (widget.allChildren.isEmpty) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Text(
                  'Switch Linked Student',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a linked student to view their Term & Final Grades.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 14),
                ...widget.allChildren.map((child) {
                  final isSelected = child.id == _activeStudent?.id;
                  final rel = child.parentGuardianRelationship ?? 'Guardian';
                  final sec = child.departmentOrSection ?? 'Senior High School';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              ),
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.14),
                        child: Text(
                          child.lastFirstMi.isNotEmpty
                              ? child.lastFirstMi[0].toUpperCase()
                              : 'S',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        child.lastFirstMi,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '$rel • $sec',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        setState(() => _activeStudent = child);
                        widget.onSelectChild?.call(child);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final student = _activeStudent;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Card & Term Grades',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (student != null && widget.allChildren.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _showChildSwitcherSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.primary.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? theme.colorScheme.primary.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            student.firstName?.isNotEmpty == true
                                ? student.firstName!
                                : student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? theme.colorScheme.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isDark
                              ? theme.colorScheme.primary
                              : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ParentGradesTab(student: student),
    );
  }
}

class ParentGradesTab extends StatefulWidget {
  final UserModel? student;
  final List<Map<String, dynamic>>? initialOfferings;
  final Map<String, Map<int, Map<String, dynamic>>>? initialTermGrades;

  const ParentGradesTab({
    super.key,
    required this.student,
    this.initialOfferings,
    this.initialTermGrades,
  });

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
    if (widget.initialOfferings != null) {
      _offerings = widget.initialOfferings!;
      _termGrades = widget.initialTermGrades ?? const {};
      _isLoading = false;
    } else {
      _loadGrades();
    }
  }

  @override
  void didUpdateWidget(covariant ParentGradesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student?.id != widget.student?.id) {
      if (widget.initialOfferings != null) {
        setState(() {
          _offerings = widget.initialOfferings!;
          _termGrades = widget.initialTermGrades ?? const {};
          _isLoading = false;
        });
      } else {
        _loadGrades();
      }
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

  /// Extracts a valid encoded transmuted grade (`> 0` and either finalized or
  /// non-incomplete), avoiding unfinalized `0` placeholder rows from showing
  /// as `0 / Needs Help`.
  static int? _encodedTermGrade(Map<String, dynamic>? row) {
    if (row == null) return null;
    if (row['is_published'] != true) return null;
    final raw = (row['transmuted_grade'] as num?)?.toInt();
    if (raw == null || raw <= 0) return null;
    final isFinalized = row['is_finalized'] == true;
    final remarks = (row['remarks']?.toString() ?? '').trim().toLowerCase();
    if (!isFinalized && remarks == 'incomplete') return null;
    return raw;
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
        // 1. Enrolled Offerings with full Teacher Public Profile & Settings
        SupabaseParentRepository().getEnrolledOfferingsWithTeachersForStudent(
          studentId,
        ),

        // 2. Term Grades (Strictly 3 Terms)
        client
            .from('term_grades')
            .select(
              'subject_offering_id, term_number, initial_grade, transmuted_grade, remarks, is_finalized, is_published',
            )
            .eq('student_id', studentId),

        // 3. Schedules (directly from student's enrolled offerings + section fallback)
        SupabaseParentRepository().getSchedulesForStudent(
          studentId,
          fallbackSection: sec,
        ),
      ]);

      final offeringRows = (responses[0] as List<Map<String, dynamic>>);

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
            message:
                'Please select a child to view their academic report card.',
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

    final hideTermGrades = student.effectiveHideTermGradesFromParent;
    final hideFinalGrades = student.effectiveHideFinalGradesFromParent;

    // Compute Overall General Weighted Average (GWA) from active encoded term grades
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
        // Fallback: average of currently encoded active terms
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

    return AppPullToRefresh(
      onRefresh: () => _loadGrades(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── 18+ Student Grade Privacy Notice (Only if student hid grades) ──
          if (hideTermGrades || hideFinalGrades) ...[
            _buildAdultPrivacyBanner(
              theme,
              isDark,
              student,
              hideTermGrades: hideTermGrades,
              hideFinalGrades: hideFinalGrades,
            ),
            const SizedBox(height: 14),
          ],

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
                    color: hideFinalGrades
                        ? AppTheme.catSlate.withValues(alpha: 0.14)
                        : generalAverage != null
                        ? (generalAverage >= 75
                              ? AppTheme.catGreen.withValues(alpha: 0.15)
                              : AppTheme.catRed.withValues(alpha: 0.15))
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: hideFinalGrades
                        ? Icon(
                            Icons.lock_outline_rounded,
                            color: AppTheme.catSlate,
                            size: 24,
                          )
                        : Text(
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
                        'SSHS Report Card (${_offerings.length} ${_offerings.length == 1 ? "Subject" : "Subjects"})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hideFinalGrades
                            ? 'Final Subject Grades & GWA are protected under 18+ student privacy settings.'
                            : generalAverage != null
                            ? 'General Weighted Average (GWA) computed across active terms.'
                            : 'Grades will be computed once term grades are finalized by teachers.',
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
            final termsTaught =
                (offering['terms_taught'] as num?)?.toInt() ?? 3;
            final termBlock = offering['term_block']?.toString();
            final activeTerms = _activeTerms(termsTaught, termBlock);

            final teacherMap = _asMap(offering['teacher_profiles']);
            final teacherFirstName = teacherMap['first_name']?.toString() ?? '';
            final teacherLastName = teacherMap['last_name']?.toString() ?? '';
            final teacherGender = teacherMap['gender']?.toString() ?? '';
            final teacherName = [
              teacherFirstName,
              teacherLastName,
            ].where((s) => s.isNotEmpty).join(' ');
            final gLower = teacherGender.toLowerCase();
            final teacherTitle = (gLower == 'female' || gLower == 'f')
                ? "Ma'am"
                : 'Sir';
            final teacherDisplayName = teacherName.isNotEmpty
                ? '$teacherTitle $teacherName'
                : 'Assigned Teacher';

            final terms = _termGrades[offId] ?? {};
            final t1Grade = _encodedTermGrade(terms[1]);
            final t2Grade = _encodedTermGrade(terms[2]);
            final t3Grade = _encodedTermGrade(terms[3]);
            final isFinalPublished =
                offering['is_final_grade_published'] == true;
            final finalSubjGrade = isFinalPublished
                ? DepEdGradingEngine.computeFinalGrade(
                    termsTaught: activeTerms.length,
                    activeTerms: activeTerms,
                    termGrades: {1: t1Grade, 2: t2Grade, 3: t3Grade},
                  )
                : null;

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
                      student: student,
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
                            Expanded(
                              child: Text(
                                'Teacher: $teacherDisplayName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                            _buildTermGradeBox(
                              theme: theme,
                              isDark: isDark,
                              termLabel: 'Term 1',
                              isActiveTerm: activeTerms.contains(1),
                              isHiddenByStudent: hideTermGrades,
                              encodedGrade: t1Grade,
                              isUnpublished:
                                  terms[1] != null &&
                                  terms[1]!['is_published'] != true,
                            ),
                            const SizedBox(width: 8),
                            _buildTermGradeBox(
                              theme: theme,
                              isDark: isDark,
                              termLabel: 'Term 2',
                              isActiveTerm: activeTerms.contains(2),
                              isHiddenByStudent: hideTermGrades,
                              encodedGrade: t2Grade,
                              isUnpublished:
                                  terms[2] != null &&
                                  terms[2]!['is_published'] != true,
                            ),
                            const SizedBox(width: 8),
                            _buildTermGradeBox(
                              theme: theme,
                              isDark: isDark,
                              termLabel: 'Term 3',
                              isActiveTerm: activeTerms.contains(3),
                              isHiddenByStudent: hideTermGrades,
                              encodedGrade: t3Grade,
                              isUnpublished:
                                  terms[3] != null &&
                                  terms[3]!['is_published'] != true,
                            ),
                            const SizedBox(width: 8),
                            _buildFinalGradeBox(
                              theme: theme,
                              isDark: isDark,
                              isHiddenByStudent: hideFinalGrades,
                              finalGrade: finalSubjGrade,
                              isPublished: isFinalPublished,
                            ),
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

  Widget _buildAdultPrivacyBanner(
    ThemeData theme,
    bool isDark,
    UserModel student, {
    required bool hideTermGrades,
    required bool hideFinalGrades,
  }) {
    final String hiddenScope;
    if (hideTermGrades && hideFinalGrades) {
      hiddenScope = 'Term Grades and Final Subject Grades';
    } else if (hideTermGrades) {
      hiddenScope = 'Term Grades (Term 1, Term 2, Term 3)';
    } else {
      hiddenScope = 'Final Subject Grades and GWA';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.catSlate.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.catSlate.withValues(alpha: isDark ? 0.4 : 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: isDark ? const Color(0xFF94A3B8) : AppTheme.catSlate,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '18+ Student Grade Privacy Active',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${student.fullName} (18+) has chosen to keep $hiddenScope private. Enrolled subjects, attendance records, class schedules, and subject teacher details remain accessible.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermGradeBox({
    required ThemeData theme,
    required bool isDark,
    required String termLabel,
    required bool isActiveTerm,
    required bool isHiddenByStudent,
    required int? encodedGrade,
    bool isUnpublished = false,
  }) {
    if (!isActiveTerm) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.25,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              Text(
                'N/A',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                termLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Inactive',
                style: TextStyle(
                  fontSize: 8.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isHiddenByStudent) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.catSlate.withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.catSlate.withValues(alpha: isDark ? 0.35 : 0.22),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.catSlate,
              ),
              const SizedBox(height: 3),
              Text(
                termLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Hidden (18+)',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.catSlate,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasGrade = encodedGrade != null;
    final isPassing = encodedGrade != null && encodedGrade >= 75;

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
              hasGrade ? '$encodedGrade' : '—',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              termLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              isUnpublished
                  ? 'Not published'
                  : (hasGrade
                        ? (isPassing ? 'Passed' : 'Needs Help')
                        : 'Ongoing'),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: hasGrade
                    ? badgeColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalGradeBox({
    required ThemeData theme,
    required bool isDark,
    required bool isHiddenByStudent,
    required int? finalGrade,
    bool isPublished = true,
  }) {
    if (isHiddenByStudent) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.catSlate.withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.catSlate.withValues(alpha: isDark ? 0.35 : 0.22),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.catSlate,
              ),
              const SizedBox(height: 3),
              Text(
                'Final',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Protected',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.catSlate,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasGrade = finalGrade != null;
    final isPassing = finalGrade != null && finalGrade >= 75;
    final Color badgeColor = !hasGrade
        ? theme.colorScheme.primary
        : (isPassing ? AppTheme.catGreen : AppTheme.catRed);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: hasGrade
              ? badgeColor.withValues(alpha: isDark ? 0.16 : 0.1)
              : theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasGrade
                ? badgeColor.withValues(alpha: isDark ? 0.4 : 0.28)
                : theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          children: [
            Text(
              hasGrade ? '$finalGrade' : '—',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: hasGrade
                    ? badgeColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Final',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              !isPublished
                  ? 'Not published'
                  : (hasGrade ? (isPassing ? 'Passed' : 'Failed') : 'Pending'),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: hasGrade
                    ? badgeColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
