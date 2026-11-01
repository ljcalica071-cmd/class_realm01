import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/utils/logout_helper.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/student_dashboard_repository.dart';
import 'package:class_realm/features/student/shared/widgets/student_classwork_card.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_academic_performance_screen.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_grades_screen.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_learning_materials_screen.dart';
import 'package:class_realm/features/student/sub_features/profile/screens/student_settings_screen.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_schedule_screen.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/features/student/sub_features/profile/widgets/student_notifications_tab.dart';
import 'package:class_realm/core/services/session_activity_tracker.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/routes/app_routes.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  String _classworkFilter = 'All';
  StudentDashboardData? _dashboard;
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final savedTab = LocalStorageService.getActiveDashboardTab('student');
    if (savedTab >= 0 && savedTab < 5) {
      _currentIndex = savedTab;
    }
    LocalStorageService.saveLastActiveRoute(AppRoutes.studentHome);
    _loadDashboard();
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
      AuthRepository.instance.setCurrentUser(dashboard.student);
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _loadError = null;
        });
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
    final pages = [
      _buildHomeTab(context, student, classwork, enrollments),
      _buildClassworkTab(
        context,
        classwork
            .where(
              (item) => item.type == 'activity' || item.type == 'assignment',
            )
            .toList(),
        emptyIcon: Icons.assignment_outlined,
        emptyTitle: 'No written work yet',
        emptyMessage:
            'Teacher-posted activities and assignments will appear here.',
      ),
      _buildClassworkTab(
        context,
        classwork
            .where((item) => item.type == 'quiz' || item.type == 'exam')
            .toList(),
        emptyIcon: Icons.quiz_outlined,
        emptyTitle: 'No quizzes or exams yet',
        emptyMessage:
            'Quizzes and exams will appear here when your teacher publishes them.',
      ),
      const StudentNotificationsTab(),
      _buildProfileTab(context, student),
    ];

    return SessionActivityTracker(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text(
            'Student',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            tooltip: 'Open menu',
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(
                theme.brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
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
            key: ValueKey(_currentIndex),
            index: 0,
            duration: const Duration(milliseconds: 280),
            child: pages[_currentIndex],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            LocalStorageService.saveActiveDashboardTab('student', index);
          },
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
              icon: Icon(Icons.quiz_outlined),
              activeIcon: Icon(Icons.quiz),
              label: 'Exam',
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
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.82),
                      fontSize: 12,
                    ),
                  ),
                if (student.lrn?.isNotEmpty == true)
                  Text(
                    'LRN: ${student.lrn}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.82),
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
            onTap: () => _openPage(context, const StudentAttendanceScreen()),
          ),
          _drawerItem(
            context,
            icon: Icons.schedule_outlined,
            title: 'My Schedule',
            onTap: () => _openPage(
              context,
              StudentScheduleScreen(dashboardData: _dashboard!),
            ),
          ),
          _drawerItem(
            context,
            icon: Icons.menu_book_outlined,
            title: 'Learning Materials',
            onTap: () =>
                _openPage(context, const StudentLearningMaterialsScreen()),
          ),
          _drawerItem(
            context,
            icon: Icons.grade_outlined,
            title: 'My Grades',
            onTap: () => _openPage(context, const StudentGradesScreen()),
          ),
          _drawerItem(
            context,
            icon: Icons.school_outlined,
            title: 'My Academic Performance',
            onTap: () =>
                _openPage(context, const StudentAcademicPerformanceScreen()),
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

  void _openPage(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _pushDirectPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildHomeTab(
    BuildContext context,
    UserModel student,
    List<StudentClassworkModel> classwork,
    List<StudentEnrollmentModel> enrollments,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pending =
        classwork
            .where(
              (item) =>
                  item.status == null ||
                  item.status == 'pending' ||
                  item.status == 'returned',
            )
            .toList()
          ..sort((a, b) {
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return a.deadline!.compareTo(b.deadline!);
          });
    final todoItems = pending;
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
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
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
                              radius: 28,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                student.fullName.isNotEmpty
                                    ? student.fullName.trim()[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
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
                                value: '${pending.length} Pending',
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
              const SizedBox(width: 10),
              _buildQuickActionTile(
                context: context,
                theme: theme,
                isDark: isDark,
                icon: Icons.folder_copy_rounded,
                color: AppTheme.catOrange,
                label: 'Materials',
                onTap: () => _pushDirectPage(
                  context,
                  const StudentLearningMaterialsScreen(),
                ),
              ),
              const SizedBox(width: 10),
              _buildQuickActionTile(
                context: context,
                theme: theme,
                isDark: isDark,
                icon: Icons.grade_rounded,
                color: AppTheme.catTeal,
                label: 'Grades',
                onTap: () =>
                    _pushDirectPage(context, const StudentGradesScreen()),
              ),
            ],
          ),

          if (enrollments.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              theme: theme,
              title: 'My Enrolled Classes',
              badgeText:
                  '${enrollments.length} ${enrollments.length == 1 ? 'subject' : 'subjects'}',
              subtitle: 'Your registered subjects and assigned teachers.',
            ),
            const SizedBox(height: 12),
            ...enrollments.map((e) => _buildEnrollmentCard(context, e)),
          ],
          const SizedBox(height: 24),
          _buildSectionHeader(
            theme: theme,
            title: 'To-do list',
            badgeText: '${pending.length} pending',
            subtitle: 'Activities and assignments from your enrolled classes.',
          ),
          const SizedBox(height: 14),
          if (todoItems.isEmpty)
            _buildEmptyCard(
              context,
              icon: Icons.task_alt_outlined,
              title: 'You are all caught up!',
              message:
                  'When your teacher posts an activity or assignment, it will appear here.',
            )
          else
            ...todoItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StudentClassworkCard(classwork: item, onRefresh: () => _loadDashboard(forceRefresh: true)),
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
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
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
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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

  Widget _buildEnrollmentCard(
    BuildContext context,
    StudentEnrollmentModel item,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.subjectCode.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.subjectCode,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          Text(
                            item.subjectName.isNotEmpty
                                ? item.subjectName
                                : 'Enrolled Subject',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.teacherName.isNotEmpty
                                      ? 'Teacher: ${item.teacherName}'
                                      : 'Assigned Teacher',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${item.sectionName.isNotEmpty ? item.sectionName : "Section"} · Grade ${item.gradeLevel}',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassworkTab(
    BuildContext context,
    List<StudentClassworkModel> items, {
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
    bool showFilterChips = false,
  }) {
    final theme = Theme.of(context);
    final totalAll = items.length;
    final totalWw = items.where((i) => i.type != 'performance_task').length;
    final totalPt = items.where((i) => i.type == 'performance_task').length;

    final filtered = showFilterChips
        ? items.where((item) {
            if (_classworkFilter == 'WW') {
              return item.type != 'performance_task';
            }
            if (_classworkFilter == 'PT') {
              return item.type == 'performance_task';
            }
            return true;
          }).toList()
        : items;

    Widget content;
    if (filtered.isEmpty) {
      final currentEmptyTitle = showFilterChips
          ? (_classworkFilter == 'PT'
              ? 'No performance tasks yet'
              : (_classworkFilter == 'WW'
                  ? 'No written works or activities yet'
                  : emptyTitle))
          : emptyTitle;

      final currentEmptyMessage = showFilterChips
          ? (_classworkFilter == 'PT'
              ? 'Performance tasks assigned by your teacher will appear here.'
              : (_classworkFilter == 'WW'
                  ? 'Activities and written works assigned by your teacher will appear here.'
                  : emptyMessage))
          : emptyMessage;

      final currentEmptyIcon = showFilterChips && _classworkFilter == 'PT'
          ? Icons.workspace_premium_outlined
          : emptyIcon;

      content = AppPullToRefresh.scrollableState(
        child: _buildEmptyCard(
          context,
          icon: currentEmptyIcon,
          title: currentEmptyTitle,
          message: currentEmptyMessage,
        ),
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => StudentClassworkCard(
          classwork: filtered[index],
          onRefresh: () => _loadDashboard(forceRefresh: true),
        ),
      );
    }

    return AppPullToRefresh(
      onRefresh: () => _loadDashboard(forceRefresh: true, silent: true),
      child: showFilterChips
          ? Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildClassworkFilterChip(
                        label: 'All',
                        count: totalAll,
                        isSelected: _classworkFilter == 'All',
                        onSelected: () =>
                            setState(() => _classworkFilter = 'All'),
                      ),
                      const SizedBox(width: 8),
                      _buildClassworkFilterChip(
                        label: 'Activities (WW)',
                        count: totalWw,
                        isSelected: _classworkFilter == 'WW',
                        onSelected: () =>
                            setState(() => _classworkFilter = 'WW'),
                      ),
                      const SizedBox(width: 8),
                      _buildClassworkFilterChip(
                        label: 'Tasks (PT)',
                        count: totalPt,
                        isSelected: _classworkFilter == 'PT',
                        onSelected: () =>
                            setState(() => _classworkFilter = 'PT'),
                      ),
                    ],
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

  Widget _buildClassworkFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
                    radius: 34,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 28,
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
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
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
