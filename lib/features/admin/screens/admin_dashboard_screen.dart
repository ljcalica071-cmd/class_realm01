import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/features/admin/widgets/widgets.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  List<UserModel> _pendingTeachers = [];
  List<UserModel> _teachers = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtimeChanges();
  }

  void _subscribeToRealtimeChanges() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin_dashboard_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teacher_info',
          callback: (payload) {
            _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            _loadData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final pending = await AuthRepository.instance.getPendingTeachers();
    final allTeachers = await AuthRepository.instance.getTeachers();
    if (mounted) {
      setState(() {
        _pendingTeachers = pending;
        _teachers = allTeachers;
        _isLoading = false;
      });
    }
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

  void _handleApproveTeacher(UserModel teacher) async {
    final success = await AuthRepository.instance.approveTeacher(teacher.id);
    if (!success) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Error',
          message: 'Teacher approval failed. Please try again.',
        );
      }
      return;
    }

    EmailService.instance.sendAdminNotificationEmail(
      adminEmail: 'ljcalica071@gmail.com',
      teacherName: teacher.fullName,
      teacherEmail: teacher.email,
    );

    await _loadData();

    if (mounted) {
      AppModals.showSuccessDialog(
        context: context,
        title: 'Teacher Approved',
        message:
            '${teacher.fullName} has been approved and can now log in to the system.',
      );
    }
  }

  void _handleRejectTeacher(UserModel teacher) {
    AppModals.showConfirmationDialog(
      context: context,
      title: 'Confirm Rejection',
      message:
          'Are you sure you want to reject the application for ${teacher.fullName}?',
      confirmLabel: 'Okay',
      confirmColor: AppTheme.catRed,
      onConfirm: () async {
        // We delete the record from database if rejected
        final success = await AuthRepository.instance.deleteTeacherRecord(
          teacher.id,
        );
        if (!success) {
          if (mounted) {
            AppModals.showErrorDialog(
              context: context,
              title: 'Error',
              message: 'Failed to reject teacher.',
            );
          }
          return;
        }

        final emailSent = await EmailService.instance.sendRejectionEmail(
          recipientEmail: teacher.email,
          recipientName: teacher.fullName,
        );

        if (emailSent) {
          EmailService.instance.sendAdminNotificationEmail(
            adminEmail: 'ljcalica071@gmail.com',
            teacherName: teacher.fullName,
            teacherEmail: teacher.email,
            isRejection: true,
          );
        }

        await _loadData();

        if (mounted) {
          AppModals.showSuccessDialog(
            context: context,
            title: 'Registration Rejected',
            message:
                'The registration for ${teacher.fullName} has been formally rejected and their record was deleted.',
            confirmLabel: 'Confirm',
          );
        }
      },
    );
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
          onDataChanged: _loadData,
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
          adminUser:
              AuthRepository.instance.currentUser ??
              UserModel(
                id: 'admin_1',
                username: 'ljcalica971@gmail.com',
                fullName: 'System Admin',
                email: 'ljcalica971@gmail.com',
                role: UserRole.admin,
                status: AccountStatus.active,
              ),
        );
      case 5:
        return const AdminSettingsTab();
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
        ),
      );
    }

    // Pass loaded teachers; students/parents to be populated later
    final teachers = _teachers;
    final students = <UserModel>[];
    final parents = <UserModel>[];

    final isMobile = MediaQuery.of(context).size.width < 900;

    final sidebar = AdminSidebar(
      selectedIndex: _selectedIndex,
            isExpanded: isMobile ? true : _isSidebarExpanded,
            pendingCount: _pendingTeachers.length,
            onSelect: (index) {
              setState(() => _selectedIndex = index);
              if (isMobile && Scaffold.of(context).isDrawerOpen) {
                Navigator.pop(context);
              }
            },
            onLogout: () {
              AppModals.showConfirmationDialog(
                context: context,
                title: 'Confirm Logout',
                message:
                    'Are you sure you want to log out of the admin portal?',
                confirmLabel: 'Logout',
                confirmColor: AppTheme.catRed,
                onConfirm: () async {
                  await AuthRepository.instance.logout();
                  if (mounted)
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
              );
            },
          );

    final mainContent = Column(
      children: [
        // Top Navbar
        AdminTopbar(
                  isSidebarExpanded: _isSidebarExpanded,
                  onToggleSidebar: () =>
                      setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                  title: _getTitle(_selectedIndex),
                  adminUser: UserModel(
                    id: 'admin_1',
                    username: 'ljcalica971@gmail.com',
                    fullName: 'System Admin',
                    email: 'ljcalica971@gmail.com',
                    role: UserRole.admin,
                    status: AccountStatus.active,
                  ),
                ),

                // Body content switch
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildBodyContent(
                      teachers,
                      students,
                      parents,
                      _pendingTeachers,
                    ),
                  ),
                ),
              ],
            );

    return Scaffold(
      drawer: isMobile ? sidebar : null,
      body: isMobile
          ? mainContent
          : Row(
              children: [
                sidebar,
                Expanded(child: mainContent),
              ],
            ),
    );
  }
}
