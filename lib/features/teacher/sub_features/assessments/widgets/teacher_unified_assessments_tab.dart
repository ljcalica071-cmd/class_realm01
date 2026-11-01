import 'dart:math';
import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
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
  final VoidCallback? onRefresh;
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
      if (_selectedGrade == null || _parseGrade(s['grade_level']) == _selectedGrade) {
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
      final matchesGrade = _selectedGrade == null || _parseGrade(s['grade_level']) == _selectedGrade;
      final matchesSubject = _selectedSubject == null || (s['subject_name']?.toString().trim() == _selectedSubject);
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
      final subjects = await SubjectRepository.instance.getTeacherSubjects(teacherId);
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
          (_selectedClassSection == null || s['section_name'] == _selectedClassSection),
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

  bool _matchesItem(String? itemSubject, String? itemSection, List<String> assignedSections) {
    // If user has chosen a section
    if (_selectedClassSection != null && _selectedClassSection!.isNotEmpty) {
      final matchesSection = (itemSection != null && itemSection.contains(_selectedClassSection!)) ||
          assignedSections.contains(_selectedClassSection!);
      if (!matchesSection) return false;
    }
    // If user has chosen a subject
    if (_selectedSubject != null && _selectedSubject!.isNotEmpty && itemSubject != null && itemSubject.isNotEmpty) {
      if (!itemSubject.toLowerCase().contains(_selectedSubject!.toLowerCase()) &&
          !_selectedSubject!.toLowerCase().contains(itemSubject.toLowerCase())) {
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right-aligned Target Filter Card matching Learning Materials
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
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
                                  .map((g) => DropdownMenuItem(value: g, child: Text('Grade $g')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedGrade = val;
                                    final subs = _availableSubjects;
                                    _selectedSubject = subs.isNotEmpty ? subs.first : null;
                                    final secs = _availableSections;
                                    _selectedClassSection = secs.isNotEmpty ? secs.first : null;
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: availableSubjects.contains(_selectedSubject)
                                  ? _selectedSubject
                                  : availableSubjects.first,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                              items: availableSubjects
                                  .map((sub) => DropdownMenuItem(
                                        value: sub,
                                        child: Text(sub, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSubject = val;
                                    final secs = _availableSections;
                                    _selectedClassSection = secs.isNotEmpty ? secs.first : null;
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: availableSections.contains(_selectedClassSection)
                                  ? _selectedClassSection
                                  : availableSections.first,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                              items: availableSections
                                  .map((sec) => DropdownMenuItem(
                                        value: sec,
                                        child: Text(_formatSectionName(sec), overflow: TextOverflow.ellipsis),
                                      ))
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
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                        AppButton.secondary(
                          label: 'Create Activity',
                          icon: Icons.assignment_outlined,
                          onPressed: () {
                            final sectionParam = _selectedClassSection ?? '';
                            final offeringMatch = _teacherSubjects.firstWhere(
                              (s) =>
                                  (_selectedSubject == null || s['subject_name'] == _selectedSubject) &&
                                  (_selectedClassSection == null || s['section_name'] == _selectedClassSection),
                              orElse: () => _teacherSubjects.isNotEmpty ? _teacherSubjects.first : <String, dynamic>{},
                            );
                            CreateRequirementFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialSubject: _selectedSubject,
                              initialOfferingId: offeringMatch['id']?.toString(),
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
                            CreateAssessmentFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialIsExam: false,
                              skipTypeSelection: true,
                              onAssessmentCreated: () {
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
                                  (_selectedSubject == null || s['subject_name'] == _selectedSubject) &&
                                  (_selectedClassSection == null || s['section_name'] == _selectedClassSection),
                              orElse: () => _teacherSubjects.isNotEmpty ? _teacherSubjects.first : <String, dynamic>{},
                            );
                            CreateRequirementFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialSubject: _selectedSubject,
                              initialOfferingId: offeringMatch['id']?.toString(),
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
                            CreateAssessmentFlowDialog.show(
                              context,
                              initialSection: sectionParam,
                              initialIsExam: true,
                              skipTypeSelection: true,
                              onAssessmentCreated: () {
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
              border: Border.all(color: AppTheme.catPurple.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.catPurple, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DepEd Order No. 015, s. 2026 — Zero-Exam Subject',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.catPurple),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This subject has no Examination component. Initial Grades are computed 100% from Written Works and Performance Tasks.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
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
                  pageSize: 20,
                ),
        ),
      ],
    );
  }

  Widget _buildUnifiedActivityCard(ActivityModel item, String category) {
    final dueDate = item.deadlineForSection(_selectedClassSection ?? '');
    final isOnline = item.completionMode == 'online';
    
    return _buildUnifiedCard(
      title: item.title,
      description: item.isRequirement ? '' : item.description,
      category: category,
      details: item.isRequirement
          ? '${item.section} • Term ${item.termNumber} • ${item.maxScore.toInt()} pts${isOnline ? ' • Due ${_monthName(dueDate.month)} ${dueDate.day}, ${_formatTime(dueDate)}' : ' • In-Person'}'
          : '${item.section} • Term ${item.termNumber} • ${item.maxScore.toInt()} pts${isOnline ? ' • Due ${_monthName(dueDate.month)} ${dueDate.day}' : ' • In-Person'}',
      icon: Icons.assignment_outlined,
      onPressed: isOnline 
          ? () {
              if (widget.onViewSubmissions != null) {
                widget.onViewSubmissions!(item);
              }
            } 
          : () {
              // In-Person -> Open Edit or Gradebook
              if (widget.onViewSubmissions != null) {
                widget.onViewSubmissions!(item);
              }
            },
      actionLabel: 'View Submissions',
      onEdit: () => _showEditActivityModal(item),
      onDelete: category == 'EX' ? null : () => _confirmDeleteActivity(item),
    );
  }

  Widget _buildUnifiedAssessmentCard(QuizOrExamModel item, String category) {
    return _buildUnifiedCard(
      title: item.title,
      description: item.description,
      category: category,
      details:
          '${item.section} • ${item.totalPoints.toInt()} pts • Start ${_monthName(item.scheduleDate.month)} ${item.scheduleDate.day}, ${_formatTime(item.scheduleDate)}',
      icon: item.isExam ? Icons.description_outlined : Icons.quiz_outlined,
      onPressed: () {},
      actionLabel: 'View Scores',
      onEdit: () => EditAssessmentFlowDialog.show(
        context,
        assessment: item,
        onAssessmentUpdated: () => setState(() {}),
      ),
      onDelete: (item.isExam || category == 'EX') ? null : () => _confirmDeleteAssessment(item),
      onReschedule: () => _showRescheduleAssessmentDialog(item),
      onProctor: () => LiveProctorMonitorModal.show(
        context: context,
        assessmentId: item.id,
        assessmentTitle: item.title,
        section: item.section,
      ),
      onItemAnalysis: () => _showItemAnalysisDialog(item),
    );
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
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
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
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
              if (onProctor != null)
                IconButton(
                  tooltip: 'Live Proctoring Monitor',
                  icon: const Icon(Icons.shield_outlined, color: AppTheme.catPurple),
                  onPressed: onProctor,
                ),
              if (onItemAnalysis != null)
                IconButton(
                  tooltip: 'Item Analysis & DepEd Tiers',
                  icon: const Icon(Icons.analytics_outlined, color: AppTheme.catTeal),
                  onPressed: onItemAnalysis,
                ),
              if (onReschedule != null)
                IconButton(
                  tooltip: 'Reschedule / Make-up Test',
                  icon: Icon(Icons.schedule, color: theme.colorScheme.primary),
                  onPressed: onReschedule,
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit',
                  icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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

      final questionRows = List<Map<String, dynamic>>.from(questionsResponse as List? ?? []);

      // Fetch real submitted attempts for this assessment
      final attemptsResponse = await client
          .from('assessment_attempts')
          .select('id, status')
          .eq('assessment_id', item.id)
          .eq('status', 'submitted');
      final attemptList = List<Map<String, dynamic>>.from(attemptsResponse as List? ?? []);
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
        final responseList = List<Map<String, dynamic>>.from(responsesData as List? ?? []);

        for (int i = 0; i < questionRows.length; i++) {
          final q = questionRows[i];
          final qId = q['id'].toString();
          final qResponses = responseList.where((r) => r['question_id']?.toString() == qId);
          final correctCount = qResponses.where((r) => r['is_correct'] == true).length;

          stats.add(
            ItemDifficultyStat(
              itemNumber: (q['position'] as num?)?.toInt() ?? (i + 1),
              questionText: q['question_text']?.toString() ?? 'Question ${i + 1}',
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
            await client.from('digital_assessments').update({
              'results_released': released,
            }).eq('id', item.id);
          } catch (_) {}
        },
      );
    } catch (e) {
      debugPrint('Item analysis query notice: $e');
      if (mounted) {
        ItemAnalysisModal.show(
          context,
          assessmentTitle: item.title,
          stats: item.questions.asMap().entries.map((e) => ItemDifficultyStat(
            itemNumber: e.key + 1,
            questionText: e.value.questionText,
            totalAttempts: 0,
            correctCount: 0,
          )).toList(),
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

  void _confirmDeleteActivity(ActivityModel item) {
    _showDeleteConfirmation(
      title: item.title,
      onDelete: () async {
        if (widget.repository != null) {
          try {
            await widget.repository!.deleteActivity(item.id);
          } catch (_) {}
        }
        widget.onRefresh?.call();
        setState(() {});
      },
    );
  }

  void _confirmDeleteAssessment(QuizOrExamModel item) {
    _showDeleteConfirmation(
      title: item.title,
      onDelete: () {
        setState(() {
          widget.assessments.removeWhere((q) => q.id == item.id);
        });
        widget.onRefresh?.call();
      },
    );
  }

  void _showRescheduleAssessmentDialog(QuizOrExamModel item) {
    DateTime newDate = item.scheduleDate;
    final isExam = item.isExam;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isExam ? 'Reschedule Exam / Special Test' : 'Reschedule Quiz Window',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assessment: ${item.title}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set a special make-up test window for absent or excused learners:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: newDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(newDate),
                    );
                    if (pickedTime != null) {
                      setModalState(() {
                        newDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${newDate.month}/${newDate.day}/${newDate.year} ${newDate.hour > 12 ? newDate.hour - 12 : newDate.hour}:${newDate.minute.toString().padLeft(2, '0')} ${newDate.hour >= 12 ? 'PM' : 'AM'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Icon(Icons.calendar_month, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Note: In accordance with DepEd guidelines, testing start and end times must fall within the same calendar day.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final client = SupabaseService().client;
                  await client.from('digital_assessments').update({
                    'available_from': newDate.toIso8601String(),
                    'deadline': newDate.add(Duration(minutes: item.durationMinutes)).toIso8601String(),
                  }).eq('id', item.id);

                  await client.from('classwork_items').update({
                    'deadline': newDate.add(Duration(minutes: item.durationMinutes)).toIso8601String(),
                  }).eq('id', item.id);
                } catch (_) {}

                if (!mounted) return;
                AppModals.showSuccessDialog(
                  context: context,
                  title: 'Schedule Updated',
                  message: 'Schedule successfully updated for ${item.title}. Window opens at ${_formatTime(newDate)}.',
                );
                widget.onRefresh?.call();
                setState(() {});
              },
              child: const Text('Save Reschedule'),
            ),
          ],
        ),
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
      onRequirementCreated: () {
        widget.onRefresh?.call();
        setState(() {});
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
    this.pageSize = 20,
  });

  @override
  State<_PaginatedUnifiedItemList> createState() =>
      _PaginatedUnifiedItemListState();
}

class _PaginatedUnifiedItemListState extends State<_PaginatedUnifiedItemList> {
  int _visibleCount = 20;

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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
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

