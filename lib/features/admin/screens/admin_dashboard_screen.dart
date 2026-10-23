import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/admin/widgets/widgets.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/logout_helper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/session_activity_tracker.dart';

import 'dart:async';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

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
  bool _isLoading = false;
  RealtimeChannel? _realtimeChannel;

  String _routeForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.adminDashboard;
      case 1:
        return AppRoutes.adminBroadcasts;
      case 2:
        return AppRoutes.adminTeacherManagement;
      case 3:
        return AppRoutes.adminActivityAnalytics;
      case 4:
        return AppRoutes.adminProfile;
      default:
        return AppRoutes.adminDashboard;
    }
  }

  @override
  void initState() {
    super.initState();
    final savedTab = LocalStorageService.getActiveDashboardTab('admin');
    _selectedIndex = widget.initialIndex != 0 ? widget.initialIndex : savedTab;

    // Direct URL entry security guard: only authenticated Admins allowed
    final user = AuthRepository.instance.currentUser;
    if (user == null || user.role != UserRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          );
        }
      });
      return;
    }

    final currentRoute = _routeForIndex(_selectedIndex);
    updateBrowserUrl(currentRoute);
    LocalStorageService.saveLastActiveRoute(currentRoute);
    LocalStorageService.saveActiveDashboardTab('admin', _selectedIndex);
    _loadData();
    _subscribeToRealtimeChanges();
  }

  void _navigateToTab(int index) {
    if (_selectedIndex == index) return;
    final route = _routeForIndex(index);
    setState(() {
      _selectedIndex = index;
    });
    updateBrowserUrl(route);
    LocalStorageService.saveLastActiveRoute(route);
    LocalStorageService.saveActiveDashboardTab('admin', index);
    SystemChannels.navigation.invokeMethod<void>('selectRouteName', route);
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
    // SWR Instant Frame 1 Cache
    final cached = AppDataCache.instance.getCached<List<UserModel>>(
      'admin_teachers_list',
      (json) => (json as List)
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _teachers = cached;
        _isLoading = false;
      });
    } else if (isInitial) {
      setState(() => _isLoading = true);
    }

    try {
      final allTeachers = await AuthRepository.instance.getTeachers();
      if (mounted) {
        setState(() {
          _teachers = allTeachers;
          _isLoading = false;
        });
        unawaited(AppDataCache.instance.setCache(
          'admin_teachers_list',
          allTeachers.map((t) => t.toJson()).toList(),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    return IndexedStack(
      index: _selectedIndex,
      children: [
        AdminOverviewTab(
          teachers: teachers,
          students: students,
          parents: parents,
          onNavigateToBroadcasts: () => _navigateToTab(1),
        ),
        const AdminBroadcastsTab(),
        AdminTeacherManagementTab(
          teachers: teachers,
          onDataChanged: _loadData,
        ),
        const AdminActivityAnalyticsTab(),
        AdminProfileTab(
          adminUser: AuthRepository.instance.currentUser,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    if (user == null || user.role != UserRole.admin) {
      return const SizedBox.shrink();
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
                    child: StaggeredEntrance(
                      key: ValueKey(_selectedIndex),
                      index: 0,
                      child: _buildBodyContent(
                        teachers,
                        students,
                        parents,
                      ),
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
