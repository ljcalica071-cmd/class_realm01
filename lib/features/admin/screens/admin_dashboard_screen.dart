import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/sync_status_badge.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final teachers = MockDatabase.instance.users.where((u) => u.role == UserRole.teacher).toList();
    final students = MockDatabase.instance.users.where((u) => u.role == UserRole.student).toList();
    final parents = MockDatabase.instance.users.where((u) => u.role == UserRole.parent).toList();
    final pendingTeachers = teachers.where((t) => t.status == AccountStatus.pending).toList();

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarExpanded ? 260 : 80,
            color: AppColors.sidebarBg,
            child: Column(
              children: [
                // Logo Header
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.white, size: 28),
                      if (_isSidebarExpanded) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'CLASSREALM',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // Nav Items
                _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined),
                _buildNavItem(1, 'Teacher Management', Icons.people_outline),
                _buildNavItem(2, 'Pending Approvals', Icons.how_to_reg_outlined, badgeCount: pendingTeachers.length),
                _buildNavItem(3, 'System Statistics', Icons.bar_chart),
                _buildNavItem(4, 'Admin Profile', Icons.person_outline),
                _buildNavItem(5, 'Settings', Icons.settings_outlined),

                const Spacer(),
                const Divider(color: Colors.white12, height: 1),

                // Logout
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: _isSidebarExpanded ? const Text('Logout', style: TextStyle(color: AppColors.error)) : null,
                  onTap: () {
                    MockDatabase.instance.logout();
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Navbar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSidebarExpanded ? Icons.menu_open : Icons.menu),
                        onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _getTitle(_selectedIndex),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      const SyncStatusBadge(),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          MockDatabase.instance.currentUser?.fullName.substring(0, 1) ?? 'A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            MockDatabase.instance.currentUser?.fullName ?? 'Administrator',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          const Text(
                            'System Administrator',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Body content switch
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: _buildBodyContent(teachers, students, parents, pendingTeachers),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Admin Dashboard Overview';
      case 1:
        return 'Teacher Management';
      case 2:
        return 'Pending Teacher Approvals';
      case 3:
        return 'System Statistics & Analytics';
      case 4:
        return 'Administrator Profile';
      case 5:
        return 'System Settings';
      default:
        return 'Admin Portal';
    }
  }

  Widget _buildNavItem(int index, String label, IconData icon, {int badgeCount = 0}) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sidebarItemActive : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppColors.textMuted, size: 20),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: isSelected ? Colors.white : AppColors.textMuted, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 14),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(List<UserModel> teachers, List<UserModel> students, List<UserModel> parents, List<UserModel> pendingTeachers) {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewTab(teachers, students, parents, pendingTeachers);
      case 1:
        return _buildTeacherManagementTab(teachers);
      case 2:
        return _buildPendingApprovalsTab(pendingTeachers);
      case 3:
        return _buildStatisticsTab(teachers, students, parents);
      case 4:
        return _buildProfileTab();
      case 5:
        return _buildSettingsTab();
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  Widget _buildOverviewTab(List<UserModel> teachers, List<UserModel> students, List<UserModel> parents, List<UserModel> pendingTeachers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Institutional Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Monitor system-level statistics and teacher account onboarding.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
              _buildStatCard('Total Teachers', '${teachers.length}', Icons.person_pin, AppColors.primary),
              _buildStatCard('Total Students', '${students.length}', Icons.groups, AppColors.accent),
              _buildStatCard('Total Parents', '${parents.length}', Icons.family_restroom, Colors.indigo),
              _buildStatCard('Pending Approvals', '${pendingTeachers.length}', Icons.pending_actions, AppColors.warning),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Pending Approvals Table Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pending Teacher Onboarding', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    TextButton(
                      onPressed: () => setState(() => _selectedIndex = 2),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                pendingTeachers.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No pending teacher requests.')))
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pendingTeachers.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final t = pendingTeachers[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(backgroundColor: AppColors.warningLight, child: const Icon(Icons.person, color: AppColors.warning)),
                            title: Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${t.email} • ${t.departmentOrSection}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppPrimaryButton(
                                  label: 'Approve',
                                  backgroundColor: AppColors.success,
                                  height: 36,
                                  width: 90,
                                  onPressed: () {
                                    setState(() {
                                      MockDatabase.instance.updateTeacherStatus(t.id, AccountStatus.active);
                                    });
                                    AppModals.showSuccessDialog(context: context, title: 'Teacher Approved', message: '${t.fullName} has been successfully approved.');
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                                  onPressed: () {
                                    setState(() {
                                      MockDatabase.instance.updateTeacherStatus(t.id, AccountStatus.rejected);
                                    });
                                  },
                                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTeacherManagementTab(List<UserModel> teachers) {
    final filtered = teachers.where((t) {
      final matchesSearch = t.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) || t.email.toLowerCase().contains(_searchQuery.toLowerCase());
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
              const Text('Teacher Accounts Directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              AppPrimaryButton(
                label: 'Create Teacher Account',
                icon: Icons.person_add,
                onPressed: () => _showCreateTeacherModal(context),
                height: 40,
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
                items: ['All', 'Active', 'Pending'].map((s) => DropdownMenuItem(value: s, child: Text('Status: $s'))).toList(),
                onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final t = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primaryLight, child: Text(t.fullName.substring(0, 1), style: const TextStyle(color: Colors.white))),
                    title: Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${t.email} • Dept: ${t.departmentOrSection ?? "General"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge.fromAccountStatus(t.status),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () async {
                            final confirm = await AppModals.showConfirmDialog(
                              context: context,
                              title: 'Deactivate Teacher',
                              message: 'Are you sure you want to deactivate ${t.fullName}?',
                              confirmLabel: 'Deactivate',
                              confirmColor: AppColors.error,
                            );
                            if (confirm == true) {
                              setState(() {
                                MockDatabase.instance.users.removeWhere((u) => u.id == t.id);
                              });
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
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name with Title')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
              const SizedBox(height: 12),
              TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department')),
              const SizedBox(height: 12),
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AppPrimaryButton(
            label: 'Create Account',
            onPressed: () {
              if (nameCtrl.text.isEmpty || usernameCtrl.text.isEmpty) return;
              setState(() {
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
              });
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(context: context, title: 'Teacher Created', message: 'New teacher account successfully created and activated.');
            },
            width: 130,
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsTab(List<UserModel> pendingTeachers) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pending Teacher Approvals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Review and approve new teacher sign-up requests.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: pendingTeachers.isEmpty
                ? const Center(child: Text('No pending teacher requests.', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)))
                : ListView.separated(
                    itemCount: pendingTeachers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final t = pendingTeachers[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            const CircleAvatar(backgroundColor: AppColors.warningLight, child: Icon(Icons.person, color: AppColors.warning)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('${t.email} • ${t.departmentOrSection}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ),
                            AppPrimaryButton(
                              label: 'Approve',
                              backgroundColor: AppColors.success,
                              height: 40,
                              width: 100,
                              onPressed: () {
                                setState(() {
                                  MockDatabase.instance.updateTeacherStatus(t.id, AccountStatus.active);
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                              onPressed: () {
                                setState(() {
                                  MockDatabase.instance.updateTeacherStatus(t.id, AccountStatus.rejected);
                                });
                              },
                              child: const Text('Reject'),
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

  Widget _buildStatisticsTab(List<UserModel> teachers, List<UserModel> students, List<UserModel> parents) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Statistics & Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatCard('Active Teachers', '${teachers.where((t) => t.status == AccountStatus.active).length}', Icons.verified_user, AppColors.success)),
              const SizedBox(width: 20),
              Expanded(child: _buildStatCard('Enrolled Students', '${students.length}', Icons.school, AppColors.primary)),
              const SizedBox(width: 20),
              Expanded(child: _buildStatCard('Linked Parents', '${parents.length}', Icons.family_restroom, AppColors.accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final admin = MockDatabase.instance.currentUser!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Administrator Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(leading: const Icon(Icons.person), title: const Text('Full Name'), subtitle: Text(admin.fullName)),
            const Divider(),
            ListTile(leading: const Icon(Icons.email), title: const Text('Email Address'), subtitle: Text(admin.email)),
            const Divider(),
            ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('Access Level'), subtitle: const Text('System-wide Administrator')),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('System Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Enable Email Notifications (Simulated)'),
              subtitle: const Text('Send automated alerts for teacher approval'),
              value: true,
              onChanged: (v) {},
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Maintenance Mode'),
              subtitle: const Text('Temporarily restrict non-admin access'),
              value: false,
              onChanged: (v) {},
            ),
          ],
        ),
      ),
    );
  }
}
