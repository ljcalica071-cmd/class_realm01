import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/core/utils/logout_helper.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/features/student/shared/widgets/student_classwork_card.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_assessment_screen.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_grades_screen.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_learning_materials_screen.dart';
import 'package:class_realm/features/student/sub_features/profile/screens/student_settings_screen.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_schedule_screen.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/features/student/sub_features/profile/widgets/student_notifications_tab.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/shared/services/in_app_notification_service.dart';
import 'package:class_realm/routes/app_routes.dart';

class StudentHomeScreen extends StatefulWidget {
  final int initialTabIndex;
  const StudentHomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  String? _selectedOfferingId;
  StudentDashboardData? _dashboard;
  Object? _loadError;
  bool _isLoading = true;
  bool _isAutoResumingAssessment = false;

  String _routeForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.studentHome;
      case 1:
        return AppRoutes.studentClasswork;
      case 2:
        return AppRoutes.studentAlerts;
      case 3:
        return AppRoutes.studentProfile;
      default:
        return AppRoutes.studentHome;
    }
  }

  void _onSelectTab(int index) {
    if (index < 0 || index >= 4) return;
    setState(() => _currentIndex = index);
    LocalStorageService.saveActiveDashboardTab('student', index);
    final route = _routeForIndex(index);
    LocalStorageService.saveLastActiveRoute(route);
    updateBrowserUrl(route);
  }

  @override
  void initState() {
    super.initState();
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && currentUser.role != UserRole.student) {
      final redirectRoute = AppRoutes.resolveSafeRouteForUser(currentUser);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            redirectRoute,
            (route) => false,
          );
        }
      });
      return;
    }
    final savedTab = LocalStorageService.getActiveDashboardTab('student');
    _currentIndex = (widget.initialTabIndex > 0)
        ? widget.initialTabIndex
        : (savedTab >= 0 && savedTab < 4 ? savedTab : 0);
    final route = _routeForIndex(_currentIndex);
    LocalStorageService.saveLastActiveRoute(route);
    updateBrowserUrl(route);
    final initialStudentId =
        AuthRepository.instance.currentUser?.id ??
        LocalStorageService.getCachedUser()?.id;
    if (initialStudentId != null && initialStudentId.isNotEmpty) {
      _checkAndAutoResumeAssessment(initialStudentId);
    }
    _loadDashboard();
    InAppNotificationService.subscribeToAnnouncements(role: 'student');
  }

  @override
  void dispose() {
    InAppNotificationService.unsubscribeFromAnnouncements();
    super.dispose();
  }

  Future<void> _checkAndAutoResumeAssessment(String studentId) async {
    if (_isAutoResumingAssessment || studentId.isEmpty) return;
    _isAutoResumingAssessment = true;
    try {
      final activeAssessment =
          await StudentAssessmentScreen.getActiveAssessmentToResume(studentId);
      if (activeAssessment != null && mounted) {
        await StudentAssessmentScreen.start(context, activeAssessment);
        if (mounted) {
          _loadDashboard(forceRefresh: true, silent: true);
        }
      }
    } catch (e) {
      debugPrint('Notice checking auto-resume assessment: $e');
    } finally {
      _isAutoResumingAssessment = false;
    }
  }

  Future<void> _loadDashboard({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    setState(() {
      if (!silent || _dashboard == null) {
        _isLoading = true;
      }
      if (!silent) {
        _loadError = null;
      }
    });
    try {
      final dashboard = await StudentDashboardRepository.instance.loadDashboard(
        forceRefresh: forceRefresh,
      );
      // Strictly guard against overwriting currentUser if session identity does not match
      final currentAuth = AuthRepository.instance.currentUser;
      if (currentAuth == null || currentAuth.id == dashboard.student.id) {
        AuthRepository.instance.setCurrentUser(dashboard.student);
      }
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _loadError = null;
        });
        _checkAndAutoResumeAssessment(dashboard.student.id);
      }
    } catch (error) {
      if (mounted && (!silent || _dashboard == null)) {
        setState(() => _loadError = error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && currentUser.role != UserRole.student) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    if (_isLoading && _dashboard == null) {
      return Scaffold(
        body: _mobileFrame(
          context,
          Center(
            child: LoadingAnimationWidget.staggeredDotsWave(
              color: theme.colorScheme.primary,
              size: 48,
            ),
          ),
        ),
      );
    }
    if (_loadError != null && _dashboard == null) {
      return Scaffold(
        body: _mobileFrame(
          context,
          AppPullToRefresh(
            onRefresh: () => _loadDashboard(forceRefresh: true),
            child: AppPullToRefresh.scrollableState(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 34,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'We could not load your student dashboard.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _loadDashboard(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final student = _dashboard!.student;
    final classwork = _dashboard!.classwork;
    final enrollments = _dashboard!.enrollments;
    final activeTabIndex = _currentIndex.clamp(0, 3);
    final Widget activePage = switch (activeTabIndex) {
      0 => _buildHomeTab(context, student, classwork, enrollments),
      1 => _buildClassworkTab(context, classwork, enrollments),
      2 => const StudentNotificationsTab(),
      _ => _buildProfileTab(context, student),
    };

    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text(
            'Student',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            tooltip: 'Open menu',
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              tooltip: theme.brightness == Brightness.dark
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  theme.brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  key: ValueKey<bool>(theme.brightness == Brightness.dark),
                ),
              ),
              onPressed: () {
                final isDark = theme.brightness != Brightness.dark;
                AppTheme.themeModeNotifier.value = isDark
                    ? ThemeMode.dark
                    : ThemeMode.light;
                LocalStorageService.saveUserThemeMode(
                  student.id,
                  isDark,
                  email: student.email,
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        drawer: _buildStudentDrawer(context, student),
        body: _mobileFrame(
          context,
          StaggeredEntrance(
            key: ValueKey(activeTabIndex),
            index: 0,
            duration: const Duration(milliseconds: 280),
            child: activePage,
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex.clamp(0, 3),
          onTap: _onSelectTab,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurfaceVariant,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Classwork',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      );
  }

  Widget _mobileFrame(BuildContext context, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 600) return child;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildStudentDrawer(BuildContext context, UserModel student) {
    final theme = Theme.of(context);
    final schoolInfo = [
      if (student.gradeLevel?.isNotEmpty == true) 'Grade ${student.gradeLevel}',
      if (student.departmentOrSection?.isNotEmpty == true)
        student.departmentOrSection!,
    ].join(' · ');

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.onPrimary,
                  radius: 26,
                  child: Text(
                    student.fullName.trim().isNotEmpty
                        ? student.fullName.trim()[0].toUpperCase()
                        : 'S',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (schoolInfo.isNotEmpty)
                  Text(
                    schoolInfo,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withValues(
                        alpha: 0.82,
                      ),
                      fontSize: 12,
                    ),
                  ),
                if (student.lrn?.isNotEmpty == true)
                  Text(
                    'LRN: ${student.lrn}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withValues(
                        alpha: 0.82,
                      ),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          _drawerItem(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Attendance Records',
            onTap: () => _openPage(
              context,
              const StudentAttendanceScreen(),
              AppRoutes.studentAttendance,
            ),
          ),
          _drawerItem(
            context,
            icon: Icons.schedule_outlined,
            title: 'My Schedule',
            onTap: () => _openPage(
              context,
              StudentScheduleScreen(dashboardData: _dashboard!),
              AppRoutes.studentSchedule,
            ),
          ),
          _drawerItem(
            context,
            icon: Icons.menu_book_outlined,
            title: 'Learning Materials',
            onTap: () => _openPage(
              context,
              const StudentLearningMaterialsScreen(),
              AppRoutes.studentMaterials,
            ),
          ),
          _drawerItem(
            context,
            icon: Icons.grade_outlined,
            title: 'My Grades',
            onTap: () => _openPage(
              context,
              const StudentGradesScreen(),
              AppRoutes.studentGrades,
            ),
          ),
          _drawerItem(
            context,
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => _openPage(context, const StudentSettingsScreen()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.catRed),
            title: const Text(
              'Logout',
              style: TextStyle(color: AppTheme.catRed),
            ),
            onTap: () {
              AppModals.showConfirmationDialog(
                context: context,
                title: 'Confirm Logout',
                message:
                    'Are you sure you want to log out of the student portal?',
                confirmLabel: 'Logout',
                confirmColor: AppTheme.catRed,
                onConfirm: () async {
                  await LogoutHelper.logout(context);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }

  void _openPage(BuildContext context, Widget page, [String? route]) {
    Navigator.pop(context);
    if (route != null) {
      updateBrowserUrl(route);
      LocalStorageService.saveLastActiveRoute(route);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: route != null ? RouteSettings(name: route) : null,
        builder: (_) => page,
      ),
    ).then((_) {
      if (mounted) {
        final currentRoute = _routeForIndex(_currentIndex);
        updateBrowserUrl(currentRoute);
        LocalStorageService.saveLastActiveRoute(currentRoute);
      }
    });
  }

  void _pushDirectPage(BuildContext context, Widget page, [String? route]) {
    if (route != null) {
      updateBrowserUrl(route);
      LocalStorageService.saveLastActiveRoute(route);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: route != null ? RouteSettings(name: route) : null,
        builder: (_) => page,
      ),
    ).then((_) {
      if (mounted) {
        final currentRoute = _routeForIndex(_currentIndex);
        updateBrowserUrl(currentRoute);
        LocalStorageService.saveLastActiveRoute(currentRoute);
      }
    });
  }

  Widget _buildHomeTab(
    BuildContext context,
    UserModel student,
    List<StudentClassworkModel> classwork,
    List<StudentEnrollmentModel> enrollments,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final todoItems =
        classwork
            .where((item) {
              // 1. Must be unsubmitted / pending / returned (not already submitted, graded, or excused)
              final isPending =
                  item.status == null ||
                  item.status == 'pending' ||
                  item.status == 'returned';
              if (!isPending) return false;

              // 2. Only show upcoming items where the set deadline or date has NOT passed yet
              if (item.deadline != null && item.deadline!.isBefore(now)) {
                return false;
              }

              return true;
            })
            .toList()
          ..sort((a, b) {
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return a.deadline!.compareTo(b.deadline!);
          });

    final enrollmentLabel = [
      if (student.gradeLevel?.isNotEmpty == true) 'Grade ${student.gradeLevel}',
      if (student.departmentOrSection?.isNotEmpty == true)
        student.departmentOrSection!,
    ].join(' · ');

    return AppPullToRefresh(
      onRefresh: () => _loadDashboard(forceRefresh: true, silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // ── Polished Student Hero Card ──
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.26),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -28,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: -18,
                  bottom: -30,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    student.lrn?.isNotEmpty == true
                                        ? 'LRN: ${student.lrn}'
                                        : 'Student Portal',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  student.firstName?.isNotEmpty == true
                                      ? student.firstName!
                                      : student.fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (enrollmentLabel.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.school_outlined,
                                        size: 15,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          enrollmentLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.8,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                student.fullName.isNotEmpty
                                    ? student.fullName.trim()[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildHeroMetric(
                                icon: Icons.menu_book_rounded,
                                label: 'Enrolled',
                                value:
                                    '${enrollments.length} ${enrollments.length == 1 ? 'Subject' : 'Subjects'}',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 26,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildHeroMetric(
                                icon: Icons.pending_actions_rounded,
                                label: 'To-Do',
                                value: '${todoItems.length} Pending',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Mobile Quick Access Row (One-thumb navigation) ──
          Row(
            children: [
              _buildQuickActionTile(
                context: context,
                theme: theme,
                isDark: isDark,
                icon: Icons.fact_check_rounded,
                color: AppTheme.catGreen,
                label: 'Attendance',
                onTap: () =>
                    _pushDirectPage(context, const StudentAttendanceScreen()),
              ),
              const SizedBox(width: 10),
              _buildQuickActionTile(
                context: context,
                theme: theme,
                isDark: isDark,
                icon: Icons.calendar_month_rounded,
                color: AppTheme.catBlue,
                label: 'Schedule',
                onTap: () => _pushDirectPage(
                  context,
                  StudentScheduleScreen(dashboardData: _dashboard!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(
            theme: theme,
            title: 'To-do list',
            badgeText: '${todoItems.length} pending',
            subtitle: 'Upcoming activities and tasks from your enrolled classes.',
          ),
          const SizedBox(height: 14),
          if (todoItems.isEmpty)
            _buildEmptyCard(
              context,
              icon: Icons.task_alt_outlined,
              title: 'You are all caught up!',
              message: 'When your teacher posts an activity or assignment, it will appear here.',
            )
          else
            ...todoItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StudentClassworkCard(
                  classwork: item,
                  onRefresh: () => _loadDashboard(forceRefresh: true),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.14 : 0.09,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.18 : 0.11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required ThemeData theme,
    required String title,
    required String badgeText,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildClassworkTab(
    BuildContext context,
    List<StudentClassworkModel> items,
    List<StudentEnrollmentModel> enrollments,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (enrollments.isEmpty) {
      return AppPullToRefresh(
        onRefresh: () => _loadDashboard(forceRefresh: true, silent: true),
        child: AppPullToRefresh.scrollableState(
          child: _buildEmptyCard(
            context,
            icon: Icons.school_outlined,
            title: 'No enrolled subjects',
            message: 'You are not enrolled in any subjects yet. Once your teacher or administrator enrolls you, your classwork will appear here.',
          ),
        ),
      );
    }

    // Strictly one enrolled subject at a time (no "All Subjects" option).
    final activeEnrollment = enrollments.firstWhere(
      (e) => e.subjectId == _selectedOfferingId,
      orElse: () => enrollments.first,
    );

    final subjectItems = items.where((i) {
      final offeringId = i.subjectOfferingId;
      if (offeringId != null && offeringId.isNotEmpty) {
        return offeringId == activeEnrollment.subjectId;
      }
      return i.subjectName.trim().toLowerCase() ==
          activeEnrollment.subjectName.trim().toLowerCase();
    }).toList();

    final wwItems = subjectItems
        .where(
          (i) =>
              i.type == 'activity' ||
              i.type == 'quiz' ||
              (i.type != 'performance_task' && i.type != 'exam'),
        )
        .toList();
    final ptItems = subjectItems
        .where((i) => i.type == 'performance_task')
        .toList();
    final exItems = subjectItems
        .where((i) => i.type == 'exam')
        .toList();

    return DefaultTabController(
      key: ValueKey('student-cw-tabs-${activeEnrollment.subjectId}'),
      length: 3,
      child: Column(
        children: [
          // Enrolled subject dropdown (single select, enrolled subjects only)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.book_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ENROLLED SUBJECT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.3 : 0.6,
                      ),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: activeEnrollment.subjectId,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 22),
                      items: enrollments.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.subjectId,
                          child: Text(
                            e.subjectName.isNotEmpty
                                ? e.subjectName
                                : 'Enrolled Subject',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null && newId != _selectedOfferingId) {
                          setState(() => _selectedOfferingId = newId);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Swipeable, animated category tabs (WW / PT / EX)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                _buildClassworkTabLabel(theme, 'Written (WW)', wwItems.length),
                _buildClassworkTabLabel(theme, 'Tasks (PT)', ptItems.length),
                _buildClassworkTabLabel(theme, 'Exams (EX)', exItems.length),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildClassworkCategoryPage(
                  context: context,
                  items: wwItems,
                  emptyIcon: Icons.assignment_outlined,
                  emptyTitle: 'No written works yet',
                  emptyMessage:
                      'Written works and activities assigned by your teacher for ${activeEnrollment.subjectName} will appear here.',
                ),
                _buildClassworkCategoryPage(
                  context: context,
                  items: ptItems,
                  emptyIcon: Icons.workspace_premium_outlined,
                  emptyTitle: 'No performance tasks yet',
                  emptyMessage:
                      'Performance tasks assigned by your teacher for ${activeEnrollment.subjectName} will appear here.',
                ),
                _buildClassworkCategoryPage(
                  context: context,
                  items: exItems,
                  emptyIcon: Icons.quiz_outlined,
                  emptyTitle: 'No examinations yet',
                  emptyMessage:
                      'Periodical examinations scheduled for ${activeEnrollment.subjectName} will appear here.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassworkTabLabel(ThemeData theme, String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassworkCategoryPage({
    required BuildContext context,
    required List<StudentClassworkModel> items,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return AppPullToRefresh(
        onRefresh: () => _loadDashboard(forceRefresh: true, silent: true),
        child: AppPullToRefresh.scrollableState(
          child: _buildEmptyCard(
            context,
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
          ),
        ),
      );
    }
    return AppPullToRefresh(
      onRefresh: () => _loadDashboard(forceRefresh: true, silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => StudentClassworkCard(
          classwork: items[index],
          onRefresh: () => _loadDashboard(forceRefresh: true),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.09,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, UserModel student) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initial = student.fullName.trim().isNotEmpty
        ? student.fullName.trim()[0].toUpperCase()
        : 'S';

    return AppPullToRefresh(
      onRefresh: () => _loadDashboard(forceRefresh: true, silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    student.lrn?.trim().isNotEmpty == true
                        ? 'LRN: ${student.lrn}'
                        : 'Student Account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  student.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (student.email.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    student.email.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'STUDENT RECORD DETAILS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
          _profileField(
            context,
            isDark: isDark,
            icon: Icons.badge_outlined,
            title: 'LRN',
            value: student.lrn,
          ),
          _profileField(
            context,
            isDark: isDark,
            icon: Icons.cake_outlined,
            title: 'Birthday',
            value: student.birthday == null
                ? null
                : _formatBirthday(student.birthday!),
          ),
          _profileField(
            context,
            isDark: isDark,
            icon: Icons.person_outline,
            title: 'Gender',
            value: student.gender,
          ),
          _profileField(
            context,
            isDark: isDark,
            icon: Icons.class_outlined,
            title: 'Grade level',
            value: student.gradeLevel == null
                ? null
                : 'Grade ${student.gradeLevel}',
          ),
          _profileField(
            context,
            isDark: isDark,
            icon: Icons.groups_outlined,
            title: 'Section',
            value: student.departmentOrSection,
          ),
        ],
      ),
    );
  }

  Widget _profileField(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String? value,
  }) {
    final theme = Theme.of(context);
    final displayValue = value?.trim().isNotEmpty == true
        ? value!.trim()
        : 'Not provided';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBirthday(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
