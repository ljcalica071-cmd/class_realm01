import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/sync_status_badge.dart';
import 'package:class_realm/features/parent/widgets/widgets.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  UserModel? _findLinkedStudent(UserModel parent) {
    final linkedId = parent.linkedStudentId;
    if (linkedId == null) return null;
    for (final user in MockDatabase.instance.users) {
      if (user.role == UserRole.student && user.id == linkedId) {
        return user;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attendance = MockDatabase.instance.attendanceRecords;
    final notifications = MockDatabase.instance.notifications
        .where(
          (notification) =>
              notification.type == 'attendance' &&
              notification.title == 'Attendance Confirmed',
        )
        .toList();
    final parent =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.parent,
        );
    final linkedStudent = _findLinkedStudent(parent);
    final linkedAttendance = attendance
        .where(
          (record) =>
              linkedStudent != null &&
              (record.studentId == linkedStudent.id ||
                  record.studentId == linkedStudent.lrn ||
                  record.studentId == linkedStudent.studentId),
        )
        .toList();
    final teacher = MockDatabase.instance.users.firstWhere(
      (u) => u.role == UserRole.teacher,
    );

    final List<Widget> pages = [
      ParentStudentOverviewTab(
        linkedStudent: linkedStudent,
        teacher: teacher,
      ),
      ParentAttendanceTab(attendance: linkedAttendance),
      ParentGradesTab(student: linkedStudent),
      ParentNotificationsTab(notifications: notifications),
      ParentProfileTab(parent: parent, linkedStudent: linkedStudent),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Parent',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        // Let the AppBarTheme in app_theme.dart handle colors
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              final isDark = theme.brightness == Brightness.dark;
              AppTheme.themeModeNotifier.value =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SyncStatusBadge(),
            ),
          ),
        ],
      ),
      drawer: ParentDrawer(
        parent: parent,
        linkedStudent: linkedStudent,
        teacher: teacher,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            activeIcon: Icon(Icons.fact_check),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grade_outlined),
            activeIcon: Icon(Icons.grade),
            label: 'Grades',
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
}
