import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/admin/shared/widgets/admin_stat_card.dart';

class AdminOverviewTab extends StatelessWidget {
  final List<UserModel> teachers;
  final List<UserModel> students;
  final List<UserModel> parents;
  final List<UserModel> pendingTeachers;
  final VoidCallback onViewAllPending;
  final ValueChanged<UserModel> onApprove;
  final ValueChanged<UserModel> onReject;

  const AdminOverviewTab({
    super.key,
    required this.teachers,
    required this.students,
    required this.parents,
    required this.pendingTeachers,
    required this.onViewAllPending,
    required this.onApprove,
    required this.onReject,
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
            'Monitor system-level statistics and teacher account onboarding.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // Stat Cards Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.5,
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
                title: 'Pending Approvals',
                value: '${pendingTeachers.length}',
                icon: Icons.pending_actions,
                color: AppTheme.catOrange,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Pending Approvals Table Preview
          Container(
            padding: const EdgeInsets.all(20),
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
                      'Pending Teacher Onboarding',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: onViewAllPending,
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                pendingTeachers.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No pending teacher requests.'),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pendingTeachers.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final t = pendingTeachers[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.catOrange.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.person,
                                color: AppTheme.catOrange,
                              ),
                            ),
                            title: Text(
                              t.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${t.email} • ${t.departmentOrSection}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppButton.success(
                                  label: 'Approve',
                                  isSmall: true,
                                  onPressed: () => onApprove(t),
                                ),
                                const SizedBox(width: 8),
                                AppButton.danger(
                                  label: 'Reject',
                                  isSmall: true,
                                  onPressed: () => onReject(t),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
