import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/admin/shared/widgets/admin_stat_card.dart';

class AdminStatisticsTab extends StatelessWidget {
  final List<UserModel> teachers;
  final List<UserModel> students;
  final List<UserModel> parents;

  const AdminStatisticsTab({
    super.key,
    required this.teachers,
    required this.students,
    required this.parents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Statistics & Analytics',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AdminStatCard(
                  title: 'Active Teachers',
                  value: '${teachers.where((t) => t.status == AccountStatus.active).length}',
                  icon: Icons.verified_user,
                  color: AppTheme.catGreen,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: AdminStatCard(
                  title: 'Enrolled Students',
                  value: '${students.length}',
                  color: theme.colorScheme.primary,
                  icon: Icons.people_alt,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: AdminStatCard(
                  title: 'Linked Parents',
                  value: '${parents.length}',
                  icon: Icons.family_restroom,
                  color: AppTheme.catPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
