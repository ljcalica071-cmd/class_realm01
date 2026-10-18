import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/features/admin/widgets/widgets.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/logout_helper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  List<UserModel> _teachers = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData(isInitial: true);
    _subscribeToRealtimeChanges();
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
        return 'Teacher Management';
      case 2:
        return 'System Statistics & Analytics';
      case 3:
        return 'Administrator Profile';
      case 4:
        return 'System Settings';
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
        );
      case 1:
        return AdminTeacherManagementTab(
          teachers: teachers,
          onDataChanged: _loadData,
        );
      case 2:
        return AdminStatisticsTab(
          teachers: teachers,
          students: students,
          parents: parents,
        );
      case 3:
        return AdminProfileTab(
          adminUser: AuthRepository.instance.currentUser,
        );
      case 4:
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
