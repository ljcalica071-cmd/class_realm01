import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../models/academic_models.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/sync_status_badge.dart';
import '../../../widgets/common/app_modals.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final attendance = MockDatabase.instance.attendanceRecords;
    final notifications = MockDatabase.instance.notifications;
    final parent = MockDatabase.instance.currentUser ?? MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.parent);
    final linkedStudent = MockDatabase.instance.users.firstWhere(
      (u) => u.id == parent.linkedStudentId,
      orElse: () => MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.student),
    );
    final teacher = MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.teacher);

    final List<Widget> pages = [
      _buildStudentOverviewTab(attendance, linkedStudent, teacher),
      _buildAttendanceLogTab(attendance),
      _buildGradesTab(),
      _buildNotificationsTab(notifications),
      _buildProfileTab(parent),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('ClassRealm Parent Portal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: const [
          Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: SyncStatusBadge())),
        ],
      ),
      drawer: _buildParentDrawer(context),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), activeIcon: Icon(Icons.fact_check), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.grade_outlined), activeIcon: Icon(Icons.grade), label: 'Grades'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildParentDrawer(BuildContext context) {
    final parent = MockDatabase.instance.currentUser ?? MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.parent);
    final linkedStudent = MockDatabase.instance.users.firstWhere(
      (u) => u.id == parent.linkedStudentId,
      orElse: () => MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.student),
    );
    final teacher = MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.teacher);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(backgroundColor: Colors.white, radius: 28, child: Icon(Icons.family_restroom, size: 32, color: AppColors.primary)),
                SizedBox(height: 10),
                Text(parent.fullName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Linked Student: ${linkedStudent.fullName} (${linkedStudent.departmentOrSection})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text("Student's Schedule"),
            onTap: () {
              Navigator.pop(context);
              AppModals.showSuccessDialog(context: context, title: 'Class Schedule', message: 'General Mathematics: Mon/Wed 07:30 AM.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_phone_outlined),
            title: const Text("Teacher Contact"),
            onTap: () {
              Navigator.pop(context);
              AppModals.showSuccessDialog(context: context, title: 'Adviser Contact', message: '${teacher.fullName} • ${teacher.email}');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Logout', style: TextStyle(color: AppColors.error)),
            onTap: () {
              MockDatabase.instance.logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentOverviewTab(
    List<AttendanceRecord> attendance,
    UserModel linkedStudent,
    UserModel teacher,
  ) {
    final quarterGrade = MockDatabase.instance.quarterlyGradeFor(linkedStudent.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: AppColors.primaryLight, radius: 28, child: Icon(Icons.school, color: Colors.white, size: 30)),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Linked Student Profile', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text(linkedStudent.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Grade ${linkedStudent.gradeLevel} - ${linkedStudent.departmentOrSection} • ID: ${linkedStudent.studentId}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Today's Attendance Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 28),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time In: 07:28 AM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('RFID Tap at Main Gate (ESP32)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                StatusBadge(text: 'Present', backgroundColor: AppColors.successLight, textColor: AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Quarterly Academic Standing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('General Mathematics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(teacher.fullName, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                Text('${quarterGrade.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceLogTab(List<AttendanceRecord> attendance) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: attendance.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final att = attendance[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(att.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Time In: ${att.timeIn} • Method: ${att.method}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              StatusBadge.fromAttendance(att.status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGradesTab() {
    final parent = MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.parent);
    final student = MockDatabase.instance.users.firstWhere(
      (u) => u.id == parent.linkedStudentId,
      orElse: () => MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.student),
    );
    final database = MockDatabase.instance;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Grade Breakdown & Component Scores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ListTile(
              title: Text('Examinations (30%)'),
              trailing: Text('${database.categoryAverageFor(student.id, 'Examinations').toStringAsFixed(1)} / 100'),
            ),
            Divider(),
            ListTile(
              title: Text('Written Works (20%)'),
              trailing: Text('${database.categoryAverageFor(student.id, 'Written Works').toStringAsFixed(1)} / 100'),
            ),
            Divider(),
            ListTile(
              title: Text('Performance Task (50%)'),
              trailing: Text('${database.categoryAverageFor(student.id, 'Performance Task').toStringAsFixed(1)} / 100'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(List<AppNotificationModel> notifications) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final n = notifications[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              const Icon(Icons.notifications, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(n.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(UserModel parent) {
    final linkedStudent = MockDatabase.instance.users.firstWhere(
      (u) => u.id == parent.linkedStudentId,
      orElse: () => MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.student),
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircleAvatar(radius: 40, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 48, color: Colors.white)),
          const SizedBox(height: 16),
          Text(parent.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(parent.email, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('Linked Student'),
            subtitle: Text('${linkedStudent.fullName} (${linkedStudent.departmentOrSection})'),
          ),
          ListTile(leading: const Icon(Icons.phone), title: Text('Contact Number'), subtitle: Text(parent.contactNumber ?? '+63 917 123 4567')),
        ],
      ),
    );
  }
}
