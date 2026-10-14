import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherLessonPlanningTab extends StatefulWidget {
  final List<LessonPlanModel> lessonPlans;
  final VoidCallback onPlanGenerated;

  const TeacherLessonPlanningTab({
    super.key,
    required this.lessonPlans,
    required this.onPlanGenerated,
  });

  @override
  State<TeacherLessonPlanningTab> createState() =>
      _TeacherLessonPlanningTabState();
}

class _TeacherLessonPlanningTabState extends State<TeacherLessonPlanningTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ILAW Format',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              AppButton.primary(
                label: 'Generate New Lesson Plan',
                icon: Icons.auto_awesome,
                onPressed: () {
                  // TO DO: AI Lesson Generator API implementation
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: widget.lessonPlans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final lp = widget.lessonPlans[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lp.topic,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          StatusBadge(
                            text: 'AI Generated',
                            backgroundColor: AppTheme.catBlue.withValues(alpha: 0.1),
                            textColor: AppTheme.catBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${lp.duration} • Created: ${lp.createdAt.toLocal().toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Objectives:\n${lp.objectives}',
                        style: TextStyle(fontSize: 13, height: 1.3, color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
