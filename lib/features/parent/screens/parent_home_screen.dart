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
  int _selectedChildIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<UserModel> _getLinkedStudents(UserModel parent) {
    final List<UserModel> students = [];

    for (final u in MockDatabase.instance.users) {
      if (u.role == UserRole.student) {
        final matchesLinkedId = (parent.linkedStudentId != null &&
            (u.id == parent.linkedStudentId ||
                u.studentId == parent.linkedStudentId ||
                u.lrn == parent.linkedStudentId));
        final matchesParentName = (u.parentGuardianName != null &&
            parent.fullName.isNotEmpty &&
            u.parentGuardianName!.toLowerCase().contains(parent.fullName.toLowerCase()));
        final matchesParentPhone = (u.parentGuardianContact != null &&
            parent.contactNumber != null &&
            u.parentGuardianContact == parent.contactNumber);
        final isReyesFamily =
            (parent.fullName.contains('Reyes') && u.lastName == 'Reyes');

        if (matchesLinkedId ||
            matchesParentName ||
            matchesParentPhone ||
            isReyesFamily) {
          if (!students.any((s) => s.id == u.id)) {
            students.add(u);
          }
        }
      }
    }

    if (students.isEmpty) {
      final defaultStudent = MockDatabase.instance.users.firstWhere(
        (u) => u.role == UserRole.student,
      );
      students.add(defaultStudent);
    }

    return students;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parent =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.parent,
        );

    final linkedStudents = _getLinkedStudents(parent);
    final linkedStudent =
        linkedStudents[_selectedChildIndex % linkedStudents.length];

    final attendance = MockDatabase.instance.attendanceRecords;
    final notifications = MockDatabase.instance.notifications
        .where(
          (notification) =>
              notification.type == 'attendance' &&
              notification.title == 'Attendance Confirmed',
        )
        .toList();

    final linkedAttendance = attendance
        .where(
          (record) =>
              record.studentId == linkedStudent.id ||
              record.studentId == linkedStudent.lrn ||
              record.studentId == linkedStudent.studentId,
        )
        .toList();

    final teacher = MockDatabase.instance.users.firstWhere(
      (u) => u.role == UserRole.teacher,
    );

    final List<Widget> pages = [
      ParentStudentOverviewTab(
        linkedStudent: linkedStudent,
        teacher: teacher,
        allChildren: linkedStudents,
        onSelectChild: (child) {
          final idx = linkedStudents.indexWhere((c) => c.id == child.id);
          if (idx != -1) {
            setState(() => _selectedChildIndex = idx);
          }
        },
      ),
      ParentAttendanceTab(attendance: linkedAttendance),
      ParentGradesTab(student: linkedStudent),
      ParentNotificationsTab(notifications: notifications),
      ParentProfileTab(parent: parent, linkedStudent: linkedStudent),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Parent',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (linkedStudents.length > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${linkedStudents.length} Children',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (linkedStudents.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Switch Child (${linkedStudent.firstName})',
              onPressed: () {
                setState(() {
                  _selectedChildIndex =
                      (_selectedChildIndex + 1) % linkedStudents.length;
                });
                final nextStudent =
                    linkedStudents[_selectedChildIndex % linkedStudents.length];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to ${nextStudent.fullName}'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
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
      body: Column(
        children: [
          // Active Child Banner (if parent has multiple children)
          if (linkedStudents.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Icon(
                    linkedStudent.gender == 'Female'
                        ? Icons.girl
                        : Icons.boy,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Child: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${linkedStudent.fullName} (${linkedStudent.departmentOrSection})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedChildIndex =
                            (_selectedChildIndex + 1) % linkedStudents.length;
                      });
                      final nextStudent = linkedStudents[
                          _selectedChildIndex % linkedStudents.length];
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched to ${nextStudent.fullName}'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Switch',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: pages[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor:
            theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
