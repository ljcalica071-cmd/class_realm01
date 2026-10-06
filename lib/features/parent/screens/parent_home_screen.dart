import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
  bool _isSwitchingChild = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<UserModel> _getLinkedStudents(UserModel parent) {
    final List<UserModel> students = [];

    for (final u in MockDatabase.instance.users) {
      if (u.role == UserRole.student) {
        final matchesLinkedId =
            (parent.linkedStudentId != null &&
            (u.id == parent.linkedStudentId ||
                u.studentId == parent.linkedStudentId ||
                u.lrn == parent.linkedStudentId));
        final matchesParentName =
            (u.parentGuardianName != null &&
            parent.fullName.isNotEmpty &&
            u.parentGuardianName!.toLowerCase().contains(
              parent.fullName.toLowerCase(),
            ));
        final matchesParentPhone =
            (u.parentGuardianContact != null &&
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

  void _switchChildWithLoading(int targetIndex) async {
    if (_isSwitchingChild) return;
    _isSwitchingChild = true;

    final parent =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.parent,
        );
    final linkedStudents = _getLinkedStudents(parent);
    final targetChild = linkedStudents[targetIndex % linkedStudents.length];

    // Show Loading Modal / Dialog in center of screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Switching Child Profile...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Loading profile & academic logs for\n${targetChild.fullName}...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Simulate short network & state update delay
    await Future.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;

    // Pop the loading modal dialog
    Navigator.of(context, rootNavigator: true).pop();
    _isSwitchingChild = false;

    // Update state to switch student profile
    setState(() {
      _selectedChildIndex = targetIndex;
    });

    // Show floating success toast/snack
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Switched child profile to ${targetChild.fullName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
          if (idx != -1 && idx != _selectedChildIndex) {
            _switchChildWithLoading(idx);
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
        title: const Text(
          'Parent',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (linkedStudents.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Switch Child Profile (${linkedStudent.firstName})',
              onPressed: () {
                _switchChildWithLoading(_selectedChildIndex + 1);
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
              AppTheme.themeModeNotifier.value = isDark
                  ? ThemeMode.light
                  : ThemeMode.dark;
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
                    linkedStudent.gender == 'Female' ? Icons.girl : Icons.boy,
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
                      _switchChildWithLoading(_selectedChildIndex + 1);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
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
        showSelectedLabels: true,
        showUnselectedLabels: false,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
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
