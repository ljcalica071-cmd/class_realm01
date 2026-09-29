import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class AdminPendingApprovalsTab extends StatelessWidget {
  final List<UserModel> pendingTeachers;
  final ValueChanged<UserModel> onApprove;
  final ValueChanged<UserModel> onReject;

  const AdminPendingApprovalsTab({
    super.key,
    required this.pendingTeachers,
    required this.onApprove,
    required this.onReject,
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
            'Pending Teacher Approvals',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review and approve new teacher sign-up requests.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: pendingTeachers.isEmpty
                ? Center(
                    child: Text(
                      'No pending teacher requests.',
                      style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  )
                : ListView.separated(
                    itemCount: pendingTeachers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final t = pendingTeachers[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.catOrange.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: AppTheme.catOrange),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '${t.email} • ${t.departmentOrSection ?? "Pending Academic Setup"}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppButton.success(
                              label: 'Approve',
                              onPressed: () => onApprove(t),
                            ),
                            const SizedBox(width: 8),
                            AppButton.danger(
                              label: 'Reject',
                              onPressed: () => onReject(t),
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
