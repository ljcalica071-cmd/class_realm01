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

  Future<void> _loadDashboard({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final dashboard = await StudentDashboardRepository.instance.loadDashboard(
        forceRefresh: forceRefresh,
      );
      AuthRepository.instance.setCurrentUser(dashboard.student);
      if (mounted) setState(() => _dashboard = dashboard);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
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
    if (_loadError != null || _dashboard == null) {
      return Scaffold(
        body: _mobileFrame(
          context,
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We could not load your student dashboard.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
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
        emptyTitle: 'No written work yet',
        emptyMessage:
            'Teacher-posted activities and assignments will appear here.',
      ),
      _buildEmptyFeature(
        context,
        icon: Icons.quiz_outlined,
        title: 'No quizzes or exams yet',
        message: 'Quizzes and exams will appear here when your teacher publishes them.',
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
            tooltip: 'Refresh dashboard',
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
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
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
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
            label: 'Written Works',
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
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.onPrimary,
                  radius: 26,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  student.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (schoolInfo.isNotEmpty)
                  Text(
                    schoolInfo,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                if (student.lrn?.isNotEmpty == true)
                  Text(
                    'LRN: ${student.lrn}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
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

  Widget _buildHomeTab(
    BuildContext context,
    UserModel student,
    List<StudentClassworkModel> classwork,
    List<StudentEnrollmentModel> enrollments,
  ) {
    final theme = Theme.of(context);
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

    return RefreshIndicator(
      onRefresh: () => _loadDashboard(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          student.lrn?.isNotEmpty == true
                              ? 'LRN: ${student.lrn}'
                              : 'Student Portal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Welcome back,',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
                            Text(
                              enrollmentLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    student.fullName.isNotEmpty
                        ? student.fullName.trim()[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (enrollments.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My Enrolled Classes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${enrollments.length} ${enrollments.length == 1 ? 'subject' : 'subjects'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your registered subjects and assigned teachers.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...enrollments.map((e) => _buildEnrollmentCard(context, e)),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'To-do list',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${pending.length} pending',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Activities and assignments from your enrolled classes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (todoItems.isEmpty)
            _emptyState(
              context,
              icon: Icons.task_alt_outlined,
              title: 'You are all caught up!',
              message: 'When your teacher posts an activity or assignment, it will appear here.',
            )
          else
            ...todoItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StudentClassworkCard(classwork: item),
              ),
            ),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.book_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.subjectCode.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.subjectCode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
                    Text(
                      '${item.sectionName.isNotEmpty ? item.sectionName : "Section"} · Grade ${item.gradeLevel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassworkTab(
    BuildContext context,
    List<StudentClassworkModel> items, {
    required String emptyTitle,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return _emptyState(
        context,
        icon: Icons.assignment_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          StudentClassworkCard(classwork: items[index]),
    );
  }

  Widget _buildEmptyFeature(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return _emptyState(context, icon: icon, title: title, message: message);
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: theme.colorScheme.onPrimaryContainer,
              ),
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
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, UserModel student) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 44,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          student.fullName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          student.email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _profileField(
          context,
          icon: Icons.badge_outlined,
          title: 'LRN',
          value: student.lrn,
        ),
        _profileField(
          context,
          icon: Icons.cake_outlined,
          title: 'Birthday',
          value: student.birthday == null
              ? null
              : _formatBirthday(student.birthday!),
        ),
        _profileField(
          context,
          icon: Icons.person_outline,
          title: 'Gender',
          value: student.gender,
        ),
        _profileField(
          context,
          icon: Icons.class_outlined,
          title: 'Grade level',
          value: student.gradeLevel == null
              ? null
              : 'Grade ${student.gradeLevel}',
        ),
        _profileField(
          context,
          icon: Icons.groups_outlined,
          title: 'Section',
          value: student.departmentOrSection,
        ),
      ],
    );
  }

  Widget _profileField(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String? value,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          value?.trim().isNotEmpty == true ? value! : 'Not provided',
        ),
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
