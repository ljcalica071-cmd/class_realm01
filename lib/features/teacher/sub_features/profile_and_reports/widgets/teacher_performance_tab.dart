import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/teacher/shared/widgets/teacher_top_summary_card.dart';

class TeacherPerformanceTab extends StatelessWidget {
  final List<UserModel> students;

  const TeacherPerformanceTab({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Performance & At-Risk Alerts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 24),
          if (MediaQuery.of(context).size.width < 900)
            Column(
              children: [
                TeacherTopSummaryCard(
                  title: 'Quarter Class Average',
                  mainValue: '88.4%',
                  subText: '↑ 2.1% improvement from Q1',
                  baseColor: AppTheme.catGreen,
                  icon: Icons.trending_up,
                ),
                const SizedBox(height: 16),
                TeacherTopSummaryCard(
                  title: 'Students At-Risk (< 75)',
                  mainValue: '2',
                  subText: 'Requires remedial interventions',
                  baseColor: AppTheme.catRed,
                  icon: Icons.warning_amber_outlined,
                ),
                const SizedBox(height: 16),
                TeacherTopSummaryCard(
                  title: 'Honor Students (> 90)',
                  mainValue: '14',
                  subText: 'High academic distinction',
                  baseColor: theme.colorScheme.primary,
                  icon: Icons.emoji_events_outlined,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TeacherTopSummaryCard(
                    title: 'Quarter Class Average',
                    mainValue: '88.4%',
                    subText: '↑ 2.1% improvement from Q1',
                    baseColor: AppTheme.catGreen,
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TeacherTopSummaryCard(
                    title: 'Students At-Risk (< 75)',
                    mainValue: '2',
                    subText: 'Requires remedial interventions',
                    baseColor: AppTheme.catRed,
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TeacherTopSummaryCard(
                    title: 'Honor Students (> 90)',
                    mainValue: '14',
                    subText: 'High academic distinction',
                    baseColor: theme.colorScheme.primary,
                    icon: Icons.emoji_events_outlined,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
