import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/student/shared/widgets/student_activity_card.dart';

class StudentRequirementsScreen extends StatefulWidget {
  const StudentRequirementsScreen({super.key});

  @override
  State<StudentRequirementsScreen> createState() =>
      _StudentRequirementsScreenState();
}

class _StudentRequirementsScreenState extends State<StudentRequirementsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );
    final requirements = MockDatabase.instance.requirements;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Task'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: requirements.isEmpty
            ? Center(
              child: Text(
                'No requirements assigned yet.',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            )
            : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requirements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                return StudentActivityCard(
                  activity: requirements[i],
                  student: student,
                  onSubmitted: () => setState(() {}),
                );
              },
            ),
      ),
    );
  }
}
