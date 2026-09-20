import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../widgets/student_activity_card.dart';

class StudentRequirementsScreen extends StatefulWidget {
  const StudentRequirementsScreen({super.key});

  @override
  State<StudentRequirementsScreen> createState() =>
      _StudentRequirementsScreenState();
}

class _StudentRequirementsScreenState extends State<StudentRequirementsScreen> {
  @override
  Widget build(BuildContext context) {
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );
    final requirements = MockDatabase.instance.requirements;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Requirements'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: requirements.isEmpty
            ? const Center(
              child: Text(
                'No requirements assigned yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
            : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requirements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
