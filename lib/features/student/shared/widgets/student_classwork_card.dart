import 'package:flutter/material.dart';
import 'package:class_realm/models/student_dashboard_models.dart';

class StudentClassworkCard extends StatelessWidget {
  const StudentClassworkCard({super.key, required this.classwork});

  final StudentClassworkModel classwork;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitted =
        classwork.status == 'submitted' || classwork.status == 'graded';
    final isOverdue =
        !isSubmitted &&
        classwork.deadline != null &&
        classwork.deadline!.isBefore(DateTime.now());
    final status = classwork.status == 'graded'
        ? 'Graded'
        : classwork.status == 'submitted'
        ? 'Submitted'
        : classwork.status == 'returned'
        ? 'Returned'
        : isOverdue
        ? 'Overdue'
        : 'To do';
    final statusColor = classwork.status == 'graded'
        ? Colors.green
        : isOverdue
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    classwork.type == 'performance_task'
                        ? Icons.workspace_premium_outlined
                        : Icons.assignment_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classwork.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          classwork.subjectName,
                          classwork.sectionName,
                          if (classwork.gradeLevel.isNotEmpty)
                            'Grade ${classwork.gradeLevel}',
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(label: status, color: statusColor),
              ],
            ),
            if (classwork.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                classwork.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Detail(
                  icon: Icons.event_outlined,
                  text: classwork.deadline == null
                      ? 'No deadline'
                      : 'Due ${_formatDate(classwork.deadline!)}',
                ),
                if (classwork.maxScore > 0)
                  _Detail(
                    icon: Icons.stars_outlined,
                    text: '${_formatScore(classwork.maxScore)} points',
                  ),
              ],
            ),
            if (classwork.score != null) ...[
              const SizedBox(height: 12),
              Text(
                'Score: ${_formatScore(classwork.score!)} / ${_formatScore(classwork.maxScore)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (classwork.feedback?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                classwork.feedback!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
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
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, $hour:$minute $period';
  }

  static String _formatScore(double score) => score == score.roundToDouble()
      ? score.toInt().toString()
      : score.toStringAsFixed(1);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
