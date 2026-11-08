import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/edit_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/anti_cheating.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/item_analysis/item_analysis.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TeacherUnifiedAssessmentsTab extends StatefulWidget {
  final List<ActivityModel> activities;
  final List<QuizOrExamModel> assessments;
  final String selectedClassSection;
  final ValueChanged<ActivityModel>? onViewSubmissions;
  final TeacherClassworkRepository? repository;
  final FutureOr<void> Function()? onRefresh;
  final bool isLoading;

  const TeacherUnifiedAssessmentsTab({
    super.key,
    required this.activities,
    required this.assessments,
    this.selectedClassSection = 'All Sections',
    this.onViewSubmissions,
    this.repository,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  State<TeacherUnifiedAssessmentsTab> createState() =>
      _TeacherUnifiedAssessmentsTabState();
}

class _TeacherUnifiedAssessmentsTabState
    extends State<TeacherUnifiedAssessmentsTab> {
  int? _selectedGrade;
  String? _selectedSubject;
  String? _selectedClassSection;
  List<Map<String, dynamic>> _teacherSubjects = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherSections();
  }

  int _parseGrade(dynamic g) {
    if (g is int) return g;
    return int.tryParse(g?.toString() ?? '') ?? 11;
  }

  String _formatSectionName(dynamic raw) {
    if (raw == null) return 'Section';
    final clean = raw.toString().trim();
    if (clean.isEmpty) return 'Section';
    if (clean.toLowerCase().startsWith('section')) {
      return clean[0].toUpperCase() + clean.substring(1);
    }
    return 'Section $clean';
  }

  List<int> get _availableGrades {
    if (_teacherSubjects.isEmpty) return [];
    final set = <int>{};
    for (final s in _teacherSubjects) {
      set.add(_parseGrade(s['grade_level']));
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableSubjects {
    if (_teacherSubjects.isEmpty) return [];
    final set = <String>{};
    for (final s in _teacherSubjects) {
      if (_selectedGrade == null ||
          _parseGrade(s['grade_level']) == _selectedGrade) {
        final name = s['subject_name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          set.add(name);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableSections {
    if (_teacherSubjects.isEmpty) return [];
    final set = <String>{};
    for (final s in _teacherSubjects) {
      final matchesGrade =
          _selectedGrade == null ||
          _parseGrade(s['grade_level']) == _selectedGrade;
      final matchesSubject =
          _selectedSubject == null ||
          (s['subject_name']?.toString().trim() == _selectedSubject);
      if (matchesGrade && matchesSubject) {
        final sec = s['section_name']?.toString().trim();
        if (sec != null && sec.isNotEmpty) {
          set.add(sec);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> _loadTeacherSections() async {
    try {
      final teacherId = AuthRepository.instance.currentUser?.id;
      if (teacherId == null) return;
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
      if (!mounted) return;
      setState(() {
        _teacherSubjects = subjects;

        final grades = _availableGrades;
        if (grades.isNotEmpty) {
          _selectedGrade ??= grades.first;
        }

        final subs = _availableSubjects;
        if (subs.isNotEmpty) {
          _selectedSubject ??= subs.first;
        }

        final secs = _availableSections;
        if (secs.isNotEmpty) {
          if (widget.selectedClassSection.isNotEmpty &&
              widget.selectedClassSection != 'All Sections' &&
              secs.contains(widget.selectedClassSection)) {
            _selectedClassSection = widget.selectedClassSection;
          } else {
            _selectedClassSection = secs.first;
          }
        }
      });
    } catch (_) {}
  }

  bool get _isCurrentSubjectZeroExam {
    if (_teacherSubjects.isEmpty) return false;
    final match = _teacherSubjects.firstWhere(
      (s) =>
          (_selectedSubject == null || s['subject_name'] == _selectedSubject) &&
          (_selectedClassSection == null ||
              s['section_name'] == _selectedClassSection),
      orElse: () => _teacherSubjects.first,
    );
    final exWeight = (match['ex_weight'] as num?)?.toDouble() ?? 30.0;
    return exWeight == 0.0;
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool _matchesItem(
    String? itemSubject,
    String? itemSection,
    List<String> assignedSections,
  ) {
    // If user has chosen a section
    if (_selectedClassSection != null && _selectedClassSection!.isNotEmpty) {
      final targetSec = _selectedClassSection!.trim().toLowerCase();
      final sec = itemSection?.trim().toLowerCase();
      final matchesSection =
          (sec != null &&
              (sec == targetSec ||
                  sec.contains(targetSec) ||
                  targetSec.contains(sec))) ||
          assignedSections.any((s) {
            final clean = s.trim().toLowerCase();
            return clean == targetSec ||
                clean.contains(targetSec) ||
                targetSec.contains(clean);
          });
      if (!matchesSection) return false;
    }
    // If user has chosen a subject
    if (_selectedSubject != null && _selectedSubject!.isNotEmpty) {
      final targetSub = _selectedSubject!.trim().toLowerCase();
      final sub = itemSubject?.trim().toLowerCase();
      if (sub == null ||
          (!sub.contains(targetSub) && !targetSub.contains(sub))) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final writtenWork = <Widget>[
      ...widget.activities
          .where(
            (item) =>
                !item.isRequirement &&
                _matchesItem(item.subject, item.section, item.assignedSections),
          )
          .map((item) => _buildUnifiedActivityCard(item, 'WW')),
      ...widget.assessments
          .where(
            (item) =>
                !item.isExam &&
                _matchesItem(item.subject, item.section, item.assignedSections),
          )
          .map((item) => _buildUnifiedAssessmentCard(item, 'WW')),
    ];
    final performanceTasks = widget.activities
        .where(
          (item) =>
              item.isRequirement &&
              _matchesItem(item.subject, item.section, item.assignedSections),
        )
        .map((item) => _buildUnifiedActivityCard(item, 'PT'))
        .toList();
    final examinations = widget.assessments
        .where(
          (item) =>
              item.isExam &&
              _matchesItem(item.subject, item.section, item.assignedSections),
        )
        .map((item) => _buildUnifiedAssessmentCard(item, 'EX'))
        .toList();

    final availableGrades = _availableGrades;
    final availableSubjects = _availableSubjects;
    final availableSections = _availableSections;

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classwork',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create activities, performance tasks, quizzes, and exams by subject and section.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right-aligned Target Filter Card matching Learning Materials
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Grade Dropdown
                      if (availableGrades.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: availableGrades.contains(_selectedGrade)
                                  ? _selectedGrade
                                  : availableGrades.first,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                              items: availableGrades
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text('Grade $g'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedGrade = val;
                                    final subs = _availableSubjects;
                                    _selectedSubject = subs.isNotEmpty
                                        ? subs.first
                                        : null;
                                    final secs = _availableSections;
                                    _selectedClassSection = secs.isNotEmpty
                                        ? secs.first
                                        : null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Subject Dropdown (NO ALL SUBJECTS)
                      if (availableSubjects.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  availableSubjects.contains(_selectedSubject)
                                  ? _selectedSubject
                                  : availableSubjects.first,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                              items: availableSubjects
                                  .map(
                                    (sub) => DropdownMenuItem(
                                      value: sub,
                                      child: Text(
                                        sub,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSubject = val;
                                    final secs = _availableSections;
                                    _selectedClassSection = secs.isNotEmpty
                                        ? secs.first
                                        : null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Section Dropdown (NO ALL SECTIONS)
                      if (availableSections.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  availableSections.contains(
                                    _selectedClassSection,
                                  )
                                  ? _selectedClassSection
                                  : availableSections.first,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                              items: availableSections
                                  .map(
                                    (sec) => DropdownMenuItem(
                                      value: sec,
                                      child: Text(
                                        _formatSectionName(sec),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedClassSection = val);
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSyncing) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F8A48)),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0F8A48),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Updating schedule and syncing with gradebook...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F8A48),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Written Works (WW)'),
                  Tab(text: 'Performance Tasks (PT)'),
                  Tab(text: 'Examinations (EX)'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _KeepAliveTabWrapper(
                    child: _buildUnifiedCategoryView(
                      label: 'Written Works',
                      items: writtenWork,
                      emptyTitle: 'No written works yet',
                      emptyMessage: 'Create assignments, activities, and quizzes for your students.',
                      icon: LucideIcons.fileText,
                      actionButtons: [
                        AppButton.primary(
                          label: 'Create Activity',
                          icon: Icons.assignment_outlined,
                          onPressed: () {
                            final sectionParam = _selectedClassSection ?? '';
                            final offeringMatch = _teacherSubjects.firstWhere(
                              (s) =>
                                  (_selectedSubject == null ||
                                      s['subject_name'] == _selectedSubject) &&
                                  (_selectedClassSection == null ||
                                      s['section_name'] ==
                                          _selectedClassSection),
                              orElse: () => _teacherSubjects.isNotEmpty
                                  ? _teacherSubjects.first
                                  : <String, dynamic>{},
                            );
                            CreateRequirementFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialSubject: _selectedSubject,
                              initialOfferingId: offeringMatch['id']
                                  ?.toString(),
                              initialOfferings: _teacherSubjects,
                              isPerformanceTask: false,
                              repository: widget.repository,
                              onRequirementCreated: () {
                                widget.onRefresh?.call();
                                setState(() {});
                              },
                            );
                          },
                          isSmall: true,
                        ),
                        AppButton.primary(
                          label: 'Create Quiz',
                          icon: Icons.quiz_outlined,
                          onPressed: () {
                            final sectionParam = _selectedClassSection ?? '';
                            final offeringMatch = _teacherSubjects.firstWhere(
                              (s) =>
                                  (_selectedSubject == null ||
                                      s['subject_name'] == _selectedSubject) &&
                                  (_selectedClassSection == null ||
                                      s['section_name'] ==
                                          _selectedClassSection),
                              orElse: () => _teacherSubjects.isNotEmpty
                                  ? _teacherSubjects.first
                                  : <String, dynamic>{},
                            );
                            CreateAssessmentFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialSubject: _selectedSubject,
                              initialOfferingId: offeringMatch['id']
                                  ?.toString(),
                              initialOfferings: _teacherSubjects,
                              initialIsExam: false,
                              skipTypeSelection: true,
                              repository: widget.repository,
                              onAssessmentCreated: () async {
                                await widget.onRefresh?.call();
                                if (mounted) setState(() {});
                              },
                            );
                          },
                          isSmall: true,
                        ),
                      ],
                    ),
                  ),
                  _KeepAliveTabWrapper(
                    child: _buildUnifiedCategoryView(
                      label: 'Performance Tasks',
                      items: performanceTasks,
                      emptyTitle: 'No performance tasks yet',
                      emptyMessage: 'Create hands-on tasks, portfolios, and graded projects.',
                      icon: LucideIcons.presentation,
                      actionButtons: [
                        AppButton.primary(
                          label: 'Create Performance Task',
                          icon: Icons.add_task,
                          onPressed: () {
                            final sectionParam = _selectedClassSection ?? '';
                            final offeringMatch = _teacherSubjects.firstWhere(
                              (s) =>
                                  (_selectedSubject == null ||
                                      s['subject_name'] == _selectedSubject) &&
                                  (_selectedClassSection == null ||
                                      s['section_name'] ==
                                          _selectedClassSection),
                              orElse: () => _teacherSubjects.isNotEmpty
                                  ? _teacherSubjects.first
                                  : <String, dynamic>{},
                            );
                            CreateRequirementFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialSubject: _selectedSubject,
                              initialOfferingId: offeringMatch['id']
                                  ?.toString(),
                              initialOfferings: _teacherSubjects,
                              isPerformanceTask: true,
                              repository: widget.repository,
                              onRequirementCreated: () {
                                widget.onRefresh?.call();
                                setState(() {});
                              },
                            );
                          },
                          isSmall: true,
                        ),
                      ],
                    ),
                  ),
                  _KeepAliveTabWrapper(
                    child: _buildUnifiedCategoryView(
                      label: 'Examinations',
                      items: examinations,
                      emptyTitle: 'No examinations yet',
                      emptyMessage: _isCurrentSubjectZeroExam
                          ? 'This subject has no Examination component under DepEd Order No. 015, s. 2026. Initial Grades are computed 100% from Written Works and Performance Tasks.'
                          : 'Create Summative Tests (ST1, ST2) and Term Examinations (TE).',
                      icon: LucideIcons.award,
                      isZeroExam: _isCurrentSubjectZeroExam,
                      actionButtons: [
                        AppButton.primary(
                          label: 'Create Examination',
                          icon: Icons.description_outlined,
                          onPressed: () {
                            if (_isCurrentSubjectZeroExam) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This subject has no Examination component under DepEd Order No. 015, s. 2026.',
                                  ),
                                  backgroundColor: AppTheme.catPurple,
                                ),
                              );
                              return;
                            }
                            final sectionParam = _selectedClassSection ?? '';
                            final offeringMatch = _teacherSubjects.firstWhere(
                              (s) =>
                                  (_selectedSubject == null ||
                                      s['subject_name'] == _selectedSubject) &&
                                  (_selectedClassSection == null ||
                                      s['section_name'] ==
                                          _selectedClassSection),
                              orElse: () => _teacherSubjects.isNotEmpty
                                  ? _teacherSubjects.first
                                  : <String, dynamic>{},
                            );
                            CreateAssessmentFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialSubject: _selectedSubject,
                              initialOfferingId: offeringMatch['id']
                                  ?.toString(),
                              initialOfferings: _teacherSubjects,
                              initialIsExam: true,
                              skipTypeSelection: true,
                              repository: widget.repository,
                              onAssessmentCreated: () async {
                                await widget.onRefresh?.call();
                                if (mounted) setState(() {});
                              },
                            );
                          },
                          isSmall: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedCategoryView({
    required String label,
    required List<Widget> items,
    required String emptyTitle,
    required String emptyMessage,
    required IconData icon,
    required List<Widget> actionButtons,
    bool isZeroExam = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isZeroExam)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.catPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.catPurple.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.catPurple,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DepEd Order No. 015, s. 2026 — Zero-Exam Subject',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.catPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This subject has no Examination component. Initial Grades are computed 100% from Written Works and Performance Tasks.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: actionButtons,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.isLoading && items.isEmpty
              ? ListView.builder(
                  itemCount: 4,
                  itemBuilder: (_, _) => const ShimmerClassworkCard(),
                )
              : _PaginatedUnifiedItemList(
                  items: items,
                  emptyTitle: emptyTitle,
                  emptyMessage: emptyMessage,
                  icon: icon,
                  pageSize: 5,
                ),
        ),
      ],
    );
  }

  Widget _buildUnifiedActivityCard(ActivityModel item, String category) {
    final dueDate = item.deadlineForSection(_selectedClassSection ?? '');
    final isOnline = item.completionMode == 'online';
    final effectiveInstructions = item.instructions.trim().isNotEmpty
        ? item.instructions.trim()
        : item.description.trim();

    return _buildUnifiedCard(
      title: item.title,
      description: effectiveInstructions,
      category: category,
      details: isOnline
          ? '${item.section} • Term ${item.termNumber} • ${item.maxScore.toInt()} pts • Due ${_monthName(dueDate.month)} ${dueDate.day}, ${_formatTime(dueDate)}'
          : '${item.section} • Term ${item.termNumber} • ${item.maxScore.toInt()} pts • In-Person (${_monthName(dueDate.month)} ${dueDate.day}, ${dueDate.year})',
      icon: Icons.assignment_outlined,
      onPressed: () {
        if (widget.onViewSubmissions != null) {
          widget.onViewSubmissions!(item);
        }
      },
      actionLabel: isOnline ? 'View Submissions' : 'Record Scores',
      onEdit: () => _showEditActivityModal(item),
      onDelete: () => _confirmDeleteActivity(item),
    );
  }

  Widget _buildUnifiedAssessmentCard(QuizOrExamModel item, String category) {
    final isInPerson = item.completionMode == 'in_person';
    final examEndTime = item.scheduleDate.add(
      Duration(minutes: item.durationMinutes),
    );
    final isTestingFinished = DateTime.now().isAfter(examEndTime);

    return _buildUnifiedCard(
      title: item.title,
      description: item.description,
      category: category,
      details: isInPerson
          ? '${item.section} • Term ${item.termNumber} • ${item.totalPoints.toInt()} pts • In-Person (${_monthName(item.scheduleDate.month)} ${item.scheduleDate.day}, ${item.scheduleDate.year})'
          : '${item.section} • Term ${item.termNumber} • ${item.totalPoints.toInt()} pts • Start ${_monthName(item.scheduleDate.month)} ${item.scheduleDate.day}, ${_formatTime(item.scheduleDate)}',
      icon: item.isExam ? Icons.description_outlined : Icons.quiz_outlined,
      resultsReleased: isInPerson ? null : item.resultsReleased,
      onToggleReleaseKey: isInPerson ? null : () => _toggleResultsReleased(item),
      onPressed: isInPerson
          ? () {
              if (widget.onViewSubmissions != null) {
                widget.onViewSubmissions!(
                  ActivityModel(
                    id: item.id,
                    title: item.title,
                    description: item.description,
                    instructions: item.description,
                    subject: item.subject,
                    section: item.section,
                    deadline: item.scheduleDate,
                    maxScore: item.totalPoints,
                    isPublished: item.isPublished,
                    isRequirement: false,
                    subjectOfferingId: item.subjectOfferingId,
                    termNumber: item.termNumber,
                    gradebookColumnIndex: item.gradebookColumnIndex,
                    completionMode: 'in_person',
                    gradingCategory: item.isExam ? 'ex' : 'ww',
                  ),
                );
              }
            }
          : () {
              AppModals.showUpcomingFeatureDialog(
                context,
                featureName: 'Assessment Score Summary',
              );
            },
      actionLabel: isInPerson ? 'Record Scores' : 'View Scores (Next Update)',
      onEdit: () => EditAssessmentFlowDialog.show(
        context,
        assessment: item,
        onAssessmentUpdated: () async {
          await widget.onRefresh?.call();
          if (mounted) setState(() {});
        },
      ),
      onDelete: () => _confirmDeleteAssessment(item),
      onReschedule: () => _showRescheduleAssessmentDialog(item),
      onProctor: isInPerson
          ? null
          : () => LiveProctorMonitorModal.show(
              context: context,
              assessmentId: item.id,
              assessmentTitle: item.title,
              section: item.section,
            ),
      isItemAnalysisLocked: !isTestingFinished,
      onItemAnalysis: isInPerson
          ? null
          : () {
              if (!isTestingFinished) {
                AppModals.showWarningDialog(
                  context: context,
                  title: 'Item Analysis Locked',
                  message:
                      'Under DepEd assessment standards, Item Analysis and difficulty index computation are finalized after the testing window concludes to ensure sample integrity.\n\nTesting Window Closes: ${_monthName(examEndTime.month)} ${examEndTime.day}, ${_formatTime(examEndTime)}.',
                );
                return;
              }
              _showItemAnalysisDialog(item);
            },
    );
  }

  Future<void> _toggleResultsReleased(QuizOrExamModel item) async {
    final newStatus = !item.resultsReleased;
    try {
      final client = SupabaseService().client;
      await client
          .from('digital_assessments')
          .update({'results_released': newStatus})
          .eq('id', item.id);

      setState(() {
        final index = widget.assessments.indexWhere((a) => a.id == item.id);
        if (index != -1) {
          widget.assessments[index] = item.copyWith(resultsReleased: newStatus);
        }
      });

      if (!mounted) return;
      if (newStatus) {
        AppModals.showSuccessDialog(
          context: context,
          title: 'Answer Key Released',
          message:
              'The answer key for "${item.title}" has been released! Students can now review their responses, see which questions they got right or wrong, and inspect the official answers.',
        );
      } else {
        AppModals.showSuccessDialog(
          context: context,
          title: 'Answer Key Retracted',
          message:
              'Answer key access for "${item.title}" has been hidden. Students will see their submission status as pending teacher evaluation.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Update Failed',
          message: 'Failed to update answer key release state: $e',
        );
      }
    }
  }

  Widget _buildUnifiedCard({
    required String title,
    required String description,
    required String category,
    required String details,
    required IconData icon,
    required VoidCallback onPressed,
    required String actionLabel,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onReschedule,
    VoidCallback? onProctor,
    VoidCallback? onItemAnalysis,
    bool? resultsReleased,
    VoidCallback? onToggleReleaseKey,
    bool isItemAnalysisLocked = false,
  }) {
    final theme = Theme.of(context);
    final isPerformanceTask = category == 'PT';
    final isExam = category == 'EX';
    final badgeBackground = isPerformanceTask
        ? AppTheme.catGreen.withValues(alpha: 0.1)
        : isExam
        ? AppTheme.catPurple.withValues(alpha: 0.1)
        : AppTheme.catBlue.withValues(alpha: 0.1);
    final badgeText = isPerformanceTask
        ? AppTheme.catGreen
        : isExam
        ? AppTheme.catPurple
        : AppTheme.catBlue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAssessmentCategoryBadge(
                      category,
                      badgeBackground,
                      badgeText,
                    ),
                    if (resultsReleased != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: resultsReleased
                              ? AppTheme.catGreen.withValues(alpha: 0.12)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: resultsReleased
                                ? AppTheme.catGreen.withValues(alpha: 0.3)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              resultsReleased
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 12,
                              color: resultsReleased
                                  ? AppTheme.catGreen
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              resultsReleased ? 'Key Released' : 'Key Hidden',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: resultsReleased
                                    ? AppTheme.catGreen
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  ExpandableInstructionsText(
                    text: description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 4,
            children: [
              AppButton.outline(
                label: actionLabel,
                icon: Icons.open_in_new,
                isSmall: true,
                onPressed: onPressed,
              ),
              if (onToggleReleaseKey != null && resultsReleased != null)
                IconButton(
                  tooltip: resultsReleased
                      ? 'Answer Key: Released (Visible to students) — Tap to Hide'
                      : 'Answer Key: Hidden from students — Tap to Release',
                  icon: Icon(
                    resultsReleased
                        ? Icons.visibility
                        : Icons.visibility_off_outlined,
                    color: resultsReleased
                        ? AppTheme.catGreen
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  onPressed: onToggleReleaseKey,
                ),
              if (onProctor != null)
                IconButton(
                  tooltip: 'Live Proctoring Monitor',
                  icon: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.catPurple,
                  ),
                  onPressed: onProctor,
                ),
              if (onItemAnalysis != null)
                IconButton(
                  tooltip: isItemAnalysisLocked
                      ? 'Item Analysis Locked (Exam window active)'
                      : 'Item Analysis & DepEd Tiers',
                  icon: Icon(
                    isItemAnalysisLocked
                        ? Icons.lock_clock_outlined
                        : Icons.analytics_outlined,
                    color: isItemAnalysisLocked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                        : AppTheme.catTeal,
                  ),
                  onPressed: onItemAnalysis,
                ),
              if (onReschedule != null)
                IconButton(
                  tooltip: 'Update Schedule',
                  icon: Icon(Icons.schedule, color: theme.colorScheme.primary),
                  onPressed: onReschedule,
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit',
                  icon: Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.catRed,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showItemAnalysisDialog(QuizOrExamModel item) async {
    try {
      final client = SupabaseService().client;
      // Fetch real assessment questions from database
      final questionsResponse = await client
          .from('assessment_questions')
          .select('id, question_text, position')
          .eq('assessment_id', item.id)
          .order('position', ascending: true);

      final questionRows = List<Map<String, dynamic>>.from(
        questionsResponse as List? ?? [],
      );

      // Fetch real submitted attempts for this assessment
      final attemptsResponse = await client
          .from('assessment_attempts')
          .select('id, status')
          .eq('assessment_id', item.id)
          .eq('status', 'submitted');
      final attemptList = List<Map<String, dynamic>>.from(
        attemptsResponse as List? ?? [],
      );
      final totalAttempts = attemptList.length;

      final stats = <ItemDifficultyStat>[];

      if (questionRows.isNotEmpty) {
        final qIds = questionRows.map((q) => q['id'].toString()).toList();
        final responsesData = totalAttempts > 0
            ? await client
                  .from('assessment_responses')
                  .select('question_id, is_correct')
                  .inFilter('question_id', qIds)
            : [];
        final responseList = List<Map<String, dynamic>>.from(
          responsesData as List? ?? [],
        );

        for (int i = 0; i < questionRows.length; i++) {
          final q = questionRows[i];
          final qId = q['id'].toString();
          final qResponses = responseList.where(
            (r) => r['question_id']?.toString() == qId,
          );
          final correctCount = qResponses
              .where((r) => r['is_correct'] == true)
              .length;

          stats.add(
            ItemDifficultyStat(
              itemNumber: (q['position'] as num?)?.toInt() ?? (i + 1),
              questionText:
                  q['question_text']?.toString() ?? 'Question ${i + 1}',
              totalAttempts: totalAttempts,
              correctCount: correctCount,
            ),
          );
        }
      } else if (item.questions.isNotEmpty) {
        for (int i = 0; i < item.questions.length; i++) {
          final q = item.questions[i];
          stats.add(
            ItemDifficultyStat(
              itemNumber: i + 1,
              questionText: q.questionText,
              totalAttempts: totalAttempts,
              correctCount: 0,
            ),
          );
        }
      }

      if (!mounted) return;

      ItemAnalysisModal.show(
        context,
        assessmentTitle: item.title,
        stats: stats,
        initialResultsReleased: item.resultsReleased,
        onToggleRelease: (released) async {
          try {
            await client
                .from('digital_assessments')
                .update({'results_released': released})
                .eq('id', item.id);
            if (mounted) {
              setState(() {
                final index = widget.assessments.indexWhere((a) => a.id == item.id);
                if (index != -1) {
                  widget.assessments[index] = item.copyWith(resultsReleased: released);
                }
              });
            }
          } catch (_) {}
        },
      );
    } catch (e) {
      debugPrint('Item analysis query notice: $e');
      if (mounted) {
        ItemAnalysisModal.show(
          context,
          assessmentTitle: item.title,
          stats: item.questions
              .asMap()
              .entries
              .map(
                (e) => ItemDifficultyStat(
                  itemNumber: e.key + 1,
                  questionText: e.value.questionText,
                  totalAttempts: 0,
                  correctCount: 0,
                ),
              )
              .toList(),
          initialResultsReleased: item.resultsReleased,
          onToggleRelease: (released) async {},
        );
      }
    }
  }

  Widget _buildAssessmentCategoryBadge(
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteActivity(ActivityModel item) async {
    bool hasRecords = false;
    try {
      final client = SupabaseService().client;
      // 1. Check student submissions for existing scores or submitted work
      final submissions = await client
          .from('student_classwork_submissions')
          .select('id, score, status')
          .eq('classwork_id', item.id);
      final subList = List<Map<String, dynamic>>.from(
        submissions as List? ?? [],
      );
      for (final s in subList) {
        if (s['score'] != null ||
            s['status'] == 'graded' ||
            s['status'] == 'submitted') {
          hasRecords = true;
          break;
        }
      }

      // 2. Also check Gradebook sheet if subjectOfferingId and gradebookColumnIndex exist
      if (!hasRecords &&
          item.subjectOfferingId != null &&
          item.gradebookColumnIndex != null) {
        final term = item.termNumber > 0 ? item.termNumber : 1;
        final termSheet =
            await SubjectRepository.instance.getGradebookTermSheet(
              item.subjectOfferingId!,
              term,
            );
        if (termSheet != null && termSheet['scores'] is Map) {
          final scoresMap = termSheet['scores'] as Map;
          final catKey = item.effectiveGradingCategory;
          final colKey = item.gradebookColumnIndex.toString();
          for (final studentVal in scoresMap.values) {
            if (studentVal is Map && studentVal[catKey] is Map) {
              final catScores = studentVal[catKey] as Map;
              final usesZeroBased =
                  catScores.containsKey('0') || catScores.containsKey(0);
              final targetKey = usesZeroBased
                  ? (item.gradebookColumnIndex! - 1).toString()
                  : colKey;
              if (catScores[targetKey] != null) {
                hasRecords = true;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Notice checking activity score records: $e');
    }

    if (!mounted) return;

    if (hasRecords) {
      AppModals.showWarningDialog(
        context: context,
        title: 'Cannot Delete Item',
        message:
            'This classwork activity already has recorded student scores or submissions. Items with existing student records cannot be deleted.',
      );
      return;
    }

    _showDeleteConfirmation(
      title: item.title,
      onDelete: () async {
        setState(() {
          _isSyncing = true;
          widget.activities.removeWhere((a) => a.id == item.id);
        });
        if (widget.repository != null) {
          try {
            await widget.repository!.deleteActivity(item.id);
          } catch (_) {}
        }
        TeacherGradebookTab.gradebookRefreshNotifier.value++;
        if (mounted) {
          await widget.onRefresh?.call();
          setState(() => _isSyncing = false);
        }
      },
    );
  }

  Future<void> _confirmDeleteAssessment(QuizOrExamModel item) async {
    bool hasRecords = false;
    Map<String, dynamic>? classworkRow;
    try {
      final client = SupabaseService().client;
      // 1. Check assessment_attempts for submitted or scored attempts
      final attempts = await client
          .from('assessment_attempts')
          .select('id, score_earned, status')
          .eq('assessment_id', item.id);
      final attemptList = List<Map<String, dynamic>>.from(
        attempts as List? ?? [],
      );
      for (final a in attemptList) {
        if (a['score_earned'] != null ||
            a['status'] == 'submitted' ||
            a['status'] == 'auto_submitted') {
          hasRecords = true;
          break;
        }
      }

      // 2. Check classwork submissions if item exists in classwork_items
      classworkRow = await client
          .from('classwork_items')
          .select(
            'id, subject_offering_id, term_number, gradebook_column_index, grading_category',
          )
          .eq('id', item.id)
          .maybeSingle();

      if (!hasRecords && classworkRow != null) {
        final subs = await client
            .from('student_classwork_submissions')
            .select('id, score, status')
            .eq('classwork_id', item.id);
        final subList = List<Map<String, dynamic>>.from(subs as List? ?? []);
        for (final s in subList) {
          if (s['score'] != null ||
              s['status'] == 'graded' ||
              s['status'] == 'submitted') {
            hasRecords = true;
            break;
          }
        }
      }

      // 3. Check Gradebook sheet scores as Single Source of Truth
      final offeringId =
          classworkRow?['subject_offering_id']?.toString() ??
          item.subjectOfferingId;
      final termNumber =
          (classworkRow?['term_number'] as num?)?.toInt() ?? item.termNumber;
      final colIdx =
          (classworkRow?['gradebook_column_index'] as num?)?.toInt() ??
          item.gradebookColumnIndex;
      final category =
          classworkRow?['grading_category']?.toString().toLowerCase() ??
          (item.isExam ? 'ex' : 'ww');

      if (!hasRecords && offeringId != null && colIdx != null) {
        final termSheet =
            await SubjectRepository.instance.getGradebookTermSheet(
              offeringId,
              termNumber,
            );
        if (termSheet != null && termSheet['scores'] is Map) {
          final scoresMap = termSheet['scores'] as Map;
          final colKey = category == 'ex'
              ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
              : colIdx.toString();
          for (final studentVal in scoresMap.values) {
            if (studentVal is Map && studentVal[category] is Map) {
              final catScores = studentVal[category] as Map;
              final usesZeroBased =
                  catScores.containsKey('0') || catScores.containsKey(0);
              final altKey = usesZeroBased
                  ? (colIdx - 1).toString()
                  : colIdx.toString();
              if (catScores[colKey] != null || catScores[altKey] != null) {
                hasRecords = true;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Notice checking assessment records: $e');
    }

    if (!mounted) return;

    if (hasRecords) {
      AppModals.showWarningDialog(
        context: context,
        title: 'Cannot Delete ${item.isExam ? 'Examination' : 'Quiz'}',
        message:
            'This ${item.isExam ? 'examination' : 'quiz'} already has recorded student attempts or scores. Items with existing student records cannot be deleted.',
      );
      return;
    }

    _showDeleteConfirmation(
      title: item.title,
      onDelete: () async {
        setState(() => _isSyncing = true);
        try {
          final client = SupabaseService().client;
          // Remove any unsubmitted/abandoned attempt rows first (FK RESTRICT)
          final openAttempts = await client
              .from('assessment_attempts')
              .select('id')
              .eq('assessment_id', item.id);
          final openIds = List<Map<String, dynamic>>.from(
            openAttempts as List? ?? [],
          ).map((e) => e['id'].toString()).toList();
          if (openIds.isNotEmpty) {
            await client
                .from('assessment_responses')
                .delete()
                .inFilter('attempt_id', openIds);
            await client
                .from('assessment_attempts')
                .delete()
                .inFilter('id', openIds);
          }

          await client
              .from('student_classwork_submissions')
              .delete()
              .eq('classwork_id', item.id);

          // Delete questions (cascade cleans up question_options)
          await client
              .from('assessment_questions')
              .delete()
              .eq('assessment_id', item.id);
          // Hard delete from classwork_items
          await client.from('classwork_items').delete().eq('id', item.id);
          // Hard delete from digital_assessments
          await client.from('digital_assessments').delete().eq('id', item.id);

          // Clean up HPS from gradebook_term_sheets
          final offeringId =
              classworkRow?['subject_offering_id']?.toString() ??
              item.subjectOfferingId;
          final colIdx =
              (classworkRow?['gradebook_column_index'] as num?)?.toInt() ??
              item.gradebookColumnIndex;
          final termNum =
              (classworkRow?['term_number'] as num?)?.toInt() ??
              item.termNumber;
          final categoryKey =
              classworkRow?['grading_category']?.toString().toLowerCase() ??
              (item.isExam ? 'ex' : 'ww');

          if (offeringId != null && colIdx != null) {
            final termSheet =
                await SubjectRepository.instance.getGradebookTermSheet(
                  offeringId,
                  termNum,
                );
            if (termSheet != null && termSheet['hps'] is Map) {
              final hps = Map<String, dynamic>.from(termSheet['hps'] as Map);
              if (hps[categoryKey] is Map) {
                final catHps = Map<String, dynamic>.from(
                  hps[categoryKey] as Map,
                );
                final colKey = categoryKey == 'ex'
                    ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
                    : colIdx.toString();
                catHps.remove(colKey);
                if (categoryKey == 'ex') {
                  catHps.remove(colIdx.toString());
                }
                hps[categoryKey] = catHps;
                termSheet['hps'] = hps;
                await SubjectRepository.instance.saveGradebookTermSheet(
                  offeringId,
                  termNum,
                  termSheet,
                );
              }
            }
            try {
              await LocalStorageService.clearGradebookSheet(offeringId, termNum);
            } catch (_) {}
          }

          // Clear caches & notify gradebook + student portal
          AppDataCache.instance.invalidatePrefix('gradebook_');
          AppDataCache.instance.invalidatePrefix('teacher_assessments_');
          AppDataCache.instance.invalidatePrefix('teacher_activities_');
          AppDataCache.instance.invalidatePrefix('student_dashboard_');
          TeacherGradebookTab.gradebookRefreshNotifier.value++;
        } catch (e) {
          debugPrint('Error deleting assessment: $e');
        }

        if (mounted) {
          setState(() {
            widget.assessments.removeWhere((q) => q.id == item.id);
          });
          await widget.onRefresh?.call();
          setState(() => _isSyncing = false);
        }
      },
    );
  }

  Future<void> _showRescheduleAssessmentDialog(QuizOrExamModel item) async {
    final isInPerson = item.completionMode == 'in_person';
    final localOrig = item.scheduleDate.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime selectedDate = DateTime(
      localOrig.year,
      localOrig.month,
      localOrig.day,
    );
    if (!isInPerson && selectedDate.isBefore(today)) {
      selectedDate = today;
    }
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(localOrig);
    bool isSavingSchedule = false;

    String? computeTimeError(DateTime date, TimeOfDay time) {
      if (isInPerson) return null;
      final candidate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!candidate.isAfter(DateTime.now())) {
        return 'Updated schedule must be in the future.';
      }
      return null;
    }

    String? scheduleTimeError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final theme = Theme.of(modalCtx);
          final candidateCombined = isInPerson
              ? DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  23,
                  59,
                )
              : DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
          final isUnchanged = isSameClassworkSchedule(
            item.scheduleDate,
            candidateCombined,
            isInPerson: isInPerson,
          );
          final isSelectedToday =
              selectedDate.year == today.year &&
              selectedDate.month == today.month &&
              selectedDate.day == today.day;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_repeat,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isInPerson ? 'Update Date' : 'Update Schedule',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInPerson
                        ? 'Update the scheduled date for "${item.title}".'
                        : 'Set a new testing window for "${item.title}".',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8A48).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0F8A48).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: Color(0xFF0F8A48),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isInPerson
                                ? 'Current Date: ${localOrig.month.toString().padLeft(2, '0')}/${localOrig.day.toString().padLeft(2, '0')}/${localOrig.year}'
                                : 'Current Schedule: ${localOrig.month.toString().padLeft(2, '0')}/${localOrig.day.toString().padLeft(2, '0')}/${localOrig.year} ${_formatTime(localOrig)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F8A48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isInPerson ? 'Update Date *' : 'Update Schedule Date *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isSavingSchedule
                        ? null
                        : () async {
                            final tNow = DateTime.now();
                            final tToday = DateTime(
                              tNow.year,
                              tNow.month,
                              tNow.day,
                            );
                            final pickedDate = await showAppDatePickerDialog(
                              ctx,
                              initialDate: selectedDate,
                              firstDate: isInPerson
                                  ? DateTime(tToday.year - 1, 1, 1)
                                  : tToday,
                              lastDate: DateTime(tToday.year + 5, 12, 31),
                              title: isInPerson
                                  ? 'Update Date'
                                  : 'Update Schedule',
                              icon: Icons.event_available_outlined,
                              highlightDate: localOrig,
                              highlightLabel: isInPerson
                                  ? 'Current Date'
                                  : 'Current Schedule',
                            );
                            if (pickedDate != null && ctx.mounted) {
                              setModalState(() {
                                selectedDate = pickedDate;
                                scheduleTimeError = computeTimeError(
                                  selectedDate,
                                  selectedTime,
                                );
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: Color(0xFF0F8A48),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  if (!isInPerson) ...[
                    const SizedBox(height: 14),
                    AppTimePickerField(
                      key: ValueKey(
                        '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}-${selectedTime.hour}-${selectedTime.minute}',
                      ),
                      label: 'Start Time *',
                      initialTime: selectedTime,
                      minTime: isSelectedToday
                          ? TimeOfDay.fromDateTime(
                              DateTime.now().add(const Duration(minutes: 1)),
                            )
                          : null,
                      onTimeSelected: (pickedTime) {
                        setModalState(() {
                          selectedTime = pickedTime;
                          scheduleTimeError = computeTimeError(
                            selectedDate,
                            selectedTime,
                          );
                        });
                      },
                    ),
                  ],
                  if (scheduleTimeError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      scheduleTimeError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (isUnchanged) ...[
                    const SizedBox(height: 8),
                    Text(
                      isInPerson
                          ? 'Select a different date to update.'
                          : 'Select a different date or time to update the schedule.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingSchedule ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    (isSavingSchedule ||
                        isUnchanged ||
                        scheduleTimeError != null)
                    ? null
                    : () async {
                        final recheckErr = computeTimeError(
                          selectedDate,
                          selectedTime,
                        );
                        if (recheckErr != null) {
                          setModalState(() => scheduleTimeError = recheckErr);
                          return;
                        }
                        setModalState(() => isSavingSchedule = true);
                        try {
                          final client = SupabaseService().client;
                          final existing = await client
                              .from(
                                isInPerson
                                    ? 'classwork_items'
                                    : 'digital_assessments',
                              )
                              .select('id')
                              .eq('id', item.id)
                              .eq('is_archived', false)
                              .maybeSingle();

                          if (existing == null) {
                            AppDataCache.instance.invalidatePrefix(
                              'teacher_assessments_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'teacher_activities_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'student_dashboard_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'gradebook_',
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              await widget.onRefresh?.call();
                              if (mounted) {
                                await AppModals.showWarningDialog(
                                  context: context,
                                  title: 'Assessment Removed',
                                  message:
                                      'This assessment has already been deleted from the database and can no longer be updated.',
                                );
                              }
                            }
                            return;
                          }

                          if (isInPerson) {
                            await client
                                .from('classwork_items')
                                .update({
                                  'deadline': candidateCombined
                                      .toUtc()
                                      .toIso8601String(),
                                })
                                .eq('id', item.id);
                          } else {
                            final endUtc = candidateCombined
                                .add(Duration(minutes: item.durationMinutes))
                                .toUtc()
                                .toIso8601String();
                            await client
                                .from('digital_assessments')
                                .update({
                                  'available_from': candidateCombined
                                      .toUtc()
                                      .toIso8601String(),
                                  'deadline': endUtc,
                                })
                                .eq('id', item.id);

                            await client
                                .from('classwork_items')
                                .update({'deadline': endUtc})
                                .eq('id', item.id);
                          }

                          AppDataCache.instance.invalidatePrefix(
                            'teacher_assessments_',
                          );
                          AppDataCache.instance.invalidatePrefix(
                            'teacher_activities_',
                          );
                          AppDataCache.instance.invalidatePrefix(
                            'student_dashboard_',
                          );
                          AppDataCache.instance.invalidatePrefix('gradebook_');
                          TeacherGradebookTab.gradebookRefreshNotifier.value++;

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() => _isSyncing = true);
                            await widget.onRefresh?.call();
                            if (mounted) {
                              setState(() => _isSyncing = false);
                              await AppModals.showSuccessDialog(
                                context: context,
                                title: isInPerson
                                    ? 'Date Updated'
                                    : 'Schedule Updated',
                                message: isInPerson
                                    ? 'Scheduled date updated for "${item.title}".'
                                    : 'Schedule updated for "${item.title}". Window opens on ${candidateCombined.month}/${candidateCombined.day}/${candidateCombined.year} at ${_formatTime(candidateCombined)}.',
                              );
                            }
                          }
                        } catch (e) {
                          setModalState(() => isSavingSchedule = false);
                          if (mounted) {
                            await AppModals.showErrorDialog(
                              context: context,
                              title: 'Update Failed',
                              message: 'Could not update schedule: $e',
                            );
                          }
                        }
                      },
                child: isSavingSchedule
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isInPerson ? 'Save New Date' : 'Save New Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation({
    required String title,
    required VoidCallback onDelete,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?\n\n$title'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              onDelete();
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditActivityModal(ActivityModel item) {
    CreateRequirementFlowDialog.show(
      context,
      existingTask: item,
      initialSection: item.assignedSections.isNotEmpty
          ? item.assignedSections.first
          : '',
      initialSubject: item.subject,
      initialOfferingId: item.subjectOfferingId,
      initialOfferings: _teacherSubjects,
      isPerformanceTask: item.isRequirement,
      repository: widget.repository,
      onRequirementCreated: () async {
        setState(() => _isSyncing = true);
        try {
          final res = widget.onRefresh?.call();
          if (res is Future) {
            await res;
          }
        } finally {
          if (mounted) {
            setState(() => _isSyncing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Classwork updated and synced with gradebook successfully.',
                ),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFF0F8A48),
              ),
            );
          }
        }
      },
    );
  }
}

class _PaginatedUnifiedItemList extends StatefulWidget {
  final List<Widget> items;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;
  final int pageSize;

  const _PaginatedUnifiedItemList({
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.icon,
    this.pageSize = 5,
  });

  @override
  State<_PaginatedUnifiedItemList> createState() =>
      _PaginatedUnifiedItemListState();
}

class _PaginatedUnifiedItemListState extends State<_PaginatedUnifiedItemList> {
  int _visibleCount = 5;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pageSize;
  }

  @override
  void didUpdateWidget(covariant _PaginatedUnifiedItemList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _visibleCount = widget.pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final effectiveVisible = min(_visibleCount, widget.items.length);
    final visibleItems = widget.items.take(effectiveVisible).toList();
    final hasMore = effectiveVisible < widget.items.length;

    return ListView(
      children: [
        for (int i = 0; i < visibleItems.length; i++) ...[
          visibleItems[i],
          if (i < visibleItems.length - 1) const SizedBox(height: 12),
        ],
        if (hasMore) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'Showing $effectiveVisible of ${widget.items.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton.outline(
                  label:
                      'Load More (Scroll to show ${widget.items.length - effectiveVisible} remaining)',
                  icon: LucideIcons.chevronDown,
                  isSmall: true,
                  onPressed: () {
                    setState(() {
                      _visibleCount += widget.pageSize;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCheck,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'All ${widget.items.length} items loaded',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _KeepAliveTabWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveTabWrapper({required this.child});

  @override
  State<_KeepAliveTabWrapper> createState() => _KeepAliveTabWrapperState();
}

class _KeepAliveTabWrapperState extends State<_KeepAliveTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
