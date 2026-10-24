import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/widgets/generate_lesson_plan_modal.dart';
import 'package:class_realm/core/services/gemini_service.dart';

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
  void _openGenerateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GenerateLessonPlanModal(
        onGenerate: (subject, topic, gradeLevel, duration) async {
          final result = await GeminiService.instance.generateLessonPlan(
            subject: subject,
            topic: topic,
            gradeLevel: gradeLevel,
            duration: duration,
          );
          
          if (!mounted) return;
          
          if (result != null && !result.startsWith('Error')) {
            // Ideally save to Supabase here, but for now we show a dialog
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Generated Lesson Plan for $topic'),
                content: SingleChildScrollView(
                  child: Text(result),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result ?? 'Unknown error occurred.')),
            );
          }
        },
      ),
    );
  }

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
                onPressed: _openGenerateModal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.lessonPlans.isEmpty
                ? const Center(child: Text("No lesson plans generated yet. Click the button above to start."))
                : ListView.separated(
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
