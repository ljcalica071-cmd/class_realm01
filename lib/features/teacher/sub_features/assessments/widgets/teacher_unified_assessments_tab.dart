import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/edit_assessment_flow.dart';

class TeacherUnifiedAssessmentsTab extends StatefulWidget {
  final List<ActivityModel> activities;
  final List<QuizOrExamModel> assessments;
  final String selectedClassSection;
  final ValueChanged<ActivityModel>? onViewSubmissions;

  const TeacherUnifiedAssessmentsTab({
    super.key,
    required this.activities,
    required this.assessments,
    this.selectedClassSection = 'Section A',
    this.onViewSubmissions,
  });

  @override
  State<TeacherUnifiedAssessmentsTab> createState() =>
      _TeacherUnifiedAssessmentsTabState();
}

class _TeacherUnifiedAssessmentsTabState
    extends State<TeacherUnifiedAssessmentsTab> {
  late String _selectedClassSection;

  @override
  void initState() {
    super.initState();
    _selectedClassSection = widget.selectedClassSection;
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
    final writtenWork = <Widget>[
      ...widget.activities
          .where(
            (item) =>
                !item.isRequirement &&
                item.assignedSections.contains(_selectedClassSection),
          )
          .map((item) => _buildUnifiedActivityCard(item, 'WW')),
      ...widget.assessments
          .where(
            (item) =>
                !item.isExam &&
                item.assignedSections.contains(_selectedClassSection),
          )
          .map((item) => _buildUnifiedAssessmentCard(item, 'WW')),
    ];
    final performanceTasks = widget.activities
        .where(
          (item) =>
              item.isRequirement &&
              item.assignedSections.contains(_selectedClassSection),
        )
        .map((item) => _buildUnifiedActivityCard(item, 'PT'))
        .toList();
    final examinations = widget.assessments
        .where(
          (item) =>
              item.isExam &&
              item.assignedSections.contains(_selectedClassSection),
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
                Column(
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
                    emptyMessage: 'No written work for this section yet.',
                    onCreate: () => _showUnifiedCreateChooser(context, 'WW'),
                  ),
                  _buildUnifiedCategoryView(
                    label: 'Performance Tasks',
                    items: performanceTasks,
                    emptyMessage: 'No performance tasks for this section yet.',
                    onCreate: () => _showUnifiedCreateChooser(context, 'PT'),
                  ),
                  _buildUnifiedCategoryView(
                    label: 'Examinations',
                    items: examinations,
                    emptyMessage: 'No examinations for this section yet.',
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
    required String emptyMessage,
    required VoidCallback onCreate,
  }) {
    final theme = Theme.of(context);
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
        Expanded(child: _buildUnifiedItemList(items, emptyMessage, theme)),
      ],
    );
  }

  Widget _buildUnifiedItemList(List<Widget> items, String emptyMessage, ThemeData theme) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => items[index],
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
      onDelete: () {
        setState(() => MockDatabase.instance.deleteActivity(item.id));
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
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?\n\n$title'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
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
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditActivityModal(ActivityModel item) {
    if (!item.isRequirement) {
      return;
    }
    CreateRequirementFlowDialog.show(
      context,
      existingTask: item,
      initialSection: item.assignedSections.first,
      onRequirementCreated: () => setState(() {}),
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
        onRequirementCreated: () => setState(() {}),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category == null ? 'Create Classwork' : 'Create $category Item',
        ),
        content: Text(
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
                  onRequirementCreated: () => setState(() {}),
                );
              },
              child: Text('Activity / Assignment'),
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
                  onRequirementCreated: () => setState(() {}),
                );
              },
              child: Text('Classwork'),
            ),
        ],
      ),
    );
  }
}
