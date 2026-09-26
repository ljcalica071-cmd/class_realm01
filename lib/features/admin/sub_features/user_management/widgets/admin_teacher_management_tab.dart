import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class AdminTeacherManagementTab extends StatefulWidget {
  final List<UserModel> teachers;
  final VoidCallback onDataChanged;

  const AdminTeacherManagementTab({
    super.key,
    required this.teachers,
    required this.onDataChanged,
  });

  @override
  State<AdminTeacherManagementTab> createState() =>
      _AdminTeacherManagementTabState();
}

class _AdminTeacherManagementTabState extends State<AdminTeacherManagementTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  void _showCreateTeacherModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Teacher Account'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name with Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton.primary(
            label: 'Create Account',
            onPressed: () {
              if (nameCtrl.text.isEmpty || usernameCtrl.text.isEmpty) return;
              MockDatabase.instance.users.add(
                UserModel(
                  id: 'usr_t_${DateTime.now().millisecondsSinceEpoch}',
                  username: usernameCtrl.text.trim(),
                  fullName: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  role: UserRole.teacher,
                  status: AccountStatus.active,
                  departmentOrSection: deptCtrl.text.trim(),
                ),
              );
              Navigator.pop(ctx);
              widget.onDataChanged();
              AppModals.showSuccessDialog(
                context: context,
                title: 'Teacher Created',
                message: 'New teacher account successfully created and activated.',
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.teachers.where((t) {
      final matchesSearch = t.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.email.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_statusFilter == 'All') return matchesSearch;
      if (_statusFilter == 'Active') return matchesSearch && t.status == AccountStatus.active;
      if (_statusFilter == 'Pending') return matchesSearch && t.status == AccountStatus.pending;
      return matchesSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Teacher Accounts Directory',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              AppButton.primary(
                label: 'Create Teacher Account',
                icon: Icons.person_add,
                onPressed: () => _showCreateTeacherModal(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters & Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search teachers by name or email...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _statusFilter,
                items: ['All', 'Active', 'Pending']
                    .map((s) => DropdownMenuItem(value: s, child: Text('Status: $s')))
                    .toList(),
                onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final t = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        t.fullName.substring(0, 1),
                        style: TextStyle(color: theme.colorScheme.onPrimary),
                      ),
                    ),
                    title: Text(t.fullName, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    subtitle: Text('${t.email} • Dept: ${t.departmentOrSection ?? "General"}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge.fromAccountStatus(t.status),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.catRed),
                          onPressed: () async {
                            final confirm = await AppModals.showConfirmDialog(
                              context: context,
                              title: 'Deactivate Teacher',
                              message: 'Are you sure you want to deactivate ${t.fullName}?',
                              confirmLabel: 'Deactivate',
                              confirmColor: AppTheme.catRed,
                            );
                            if (confirm == true) {
                              MockDatabase.instance.users.removeWhere((u) => u.id == t.id);
                              widget.onDataChanged();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
