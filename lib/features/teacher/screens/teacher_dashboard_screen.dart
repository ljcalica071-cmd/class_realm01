import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../models/academic_models.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/sync_status_badge.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  // Controllers for CRUD forms
  final _studentNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _actTitleCtrl = TextEditingController();
  final _actDescCtrl = TextEditingController();
  final _quizTitleCtrl = TextEditingController();
  final _quizDescCtrl = TextEditingController();
  final _lessonTopicCtrl = TextEditingController();

  @override
  void dispose() {
    _studentNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _actTitleCtrl.dispose();
    _actDescCtrl.dispose();
    _quizTitleCtrl.dispose();
    _quizDescCtrl.dispose();
    _lessonTopicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = MockDatabase.instance.users.where((u) => u.role == UserRole.student).toList();
    final activities = MockDatabase.instance.activities;
    final quizzes = MockDatabase.instance.quizzesAndExams;
    final attendance = MockDatabase.instance.attendanceRecords;
    final lessonPlans = MockDatabase.instance.lessonPlans;
    final materials = MockDatabase.instance.materials;
    final schedules = MockDatabase.instance.schedules;
    final criteria = MockDatabase.instance.gradingCriteria;
    final examReviews = MockDatabase.instance.examReviews;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarExpanded ? 260 : 80,
            color: AppColors.sidebarBg,
            child: Column(
              children: [
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.white, size: 28),
                      if (_isSidebarExpanded) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'CLASSREALM',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),

                // Teacher Navigation Items
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined),
                      _buildNavItem(1, 'Academic Setup', Icons.settings_accessibility),
                      _buildNavItem(2, 'Students', Icons.groups_outlined),
                      _buildNavItem(3, 'Attendance', Icons.fact_check_outlined),
                      _buildNavItem(4, 'Activities', Icons.assignment_outlined),
                      _buildNavItem(5, 'Quizzes & Exams', Icons.quiz_outlined),
                      _buildNavItem(6, 'Exam Checker', Icons.checklist_rtl),
                      _buildNavItem(7, 'Item Analysis', Icons.insights),
                      _buildNavItem(8, 'Grading System', Icons.pie_chart_outline),
                      _buildNavItem(9, 'Grades', Icons.grade_outlined),
                      _buildNavItem(10, 'Performance', Icons.trending_up),
                      _buildNavItem(11, 'Lesson Planning', Icons.psychology_outlined),
                      _buildNavItem(12, 'Learning Materials', Icons.menu_book_outlined),
                      _buildNavItem(13, 'Schedule', Icons.schedule_outlined),
                      _buildNavItem(14, 'Notifications', Icons.notifications_outlined),
                      _buildNavItem(15, 'Profile', Icons.person_outline),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: _isSidebarExpanded ? const Text('Logout', style: TextStyle(color: AppColors.error)) : null,
                  onTap: () {
                    MockDatabase.instance.logout();
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main Area
          Expanded(
            child: Column(
              children: [
                // Top App Bar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSidebarExpanded ? Icons.menu_open : Icons.menu),
                        onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _getTeacherTitle(_selectedIndex),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      const SyncStatusBadge(),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          MockDatabase.instance.currentUser?.fullName.substring(0, 1) ?? 'T',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            MockDatabase.instance.currentUser?.fullName ?? 'Prof. Maria Santos',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          const Text(
                            'Grade 11 Mathematics Teacher',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content View
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: _buildTeacherBodyContent(students, activities, quizzes, attendance, lessonPlans, materials, schedules, criteria, examReviews),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTeacherTitle(int index) {
    switch (index) {
      case 0:
        return 'Teacher Dashboard Overview';
      case 1:
        return 'Academic Setup & Configuration';
      case 2:
        return 'Student Management';
      case 3:
        return 'Attendance Tracker & RFID Log';
      case 4:
        return 'Activity & Requirement Manager';
      case 5:
        return 'Quizzes & Examinations';
      case 6:
        return 'Exam Auto-Checker & Scoring';
      case 7:
        return 'Item Analysis Dashboard';
      case 8:
        return 'Grading System Weighting';
      case 9:
        return 'Student Grades & Breakdown';
      case 10:
        return 'Performance Analytics';
      case 11:
        return 'AI Lesson Plan Generator';
      case 12:
        return 'Learning Materials Repository';
      case 13:
        return 'Schedule & Timetable';
      case 14:
        return 'Notifications & Alerts';
      case 15:
        return 'Teacher Profile';
      default:
        return 'Teacher Portal';
    }
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sidebarItemActive : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppColors.textMuted, size: 18),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: isSelected ? Colors.white : AppColors.textMuted, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherBodyContent(
    List<UserModel> students,
    List<ActivityModel> activities,
    List<QuizOrExamModel> quizzes,
    List<AttendanceRecord> attendance,
    List<LessonPlanModel> lessonPlans,
    List<LearningMaterialModel> materials,
    List<ScheduleModel> schedules,
    List<GradingCriteria> criteria,
    List<ExamSubmissionReview> examReviews,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview(students, activities, quizzes, attendance);
      case 1:
        return _buildAcademicSetupTab();
      case 2:
        return _buildStudentManagementTab(students);
      case 3:
        return _buildAttendanceTab(attendance);
      case 4:
        return _buildActivitiesTab(activities);
      case 5:
        return _buildQuizzesTab(quizzes);
      case 6:
        return _buildExamCheckerTab(examReviews, quizzes);
      case 7:
        return _buildItemAnalysisTab(quizzes);
      case 8:
        return _buildGradingSystemTab(criteria);
      case 9:
        return _buildGradesTab(students);
      case 10:
        return _buildPerformanceTab(students);
      case 11:
        return _buildLessonPlanningTab(lessonPlans);
      case 12:
        return _buildLearningMaterialsTab(materials);
      case 13:
        return _buildScheduleTab(schedules);
      case 14:
        return _buildNotificationsTab();
      case 15:
        return _buildProfileTab();
      default:
        return const Center(child: Text('Feature coming up'));
    }
  }

  // --- 0. Dashboard Overview ---
  Widget _buildDashboardOverview(List<UserModel> students, List<ActivityModel> activities, List<QuizOrExamModel> quizzes, List<AttendanceRecord> attendance) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome back, Prof. Santos!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text("Here's your academic summary for Grade 11 Mathematics today.", style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          // Cards Row
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.6,
            children: [
              _buildMetricCard('Enrolled Students', '${students.length}', Icons.groups, AppColors.primary),
              _buildMetricCard("Today's Attendance", '${attendance.where((a) => a.status == AttendanceStatus.present).length} Present', Icons.fact_check, AppColors.success),
              _buildMetricCard('Pending Activities', '${activities.length}', Icons.assignment, AppColors.warning),
              _buildMetricCard('Upcoming Quizzes', '${quizzes.length}', Icons.quiz, AppColors.info),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Submissions & Schedule Quick View
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Student Submissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: MockDatabase.instance.activitySubmissions.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final sub = MockDatabase.instance.activitySubmissions[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(backgroundColor: AppColors.successLight, child: Icon(Icons.check, color: AppColors.success)),
                            title: Text(sub.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Submitted: ${sub.attachedFile ?? "Worksheet"}'),
                            trailing: Text('${sub.score ?? 0} / ${sub.maxScore}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Today's Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...MockDatabase.instance.schedules.take(2).map((s) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.subject, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const SizedBox(height: 4),
                                Text('${s.section} • ${s.room}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text('${s.startTime} - ${s.endTime}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // --- 1. Academic Setup ---
  Widget _buildAcademicSetupTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Teacher Academic Setup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Define your active academic year, grade level, sections, and subjects.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            TextField(controller: TextEditingController(text: MockDatabase.instance.academicYear), decoration: const InputDecoration(labelText: 'Academic Year')),
            const SizedBox(height: 16),
            TextField(controller: TextEditingController(text: MockDatabase.instance.gradeLevel), decoration: const InputDecoration(labelText: 'Grade Level')),
            const SizedBox(height: 16),
            TextField(controller: TextEditingController(text: MockDatabase.instance.currentSubject), decoration: const InputDecoration(labelText: 'Primary Subject')),
            const SizedBox(height: 16),
            const Text('Managed Sections:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: MockDatabase.instance.sections.map((sec) => Chip(label: Text(sec))).toList(),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Save Academic Configuration',
              onPressed: () {
                AppModals.showSuccessDialog(context: context, title: 'Configuration Saved', message: 'Your academic setup has been updated successfully.');
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Student Management ---
  Widget _buildStudentManagementTab(List<UserModel> students) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Student Roster & Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              AppPrimaryButton(
                label: 'Add Student',
                icon: Icons.person_add,
                onPressed: () => _showAddStudentModal(context),
                height: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: ListView.separated(
                itemCount: students.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final s = students[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primaryLight, child: Text(s.fullName.substring(0, 1), style: const TextStyle(color: Colors.white))),
                    title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${s.studentId ?? "N/A"} • Section: ${s.departmentOrSection ?? "STEM 11-A"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge.fromAccountStatus(s.status),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () {
                            setState(() {
                              MockDatabase.instance.users.removeWhere((u) => u.id == s.id);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStudentModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Student'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _studentNameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: _studentIdCtrl, decoration: const InputDecoration(labelText: 'Student ID (e.g. 2024-SHS-0199)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AppPrimaryButton(
            label: 'Save Student',
            onPressed: () {
              if (_studentNameCtrl.text.isEmpty) return;
              setState(() {
                MockDatabase.instance.users.add(
                  UserModel(
                    id: 'usr_s_${DateTime.now().millisecondsSinceEpoch}',
                    username: 'student_${DateTime.now().millisecond}',
                    fullName: _studentNameCtrl.text.trim(),
                    email: 'student@classrealm.edu',
                    role: UserRole.student,
                    status: AccountStatus.active,
                    studentId: _studentIdCtrl.text.trim().isEmpty ? '2024-SHS-0999' : _studentIdCtrl.text.trim(),
                    departmentOrSection: 'STEM 11-A',
                  ),
                );
              });
              _studentNameCtrl.clear();
              _studentIdCtrl.clear();
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(context: context, title: 'Student Added', message: 'Student successfully added to roster.');
            },
            width: 120,
            height: 40,
          ),
        ],
      ),
    );
  }

  // --- 3. Attendance Tracker ---
  Widget _buildAttendanceTab(List<AttendanceRecord> attendance) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attendance & RFID Tap Log (ESP32 Simulation)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                icon: const Icon(Icons.nfc),
                label: const Text('Simulate RFID Tap'),
                onPressed: () {
                  setState(() {
                    MockDatabase.instance.toggleAttendance('2024-SHS-0104', AttendanceStatus.present);
                  });
                  AppModals.showSuccessDialog(context: context, title: 'RFID Tap Detected', message: 'Student Carlos Yulo tapped RFID at Main Gate (08:05 AM). Marked Present.');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: ListView.separated(
                itemCount: attendance.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final att = attendance[i];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.infoLight, child: Icon(Icons.badge, color: AppColors.info)),
                    title: Text(att.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${att.studentId} • Section: ${att.section} • Time: ${att.timeIn} • Method: ${att.method}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge.fromAttendance(att.status),
                        const SizedBox(width: 12),
                        DropdownButton<AttendanceStatus>(
                          value: att.status,
                          items: AttendanceStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
                          onChanged: (newStatus) {
                            if (newStatus != null) {
                              setState(() {
                                MockDatabase.instance.toggleAttendance(att.studentId, newStatus);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Activities ---
  Widget _buildActivitiesTab(List<ActivityModel> activities) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Activities & Requirements Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              AppPrimaryButton(
                label: 'Create Activity',
                icon: Icons.add,
                onPressed: () => _showCreateActivityModal(context),
                height: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final act = activities[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment, color: AppColors.primary, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(act.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(act.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('Max Score: ${act.maxScore} • Submissions: ${act.submissionsCount}/${act.totalStudents}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () {
                          setState(() {
                            MockDatabase.instance.deleteActivity(act.id);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateActivityModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Activity'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _actTitleCtrl, decoration: const InputDecoration(labelText: 'Activity Title')),
              const SizedBox(height: 12),
              TextField(controller: _actDescCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions / Description')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AppPrimaryButton(
            label: 'Publish Activity',
            onPressed: () {
              if (_actTitleCtrl.text.isEmpty) return;
              setState(() {
                MockDatabase.instance.addActivity(
                  ActivityModel(
                    id: 'act_${DateTime.now().millisecondsSinceEpoch}',
                    title: _actTitleCtrl.text.trim(),
                    description: _actDescCtrl.text.trim(),
                    subject: 'General Mathematics',
                    section: 'STEM 11-A',
                    deadline: DateTime.now().add(const Duration(days: 3)),
                    maxScore: 50.0,
                    isPublished: true,
                  ),
                );
              });
              _actTitleCtrl.clear();
              _actDescCtrl.clear();
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(context: context, title: 'Activity Published', message: 'Activity successfully created and broadcasted to students.');
            },
            width: 130,
            height: 40,
          ),
        ],
      ),
    );
  }

  // --- 5. Quizzes & Exams ---
  Widget _buildQuizzesTab(List<QuizOrExamModel> quizzes) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quizzes & Examinations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              AppPrimaryButton(
                label: 'Create Quiz / Exam',
                icon: Icons.note_add,
                onPressed: () => _showCreateQuizModal(context),
                height: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: quizzes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final q = quizzes[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Icon(q.isExam ? Icons.description : Icons.quiz, color: q.isExam ? AppColors.error : AppColors.primary, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(q.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  text: q.isExam ? 'EXAM' : 'QUIZ',
                                  backgroundColor: q.isExam ? AppColors.errorLight : AppColors.infoLight,
                                  textColor: q.isExam ? AppColors.error : AppColors.info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(q.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('Duration: ${q.durationMinutes} mins • Questions: ${q.questions.length} • Total Points: ${q.totalPoints}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () {
                          setState(() {
                            MockDatabase.instance.deleteQuizOrExam(q.id);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateQuizModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Quiz / Exam'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _quizTitleCtrl, decoration: const InputDecoration(labelText: 'Quiz / Exam Title')),
              const SizedBox(height: 12),
              TextField(controller: _quizDescCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AppPrimaryButton(
            label: 'Save Assessment',
            onPressed: () {
              if (_quizTitleCtrl.text.isEmpty) return;
              setState(() {
                MockDatabase.instance.addQuizOrExam(
                  QuizOrExamModel(
                    id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
                    title: _quizTitleCtrl.text.trim(),
                    description: _quizDescCtrl.text.trim(),
                    subject: 'General Mathematics',
                    section: 'STEM 11-A',
                    isExam: false,
                    durationMinutes: 45,
                    scheduleDate: DateTime.now().add(const Duration(days: 2)),
                    questions: [
                      QuestionModel(
                        id: 'qp_1',
                        questionText: 'Sample Question 1: What is 2 + 2?',
                        type: QuestionType.multipleChoice,
                        choices: ['3', '4', '5'],
                        correctAnswer: '4',
                        points: 5.0,
                      ),
                    ],
                  ),
                );
              });
              _quizTitleCtrl.clear();
              _quizDescCtrl.clear();
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(context: context, title: 'Quiz Created', message: 'Assessment created successfully.');
            },
            width: 130,
            height: 40,
          ),
        ],
      ),
    );
  }

  // --- 6. Exam Checker ---
  Widget _buildExamCheckerTab(List<ExamSubmissionReview> examReviews, List<QuizOrExamModel> quizzes) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exam Auto-Checker & Scoring', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Review student submissions, compare answers against the key, and finalize scores.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: examReviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final rev = examReviews[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.fact_check, color: AppColors.success, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rev.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Calculated Auto-Score: ${rev.calculatedScore} / 20.0', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                      AppPrimaryButton(
                        label: 'Review Answers',
                        height: 38,
                        width: 130,
                        onPressed: () {
                          AppModals.showSuccessDialog(context: context, title: 'Exam Verified', message: 'All objective answers for ${rev.studentName} verified and matched with answer key.');
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 7. Item Analysis ---
  Widget _buildItemAnalysisTab(List<QuizOrExamModel> quizzes) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Item Analysis Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Evaluate question difficulty index and student correctness percentages.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quiz 1: Functions & Domain/Range - Item Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(color: AppColors.border, width: 1),
                  columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(3), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
                  children: const [
                    TableRow(
                      decoration: BoxDecoration(color: AppColors.background),
                      children: [
                        Padding(padding: EdgeInsets.all(10), child: Text('Q #', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(10), child: Text('Question Concept', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(10), child: Text('% Correct', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(10), child: Text('Difficulty', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    TableRow(children: [
                      Padding(padding: EdgeInsets.all(10), child: Text('1')),
                      Padding(padding: EdgeInsets.all(10), child: Text('Domain of rational function')),
                      Padding(padding: EdgeInsets.all(10), child: Text('85%')),
                      Padding(padding: EdgeInsets.all(10), child: Text('Easy', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                    ]),
                    TableRow(children: [
                      Padding(padding: EdgeInsets.all(10), child: Text('2')),
                      Padding(padding: EdgeInsets.all(10), child: Text('Vertical asymptote true/false')),
                      Padding(padding: EdgeInsets.all(10), child: Text('65%')),
                      Padding(padding: EdgeInsets.all(10), child: Text('Moderate', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold))),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 8. Grading System ---
  Widget _buildGradingSystemTab(List<GradingCriteria> criteria) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Teacher-Defined Grading Weighting System', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Admin does NOT control these weights. Configure your component percentages here.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ...criteria.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Expanded(
                        flex: 1,
                        child: Text('${c.percentage}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 32),
            AppPrimaryButton(
              label: 'Update Weighting Criteria',
              onPressed: () {
                AppModals.showSuccessDialog(context: context, title: 'Criteria Updated', message: 'Grading percentages successfully updated for score calculations.');
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 9. Grades ---
  Widget _buildGradesTab(List<UserModel> students) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Student Grades & Calculation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: ListView.separated(
                itemCount: students.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final s = students[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.accent, child: Text(s.fullName.substring(0, 1), style: const TextStyle(color: Colors.white))),
                    title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${s.studentId} • Calculated Quarter Grade'),
                    trailing: const Text('92.5 (A)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 10. Performance Analytics ---
  Widget _buildPerformanceTab(List<UserModel> students) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Analytics & At-Risk Alerts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Class Average', '88.4%', Icons.trending_up, AppColors.success)),
              const SizedBox(width: 20),
              Expanded(child: _buildMetricCard('Students At Risk (< 75)', '2', Icons.warning_amber, AppColors.error)),
              const SizedBox(width: 20),
              Expanded(child: _buildMetricCard('Honor Roll (> 90)', '14', Icons.emoji_events, AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  // --- 11. Lesson Planning ---
  Widget _buildLessonPlanningTab(List<LessonPlanModel> lessonPlans) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AI Lesson Plan Generator (Simulated)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              AppPrimaryButton(
                label: 'Generate New Lesson Plan',
                icon: Icons.auto_awesome,
                onPressed: () {
                  setState(() {
                    MockDatabase.instance.generateLessonPlan(
                      topic: 'Logarithmic Properties and Real Applications',
                      gradeLevel: 'Grade 11',
                      subject: 'General Mathematics',
                      duration: '60 minutes',
                    );
                  });
                  AppModals.showSuccessDialog(context: context, title: 'AI Lesson Plan Generated', message: 'Simulated AI generated a comprehensive lesson plan for Logarithmic Properties.');
                },
                height: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: lessonPlans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final lp = lessonPlans[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lp.topic, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                          const StatusBadge(text: 'AI Generated', backgroundColor: AppColors.infoLight, textColor: AppColors.info),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Duration: ${lp.duration} • Created: ${lp.createdAt.toLocal().toString().split(' ')[0]}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Objectives:\n${lp.objectives}', style: const TextStyle(fontSize: 13, height: 1.3)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 12. Learning Materials ---
  Widget _buildLearningMaterialsTab(List<LearningMaterialModel> materials) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Learning Materials Repository', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              AppPrimaryButton(
                label: 'Upload Material',
                icon: Icons.upload_file,
                onPressed: () {
                  AppModals.showSuccessDialog(context: context, title: 'Material Uploaded', message: 'Simulated document successfully added to student repository.');
                },
                height: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: materials.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final mat = materials[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: AppColors.error, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mat.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(mat.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('File: ${mat.fileName} • Size: ${mat.fileSize}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download'),
                        onPressed: () {
                          AppModals.showSuccessDialog(context: context, title: 'Download Simulated', message: 'File downloaded successfully.');
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 13. Schedule ---
  Widget _buildScheduleTab(List<ScheduleModel> schedules) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Class Schedule & Timetable', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final s = schedules[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primary, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Section: ${s.section} • Room: ${s.room}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('${s.dayOfWeek} • ${s.startTime} - ${s.endTime}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 14. Notifications ---
  Widget _buildNotificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notifications & Alerts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: MockDatabase.instance.notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final n = MockDatabase.instance.notifications[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: AppColors.warning, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(n.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 15. Profile ---
  Widget _buildProfileTab() {
    final t = MockDatabase.instance.currentUser!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Teacher Educator Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(leading: const Icon(Icons.person), title: const Text('Full Name'), subtitle: Text(t.fullName)),
            const Divider(),
            ListTile(leading: const Icon(Icons.email), title: const Text('Institutional Email'), subtitle: Text(t.email)),
            const Divider(),
            ListTile(leading: const Icon(Icons.science), title: const Text('Department'), subtitle: Text(t.departmentOrSection ?? 'Mathematics')),
          ],
        ),
      ),
    );
  }
}
