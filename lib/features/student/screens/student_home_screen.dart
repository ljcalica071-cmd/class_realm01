import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../models/academic_models.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/sync_status_badge.dart';
import '../../../widgets/common/app_buttons.dart';
import 'student_assessment_screen.dart';
import 'student_requirements_screen.dart';
import 'student_attendance_screen.dart';
import 'student_schedule_screen.dart';
import 'student_learning_materials_screen.dart';
import 'student_grades_screen.dart';
import 'student_settings_screen.dart';
import '../widgets/student_activity_card.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final activities = MockDatabase.instance.activitiesOnly;
    final quizzes = MockDatabase.instance.quizzesAndExams
        .where((q) => q.id != 'WW3' && q.title != 'Functions Quiz')
        .toList();
    final notifications = MockDatabase.instance.notifications;
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );

    final List<Widget> pages = [
      _buildHomeTab(activities, quizzes),
      _buildActivitiesTab(activities),
      _buildQuizExamTab(quizzes),
      _buildNotificationsTab(notifications),
      _buildProfileTab(student),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'ClassRealm',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: const [
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SyncStatusBadge(),
            ),
          ),
        ],
      ),
      drawer: _buildStudentDrawer(context, student),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
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
    );
  }

  Widget _buildStudentDrawer(BuildContext context, UserModel student) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 28,
                  child: Image.asset(
                    'lib/school_logo.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  student.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${student.departmentOrSection ?? 'Section A'} • LRN: ${student.lrn ?? student.studentId ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Attendance Records'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentAttendanceScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('My Schedule'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentScheduleScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Learning Materials'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentLearningMaterialsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in_outlined),
            title: const Text('Performance Task'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StudentRequirementsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.grade_outlined),
            title: const Text('My Grades'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentGradesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentSettingsScreen()),
              );
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

  Widget _buildHomeTab(
    List<ActivityModel> activities,
    List<QuizOrExamModel> quizzes,
  ) {
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome to ClassRealm',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Grade ${student.gradeLevel ?? '11'} - ${student.departmentOrSection ?? 'Section A'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified, color: AppColors.success, size: 36),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pending Written Works',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...activities.map(
            (act) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StudentActivityCard(
                activity: act,
                student: student,
                onSubmitted: () => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab(List<ActivityModel> activities) {
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        return StudentActivityCard(
          activity: activities[i],
          student: student,
          onSubmitted: () => setState(() {}),
        );
      },
    );
  }

  Widget _buildQuizExamTab(List<QuizOrExamModel> quizzes) {
    final student =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (u) => u.role == UserRole.student,
        );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: quizzes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final q = quizzes[i];
        final result = MockDatabase.instance.resultFor(q.id, student.id);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    q.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                q.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              if (result == null)
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: 'Start ${q.isExam ? "Examination" : "Quiz"}',
                    height: 44,
                    onPressed: () async {
                      await StudentAssessmentScreen.start(context, q);
                      setState(() {});
                    },
                  ),
                )
              else if (!result.isReleased)
                const StatusBadge(
                  text: 'Submitted — awaiting release',
                  backgroundColor: AppColors.warningLight,
                  textColor: AppColors.warning,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: ${result.scoreEarned.toInt()} / ${result.totalPoints.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    AppSecondaryButton(
                      label: 'View Result',
                      height: 36,
                      width: 120,
                      onPressed: () {
                        StudentAssessmentScreen.start(context, q);
                      },
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () {
              if (n.type == 'activity') {
                setState(() => _currentIndex = 1);
              } else if (n.type == 'attendance') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentAttendanceScreen(),
                  ),
                );
              } else if (n.type == 'grade') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentGradesScreen()),
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      n.type == 'attendance'
                          ? Icons.fact_check_outlined
                          : n.type == 'grade'
                          ? Icons.grade_outlined
                          : Icons.assignment_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.message,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(UserModel student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            student.fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(student.email, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text('LRN'),
            subtitle: Text(student.lrn ?? student.studentId ?? 'N/A'),
          ),
          ListTile(
            leading: const Icon(Icons.class_),
            title: const Text('Section'),
            subtitle: Text(student.departmentOrSection ?? 'Section A'),
          ),
        ],
      ),
    );
  }
}
