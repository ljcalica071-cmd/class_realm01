import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/features/admin/widgets/widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

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

  void _handleApproveTeacher(UserModel teacher) {
    setState(() {
      MockDatabase.instance.updateTeacherStatus(teacher.id, AccountStatus.active);
    });
    AppModals.showSuccessDialog(
      context: context,
      title: 'Teacher Approved',
      message: '${teacher.fullName} has been successfully approved.',
    );
  }

  void _handleRejectTeacher(UserModel teacher) {
    setState(() {
      MockDatabase.instance.updateTeacherStatus(teacher.id, AccountStatus.rejected);
    });
  }

  Widget _buildBodyContent(
    List<UserModel> teachers,
    List<UserModel> students,
    List<UserModel> parents,
    List<UserModel> pendingTeachers,
  ) {
    switch (_selectedIndex) {
      case 0:
        return AdminOverviewTab(
          teachers: teachers,
          students: students,
          parents: parents,
          pendingTeachers: pendingTeachers,
          onViewAllPending: () => setState(() => _selectedIndex = 2),
          onApprove: _handleApproveTeacher,
          onReject: _handleRejectTeacher,
        );
      case 1:
        return AdminTeacherManagementTab(
          teachers: teachers,
          onDataChanged: () => setState(() {}),
        );
      case 2:
        return AdminPendingApprovalsTab(
          pendingTeachers: pendingTeachers,
          onApprove: _handleApproveTeacher,
          onReject: _handleRejectTeacher,
        );
      case 3:
        return AdminStatisticsTab(
          teachers: teachers,
          students: students,
          parents: parents,
        );
      case 4:
        return AdminProfileTab(
          adminUser: MockDatabase.instance.currentUser,
        );
      case 5:
        return const AdminSettingsTab();
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachers = MockDatabase.instance.users
        .where((u) => u.role == UserRole.teacher)
        .toList();
    final students = MockDatabase.instance.users
        .where((u) => u.role == UserRole.student)
        .toList();
    final parents = MockDatabase.instance.users
        .where((u) => u.role == UserRole.parent)
        .toList();
    final pendingTeachers = teachers
        .where((t) => t.status == AccountStatus.pending)
        .toList();

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            selectedIndex: _selectedIndex,
            isExpanded: _isSidebarExpanded,
            pendingCount: pendingTeachers.length,
            onSelect: (index) => setState(() => _selectedIndex = index),
            onLogout: () {
              MockDatabase.instance.logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Navbar
                AdminTopbar(
                  isSidebarExpanded: _isSidebarExpanded,
                  onToggleSidebar: () =>
                      setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                  title: _getTitle(_selectedIndex),
                  adminUser: MockDatabase.instance.currentUser,
                ),

                // Body content switch
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildBodyContent(
                      teachers,
                      students,
                      parents,
                      pendingTeachers,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
