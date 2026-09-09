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
    final activities = MockDatabase.instance.activities;
    final quizzes = MockDatabase.instance.quizzesAndExams;
    final notifications = MockDatabase.instance.notifications;
    final student = MockDatabase.instance.currentUser ?? MockDatabase.instance.users.firstWhere((u) => u.role == UserRole.student);

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
        title: const Text('ClassRealm Student Portal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      drawer: _buildStudentDrawer(context),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Activities'),
          BottomNavigationBarItem(icon: Icon(Icons.quiz_outlined), activeIcon: Icon(Icons.quiz), label: 'Quiz/Exam'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildStudentDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(backgroundColor: Colors.white, radius: 28, child: Icon(Icons.school, size: 32, color: AppColors.primary)),
                SizedBox(height: 10),
                Text('Juan Dela Cruz', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('STEM 11-A • ID: 2024-SHS-0101', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Attendance Records'),
            onTap: () {
              Navigator.pop(context);
              AppModals.showSuccessDialog(context: context, title: 'Attendance Logs', message: 'You have 100% attendance rate for this quarter (Present on all school days).');
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Class Schedule'),
            onTap: () {
              Navigator.pop(context);
              AppModals.showSuccessDialog(context: context, title: 'Class Schedule', message: 'General Mathematics: Mon/Wed 07:30 AM (Room 304).');
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Learning Materials'),
            onTap: () {
              Navigator.pop(context);
              AppModals.showSuccessDialog(context: context, title: 'Learning Materials', message: 'You have access to 3 downloadable PDF modules.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.grade_outlined),
            title: const Text('Published Grades'),
            onTap: () {
              Navigator.pop(context);
              AppModals.showSuccessDialog(context: context, title: 'Published Grades', message: 'Current Quarter Grade: 92.5 (A) - Excellent performance.');
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

  Widget _buildHomeTab(List<ActivityModel> activities, List<QuizOrExamModel> quizzes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome to ClassRealm', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      SizedBox(height: 4),
                      Text('Juan Dela Cruz', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Grade 11 - STEM 11-A', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.verified, color: AppColors.success, size: 36),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Pending Activities & Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...activities.map((act) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(act.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(act.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Max Score: ${act.maxScore}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        AppPrimaryButton(
                          label: 'Submit Work',
                          height: 36,
                          width: 110,
                          onPressed: () {
                            MockDatabase.instance.submitActivity(act.id, 'usr_student_1', 'Juan Dela Cruz', 'Juan_Worksheet.pdf');
                            AppModals.showSuccessDialog(context: context, title: 'Activity Submitted', message: 'Your file has been saved locally and synchronized successfully.');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab(List<ActivityModel> activities) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final act = activities[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(act.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(act.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              AppPrimaryButton(
                label: 'Upload & Submit Document (.docx / .pdf)',
                height: 40,
                onPressed: () {
                  MockDatabase.instance.submitActivity(act.id, 'usr_student_1', 'Juan Dela Cruz', 'Juan_Solution.pdf');
                  AppModals.showSuccessDialog(context: context, title: 'Submission Successful', message: 'File uploaded and status updated to Submitted.');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuizExamTab(List<QuizOrExamModel> quizzes) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: quizzes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final q = quizzes[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(q.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  StatusBadge(text: q.isExam ? 'EXAM' : 'QUIZ', backgroundColor: AppColors.infoLight, textColor: AppColors.info),
                ],
              ),
              const SizedBox(height: 4),
              Text(q.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              AppPrimaryButton(
                label: 'Start ${q.isExam ? "Examination" : "Quiz"} (Offline Safe)',
                height: 40,
                onPressed: () {
                  AppModals.showSuccessDialog(context: context, title: 'Assessment Started', message: 'Answers will be saved locally in real time even if offline.');
                },
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

  Widget _buildProfileTab(UserModel student) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircleAvatar(radius: 40, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 48, color: Colors.white)),
          const SizedBox(height: 16),
          Text(student.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(student.email, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ListTile(leading: const Icon(Icons.badge), title: const Text('Student ID'), subtitle: Text(student.studentId ?? '2024-SHS-0101')),
          ListTile(leading: const Icon(Icons.class_), title: const Text('Section'), subtitle: Text(student.departmentOrSection ?? 'STEM 11-A')),
        ],
      ),
    );
  }
}
