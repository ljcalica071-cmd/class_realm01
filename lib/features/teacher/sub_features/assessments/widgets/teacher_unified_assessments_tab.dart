import 'dart:math';
import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/data/repositories/supabase_teacher_classwork_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/edit_assessment_flow.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TeacherUnifiedAssessmentsTab extends StatefulWidget {
  final List<ActivityModel> activities;
  final List<QuizOrExamModel> assessments;
  final String selectedClassSection;
  final ValueChanged<ActivityModel>? onViewSubmissions;
  final TeacherClassworkRepository? repository;
  final VoidCallback? onRefresh;

  const TeacherUnifiedAssessmentsTab({
    super.key,
    required this.activities,
    required this.assessments,
    this.selectedClassSection = 'All Sections',
    this.onViewSubmissions,
    this.repository,
    this.onRefresh,
  });

  @override
  State<TeacherUnifiedAssessmentsTab> createState() =>
      _TeacherUnifiedAssessmentsTabState();
}

class _TeacherUnifiedAssessmentsTabState
    extends State<TeacherUnifiedAssessmentsTab> {
  late String _selectedClassSection;
  List<String> _teacherSections = [];

  @override
  void initState() {
    super.initState();
    _selectedClassSection = widget.selectedClassSection;
    _loadTeacherSections();
  }

  Future<void> _loadTeacherSections() async {
    try {
      final teacherId = AuthRepository.instance.currentUser?.id;
      if (teacherId == null) return;
      final subjects = await SubjectRepository.instance.getTeacherSubjects(teacherId);
      final sections = subjects
          .map((s) => s['section_name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _teacherSections = sections;
      });
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool matchAll =
        _selectedClassSection == 'All Sections' || _selectedClassSection.isEmpty;

    final writtenWork = <Widget>[
      ...widget.activities
          .where(
            (item) =>
                !item.isRequirement &&
                (matchAll || item.assignedSections.contains(_selectedClassSection)),
          )
          .map((item) => _buildUnifiedActivityCard(item, 'WW')),
      ...widget.assessments
          .where(
            (item) =>
                !item.isExam &&
                (matchAll || item.assignedSections.contains(_selectedClassSection)),
          )
          .map((item) => _buildUnifiedAssessmentCard(item, 'WW')),
    ];
    final performanceTasks = widget.activities
        .where(
          (item) =>
              item.isRequirement &&
              (matchAll || item.assignedSections.contains(_selectedClassSection)),
        )
        .map((item) => _buildUnifiedActivityCard(item, 'PT'))
        .toList();
    final examinations = widget.assessments
        .where(
          (item) =>
              item.isExam &&
              (matchAll || item.assignedSections.contains(_selectedClassSection)),
        )
        .map((item) => _buildUnifiedAssessmentCard(item, 'EX'))
        .toList();

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classwork',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create activities, performance tasks, quizzes, and exams in one place.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _teacherSections.contains(_selectedClassSection) ||
                              _selectedClassSection == 'All Sections'
                          ? _selectedClassSection
                          : 'All Sections',
                      isDense: true,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      items: [
                        'All Sections',
                        ..._teacherSections,
                      ].toSet().map((sec) => DropdownMenuItem(value: sec, child: Text(sec))).toList(),
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
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              child: TabBar(
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
                children: [
                  _buildUnifiedCategoryView(
                    label: 'Written Works',
                    items: writtenWork,
                    emptyTitle: 'No written works yet',
                    emptyMessage: 'Create assignments, activities, and quizzes for your students.',
                    icon: LucideIcons.fileText,
                    onCreate: () => _showUnifiedCreateChooser(context, 'WW'),
                  ),
                  _buildUnifiedCategoryView(
                    label: 'Performance Tasks',
                    items: performanceTasks,
                    emptyTitle: 'No performance tasks yet',
                    emptyMessage: 'Create hands-on tasks, portfolios, and graded projects.',
                    icon: LucideIcons.presentation,
                    onCreate: () => _showUnifiedCreateChooser(context, 'PT'),
                  ),
                  _buildUnifiedCategoryView(
                    label: 'Examinations',
                    items: examinations,
                    emptyTitle: 'No examinations yet',
                    emptyMessage: 'Create Summative Tests (ST1, ST2) and Term Examinations (TE).',
                    icon: LucideIcons.award,
                    onCreate: () => _showUnifiedCreateChooser(context, 'EX'),
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
    required VoidCallback onCreate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: AppButton.primary(
            label: 'Create $label',
            icon: Icons.add,
            onPressed: onCreate,
            isSmall: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _PaginatedUnifiedItemList(
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
    final dueDate = item.deadlineForSection(_selectedClassSection);
    return _buildUnifiedCard(
      title: item.title,
      description: item.isRequirement ? '' : item.description,
      category: category,
      details: item.isRequirement
          ? '${item.section} • ${item.maxScore.toInt()} pts • Due ${_monthName(dueDate.month)} ${dueDate.day}, ${_formatTime(dueDate)}'
          : '${item.section} • ${item.maxScore.toInt()} pts • Due ${_monthName(dueDate.month)} ${dueDate.day}',
      icon: Icons.assignment_outlined,
      onPressed: () {
        if (widget.onViewSubmissions != null) {
          widget.onViewSubmissions!(item);
        }
      },
      actionLabel: 'View Submissions',
      onEdit: () => _showEditActivityModal(item),
      onDelete: () => _confirmDeleteActivity(item),
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
      onDelete: () => _confirmDeleteAssessment(item),
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
          } catch (_) {
            MockDatabase.instance.deleteActivity(item.id);
          }
        } else {
          MockDatabase.instance.deleteActivity(item.id);
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
        setState(() => MockDatabase.instance.deleteQuizOrExam(item.id));
      },
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
      isPerformanceTask: item.isRequirement,
      repository: widget.repository,
      onRequirementCreated: () {
        widget.onRefresh?.call();
        setState(() {});
      },
    );
  }

  void _showUnifiedCreateChooser(BuildContext context, [String? category]) {
    if (category == 'EX') {
      CreateAssessmentFlowDialog.show(
        context,
        initialSection: _selectedClassSection,
        initialIsExam: true,
        skipTypeSelection: true,
        onAssessmentCreated: () => setState(() {}),
      );
      return;
    }
    if (category == 'PT') {
      CreateRequirementFlowDialog.show(
        context,
        initialSection: _selectedClassSection,
        isPerformanceTask: true,
        repository: widget.repository,
        onRequirementCreated: () {
          widget.onRefresh?.call();
          setState(() {});
        },
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category == null ? 'Create Classwork' : 'Create $category Item',
        ),
        content: const Text(
          'Choose the grading category and use the appropriate creation flow.',
        ),
        actions: [
          if (category != 'PT' && category != 'EX')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                CreateRequirementFlowDialog.show(
                  context,
                  initialSection: _selectedClassSection,
                  isPerformanceTask: false,
                  repository: widget.repository,
                  onRequirementCreated: () {
                    widget.onRefresh?.call();
                    setState(() {});
                  },
                );
              },
              child: const Text('Activity / Assignment'),
            ),
          if (category != 'PT')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                CreateAssessmentFlowDialog.show(
                  context,
                  initialSection: _selectedClassSection,
                  initialIsExam: category == 'EX',
                  skipTypeSelection: true,
                  onAssessmentCreated: () => setState(() {}),
                );
              },
              child: Text(category == 'EX' ? 'Exam' : 'Quiz'),
            ),
          if (category != 'WW' && category != 'EX')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                CreateRequirementFlowDialog.show(
                  context,
                  initialSection: _selectedClassSection,
                  isPerformanceTask: true,
                  repository: widget.repository,
                  onRequirementCreated: () {
                    widget.onRefresh?.call();
                    setState(() {});
                  },
                );
              },
              child: const Text('Classwork'),
            ),
        ],
      ),
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

