import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';

class ParentGradesTab extends StatelessWidget {
  final UserModel? student;

  const ParentGradesTab({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (student == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No linked student found. Please contact the school administrator.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final database = MockDatabase.instance;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Grade Breakdown & Component Scores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Examinations (30%)'),
              trailing: Text(
                '${database.categoryAverageFor(student!.id, 'Examinations').toStringAsFixed(1)} / 100',
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Written Works (20%)'),
              trailing: Text(
                '${database.categoryAverageFor(student!.id, 'Written Works').toStringAsFixed(1)} / 100',
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Performance Task (50%)'),
              trailing: Text(
                '${database.categoryAverageFor(student!.id, 'Performance Task').toStringAsFixed(1)} / 100',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
