import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/admin/shared/widgets/admin_stat_card.dart';

class AdminOverviewTab extends StatelessWidget {
  final List<UserModel> teachers;
  final List<UserModel> students;
  final List<UserModel> parents;

  const AdminOverviewTab({
    super.key,
    required this.teachers,
    required this.students,
    required this.parents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institutional Overview',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage teacher accounts and monitor system-level statistics.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 4
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: columns == 1 ? 2.8 : 1.5,
                children: [
                  AdminStatCard(
                    title: 'Total Teachers',
                    value: '${teachers.length}',
                    icon: Icons.person_pin,
                    color: theme.colorScheme.primary,
                  ),
                  AdminStatCard(
                    title: 'Total Students',
                    value: '${students.length}',
                    icon: Icons.groups,
                    color: AppTheme.catPurple,
                  ),
                  AdminStatCard(
                    title: 'Total Parents',
                    value: '${parents.length}',
                    icon: Icons.family_restroom,
                    color: AppTheme.catBlue,
                  ),
                  AdminStatCard(
                    title: 'First Login Pending',
                    value:
                        '${teachers.where((teacher) => teacher.status == AccountStatus.pendingFirstLogin).length}',
                    icon: Icons.lock_clock_outlined,
                    color: AppTheme.catOrange,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
