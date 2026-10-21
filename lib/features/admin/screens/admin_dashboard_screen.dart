import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/features/admin/widgets/widgets.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/logout_helper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/session_activity_tracker.dart';

import 'package:class_realm/routes/app_routes.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int initialIndex;
  const AdminDashboardScreen({super.key, this.initialIndex = 0});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late int _selectedIndex;
  bool _isSidebarExpanded = true;
  List<UserModel> _teachers = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    // Direct URL entry security guard: only authenticated Admins allowed
    final user = AuthRepository.instance.currentUser;
    if (user == null || user.role != UserRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      });
      return;
    }

    _loadData(isInitial: true);
    _subscribeToRealtimeChanges();
  }

  void _navigateToTab(int index) {
    if (_selectedIndex == index) return;
    String route = AppRoutes.adminDashboard;
    switch (index) {
      case 0:
        route = AppRoutes.adminDashboard;
        break;
      case 1:
        route = AppRoutes.adminBroadcasts;
        break;
      case 2:
        route = AppRoutes.adminTeacherManagement;
        break;
      case 3:
        route = AppRoutes.adminActivityAnalytics;
        break;
      case 4:
        route = AppRoutes.adminProfile;
        break;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  void _subscribeToRealtimeChanges() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin_dashboard_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teacher_settings',
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

  Future<void> _loadData({bool isInitial = false}) async {
    if (isInitial) {
      setState(() => _isLoading = true);
    }
    final allTeachers = await AuthRepository.instance.getTeachers();
    if (mounted) {
      setState(() {
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
        return 'Broadcasts & Maintenance Control';
      case 2:
        return 'Teacher Management';
      case 3:
        return 'Teacher Activity & Analytics Hub';
      case 4:
        return 'Administrator Profile';
      default:
        return 'Admin Portal';
    }
  }

  Widget _buildBodyContent(
    List<UserModel> teachers,
    List<UserModel> students,
    List<UserModel> parents,
  ) {
    switch (_selectedIndex) {
      case 0:
        return AdminOverviewTab(
          teachers: teachers,
          students: students,
          parents: parents,
          onNavigateToBroadcasts: () => setState(() => _selectedIndex = 1),
        );
      case 1:
        return const AdminBroadcastsTab();
      case 2:
        return AdminTeacherManagementTab(
          teachers: teachers,
          onDataChanged: _loadData,
        );
      case 3:
        return const AdminActivityAnalyticsTab();
      case 4:
        return AdminProfileTab(
          adminUser: AuthRepository.instance.currentUser,
        );
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pass loaded teachers; students/parents to be populated later
    final teachers = _teachers;
    final students = <UserModel>[];
    final parents = <UserModel>[];

    final isMobile = MediaQuery.of(context).size.width < 900;

    final sidebar = AdminSidebar(
      selectedIndex: _selectedIndex,
            isExpanded: isMobile ? true : _isSidebarExpanded,
            onSelect: (index) {
              if (isMobile && Scaffold.of(context).isDrawerOpen) {
                Navigator.pop(context);
              }
              _navigateToTab(index);
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
                  await LogoutHelper.logout(context);
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
                  adminUser: AuthRepository.instance.currentUser,
                ),

                // Body content switch
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildBodyContent(
                      teachers,
                      students,
                      parents,
                    ),
                  ),
                ),
              ],
            );

    return SessionActivityTracker(
      child: Scaffold(
        drawer: isMobile ? sidebar : null,
        body: isMobile
            ? mainContent
            : Row(
                children: [
                  sidebar,
                  Expanded(child: mainContent),
                ],
              ),
      ),
    );
  }
}
