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
import '../widgets/add_student_dialog.dart';
import '../widgets/edit_student_dialog.dart';
import 'create_assessment_flow.dart';
import 'edit_assessment_flow.dart';
import 'activity_submissions_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedIndex = 17;
  bool _isSidebarExpanded = true;
  bool _showArchivedStudents = false;
  bool _showNewSchoolYearForm = false;
  bool _showAddClassForm = false;
  final List<String> _classroomSections = [];
  String _selectedSchoolYear = '2026-2027';
  String _newSchoolYearStructure = 'Quarterly (4 quarters)';
  String _newClassSchoolYear = 'SY 2026-2027';
  String _newClassGradeLevel = 'Grade 11';
  String _studentSearchQuery = '';

  // Controllers for CRUD forms
  final _studentNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _studentSectionCtrl = TextEditingController();
  final _actTitleCtrl = TextEditingController();
  final _actDescCtrl = TextEditingController();
  final _quizTitleCtrl = TextEditingController();
  final _quizDescCtrl = TextEditingController();
  final _schoolYearCtrl = TextEditingController();
  final _schoolYearStartCtrl = TextEditingController(text: '01/06/2026');
  final _schoolYearEndCtrl = TextEditingController(text: '30/04/2027');
  final _classSectionCtrl = TextEditingController();

  @override
  void dispose() {
    _studentNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _studentSectionCtrl.dispose();
    _actTitleCtrl.dispose();
    _actDescCtrl.dispose();
    _quizTitleCtrl.dispose();
    _quizDescCtrl.dispose();
    _schoolYearCtrl.dispose();
    _schoolYearStartCtrl.dispose();
    _schoolYearEndCtrl.dispose();
    _classSectionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allStudents = MockDatabase.instance.users
        .where((u) => u.role == UserRole.student)
        .toList();
    final activeStudents = allStudents.where((u) => !u.isArchived).toList();
    final archivedStudents = allStudents.where((u) => u.isArchived).toList();

    final activities = MockDatabase.instance.activities;
    final quizzesAndExams = MockDatabase.instance.quizzesAndExams;
    final attendance = MockDatabase.instance.attendanceRecords;
    final lessonPlans = MockDatabase.instance.lessonPlans;
    final materials = MockDatabase.instance.materials;
    final schedules = MockDatabase.instance.schedules;
    final criteria = MockDatabase.instance.gradingCriteria;
    final examReviews = MockDatabase.instance.examReviews;

    return Scaffold(
      body: Row(
        children: [
          // Collapsible Categorized Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarExpanded ? 260 : 80,
            color: AppColors.sidebarBg,
            child: Column(
              children: [
                // Brand Header
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CLASSREALM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'TEACHER PORTAL',
                                style: TextStyle(
                                  color: AppColors.accentLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),

                // Grouped Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined),
                      const SizedBox(height: 8),
                      _buildSectionHeader('TEACHING'),
                      _buildNavItem(
                        1,
                        'Activities & Requirements',
                        Icons.assignment_outlined,
                      ),
                      _buildNavItem(2, 'Quizzes & Exams', Icons.quiz_outlined),
                      _buildNavItem(
                        3,
                        'Lesson Planning',
                        Icons.psychology_outlined,
                      ),
                      _buildNavItem(
                        4,
                        'Learning Materials',
                        Icons.menu_book_outlined,
                      ),
                      const SizedBox(height: 8),
                      _buildSectionHeader('MONITORING & EVALUATION'),
                      _buildNavItem(5, 'Attendance', Icons.fact_check_outlined),
                      _buildNavItem(6, 'Exam Checker', Icons.checklist_rtl),
                      _buildNavItem(7, 'Item Analysis', Icons.insights),
                      _buildNavItem(
                        8,
                        'Grading System',
                        Icons.pie_chart_outline,
                      ),
                      _buildNavItem(9, 'Grades', Icons.grade_outlined),
                      _buildNavItem(
                        10,
                        'Academic Reports',
                        Icons.assessment_outlined,
                      ),
                      const SizedBox(height: 8),
                      _buildSectionHeader('INSIGHTS & MANAGEMENT'),
                      _buildNavItem(11, 'Academic Setup', Icons.tune_outlined),
                      _buildNavItem(
                        12,
                        'Manage Students',
                        Icons.groups_outlined,
                      ),
                      _buildNavItem(
                        13,
                        'Performance Analytics',
                        Icons.trending_up,
                      ),
                      _buildNavItem(
                        14,
                        'Schedule',
                        Icons.calendar_today_outlined,
                      ),
                      _buildNavItem(
                        15,
                        'Notifications',
                        Icons.notifications_outlined,
                      ),
                      _buildNavItem(16, 'Profile', Icons.person_outline),
                      const SizedBox(height: 8),
                      _buildSectionHeader('MY CLASSROOM'),
                      _buildNavItem(
                        17,
                        'Classroom Setup',
                        Icons.apartment_outlined,
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: _isSidebarExpanded
                      ? const Text(
                          'Log Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  onTap: () {
                    MockDatabase.instance.logout();
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Header Navbar
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
                        icon: Icon(
                          _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                        ),
                        onPressed: () => setState(
                          () => _isSidebarExpanded = !_isSidebarExpanded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _getTeacherTitle(_selectedIndex),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const SyncStatusBadge(),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _selectedIndex = 15),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 18,
                        child: Text(
                          MockDatabase.instance.currentUser?.fullName.substring(
                                0,
                                1,
                              ) ??
                              'M',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            MockDatabase.instance.currentUser?.fullName ??
                                'Prof. Maria Santos',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'General Mathematics',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dynamic Body View
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: _buildTeacherBodyContent(
                      activeStudents,
                      archivedStudents,
                      activities,
                      quizzesAndExams,
                      attendance,
                      lessonPlans,
                      materials,
                      schedules,
                      criteria,
                      examReviews,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    if (!_isSidebarExpanded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(color: Colors.white12, height: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  String _getTeacherTitle(int index) {
    switch (index) {
      case 17:
        return 'Classroom Setup';
      case 0:
        return 'Teacher Dashboard Overview';
      case 1:
        return 'Activities & Requirements Management';
      case 2:
        return 'Quizzes & Periodical Examinations';
      case 3:
        return 'AI Lesson Planning Generator';
      case 4:
        return 'Learning Materials Repository';
      case 5:
        return 'Attendance Tracker & RFID Logs';
      case 6:
        return 'Exam Auto-Checker & Scoring';
      case 7:
        return 'Item Analysis Dashboard';
      case 8:
        return 'Teacher-Defined Grading Weights';
      case 9:
        return 'Student Grades & Component Breakdown';
      case 10:
        return 'Academic & DepEd Quarterly Reports';
      case 11:
        return 'Academic Setup & Configurations';
      case 12:
        return 'Student Management & Roster';
      case 13:
        return 'Performance Analytics';
      case 14:
        return 'Class Schedule & Timetable';
      case 15:
        return 'Notifications & Institutional Alerts';
      case 16:
        return 'Faculty Educator Profile';
      default:
        return 'Teacher Portal';
    }
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D9488).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.accentLight.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accentLight : AppColors.textMuted,
              size: 18,
            ),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
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
    List<UserModel> activeStudents,
    List<UserModel> archivedStudents,
    List<ActivityModel> activities,
    List<QuizOrExamModel> quizzesAndExams,
    List<AttendanceRecord> attendance,
    List<LessonPlanModel> lessonPlans,
    List<LearningMaterialModel> materials,
    List<ScheduleModel> schedules,
    List<GradingCriteria> criteria,
    List<ExamSubmissionReview> examReviews,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview(
          activeStudents,
          quizzesAndExams,
          schedules,
        );
      case 1:
        return _buildActivitiesTab(activities);
      case 2:
        return _buildQuizzesTab(quizzesAndExams);
      case 3:
        return _buildLessonPlanningTab(lessonPlans);
      case 4:
        return _buildLearningMaterialsTab(materials);
      case 5:
        return _buildAttendanceTab(attendance);
      case 6:
        return _buildExamCheckerTab(examReviews, quizzesAndExams);
      case 7:
        return _buildItemAnalysisTab(quizzesAndExams);
      case 8:
        return _buildGradingSystemTab(criteria);
      case 9:
        return _buildGradesTab(activeStudents);
      case 10:
        return _buildReportsTab(); // Reports Feature Tab
      case 11:
        return _buildAcademicSetupTab();
      case 17:
        return _buildClassroomSetupTab();
      case 12:
        return _buildStudentManagementTab(activeStudents, archivedStudents);
      case 13:
        return _buildPerformanceTab(activeStudents);
      case 14:
        return _buildScheduleTab(schedules);
      case 15:
        return _buildNotificationsTab();
      case 16:
        return _buildProfileTab();
      default:
        return const Center(child: Text('Feature coming up'));
    }
  }

  // ==========================================
  // --- 0. DASHBOARD OVERVIEW (3 BOXES ONLY) ---
  // ==========================================
  Widget _buildDashboardOverview(
    List<UserModel> activeStudents,
    List<QuizOrExamModel> quizzesAndExams,
    List<ScheduleModel> schedules,
  ) {
    final quizzesCount = quizzesAndExams.where((q) => !q.isExam).length;
    final examsCount = quizzesAndExams.where((q) => q.isExam).length;
    final totalAssessments = quizzesAndExams.length;
    final todaysClassesCount = schedules.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back, Prof. Santos!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Here's your academic summary for Eduardo Barretto Senior Integrated School today.",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // 3 TOP STAT CARDS
          Row(
            children: [
              Expanded(
                child: _buildTopSummaryCard(
                  title: "Today's Classes",
                  mainValue: '$todaysClassesCount',
                  subText: '↑ 2 completed, 2 remaining',
                  subColor: AppColors.success,
                  icon: Icons.menu_book_outlined,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor: const Color(0xFFCCFBF1),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildTopSummaryCard(
                  title: 'Students',
                  mainValue: '${activeStudents.length * 27}',
                  subText: '↑ Across 5 sections (Grade 11)',
                  subColor: AppColors.primary,
                  icon: Icons.school_outlined,
                  iconColor: AppColors.primary,
                  iconBgColor: const Color(0xFFDBEAFE),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildTopSummaryCard(
                  title: 'Upcoming Assessments',
                  mainValue: '$totalAssessments',
                  subText:
                      '$quizzesCount Quizzes • $examsCount Periodical Exams',
                  subColor: AppColors.accent,
                  icon: Icons.quiz_outlined,
                  iconColor: Colors.amber.shade800,
                  iconBgColor: Colors.amber.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // LOWER SECTION: Today's Classes & Quick Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Classes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedIndex = 14),
                            child: const Text(
                              'View All Schedule',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildClassItem(
                        subject: 'Mathematics 11 (General Math)',
                        sectionAndRoom:
                            'Grade 11 - STEM 11-A • Room 304 - Science Wing',
                        time: '07:30 AM - 09:00 AM',
                        isDone: true,
                        attendanceStats: 'Attendance: 34 / 35 present',
                      ),
                      const SizedBox(height: 12),
                      _buildClassItem(
                        subject: 'Mathematics 11 (General Math)',
                        sectionAndRoom:
                            'Grade 11 - STEM 11-B • Room 305 - Science Wing',
                        time: '09:15 AM - 10:45 AM',
                        isDone: true,
                        attendanceStats: 'Attendance: 35 / 35 present',
                      ),
                      const SizedBox(height: 12),
                      _buildClassItem(
                        subject: 'Business Mathematics',
                        sectionAndRoom:
                            'Grade 11 - ABM 11-A • Room 201 - Business Wing',
                        time: '01:00 PM - 02:30 PM',
                        isDone: false,
                        attendanceStats: 'Scheduled (Not yet started)',
                      ),
                      const SizedBox(height: 12),
                      _buildClassItem(
                        subject: 'Basic Calculus & Statistics',
                        sectionAndRoom: 'Grade 11 - HUMSS 11-A • Room 102 - Humanities Wing',
                        time: '02:45 PM - 04:15 PM',
                        isDone: false,
                        attendanceStats: 'Scheduled (Not yet started)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right: Quick Actions Menu
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildQuickActionTile(
                        title: 'Mark Attendance',
                        icon: Icons.checklist_rtl_outlined,
                        onTap: () => setState(() => _selectedIndex = 5),
                      ),
                      const Divider(height: 1),
                      _buildQuickActionTile(
                        title: 'Create Activity / Task',
                        icon: Icons.add_circle_outline,
                        onTap: () {
                          setState(() => _selectedIndex = 1);
                          _showCreateActivityModal(context);
                        },
                      ),
                      const Divider(height: 1),
                      _buildQuickActionTile(
                        title: 'Check Submissions & Auto-Score',
                        icon: Icons.task_alt_outlined,
                        onTap: () => setState(() => _selectedIndex = 6),
                      ),
                      const Divider(height: 1),
                      _buildQuickActionTile(
                        title: 'Create Quiz / Examination',
                        icon: Icons.description_outlined,
                        onTap: () {
                          setState(() => _selectedIndex = 2);
                          CreateAssessmentFlowDialog.show(
                            context,
                            onAssessmentCreated: () => setState(() {}),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildQuickActionTile(
                        title: 'Generate Lesson Plan with AI',
                        icon: Icons.auto_awesome_outlined,
                        onTap: () => setState(() => _selectedIndex = 3),
                      ),
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

  Widget _buildTopSummaryCard({
    required String title,
    required String mainValue,
    required String subText,
    required Color subColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mainValue,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassItem({
    required String subject,
    required String sectionAndRoom,
    required String time,
    required bool isDone,
    required String attendanceStats,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: isDone ? AppColors.success : AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sectionAndRoom,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.successLight
                      : const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.schedule,
                      size: 12,
                      color: isDone ? AppColors.success : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDone ? 'Done' : 'Upcoming',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDone ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                attendanceStats,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  // ==========================================
  // --- 10. ACADEMIC & DEPED REPORTS TAB ---
  // ==========================================
  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic & DepEd Reports Generator',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Generate, view, and export official attendance summaries and quarterly grading sheets.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              AppPrimaryButton(
                label: 'Export All DepEd Forms',
                icon: Icons.download_outlined,
                onPressed: () {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Reports Export Simulated',
                    message: 'Official SF2 (Attendance) and SF9 (Progress Report) generated successfully in PDF/Excel format.',
                  );
                },
                height: 40,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Report Options Cards
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.5,
            children: [
              _buildReportCard(
                title: 'School Form 2 (SF2)',
                subtitle: 'Daily Attendance Report of Learners',
                icon: Icons.fact_check_outlined,
                color: AppColors.primary,
                onDownload: () => _showExportConfirm('School Form 2 (SF2)'),
              ),
              _buildReportCard(
                title: 'Quarterly Grading Sheet',
                subtitle: 'Grade 11 Mathematics Component Summaries',
                icon: Icons.grade_outlined,
                color: AppColors.success,
                onDownload: () => _showExportConfirm('Quarterly Grading Sheet'),
              ),
              _buildReportCard(
                title: 'Item Analysis Summary',
                subtitle: 'Periodical Examination Statistical Report',
                icon: Icons.insights_outlined,
                color: AppColors.accent,
                onDownload: () => _showExportConfirm('Item Analysis Summary'),
              ),
              _buildReportCard(
                title: 'School Form 9 (SF9)',
                subtitle: 'Learner Progress Report Card',
                icon: Icons.badge_outlined,
                color: Colors.indigo,
                onDownload: () => _showExportConfirm('School Form 9 (SF9)'),
              ),
              _buildReportCard(
                title: 'At-Risk Remediation Log',
                subtitle: 'Early warning list of students below 75%',
                icon: Icons.warning_amber_outlined,
                color: AppColors.error,
                onDownload: () => _showExportConfirm('At-Risk Remediation Log'),
              ),
              _buildReportCard(
                title: 'Activity Completion Masterlist',
                subtitle: 'Overall task submissions across 5 sections',
                icon: Icons.assignment_turned_in_outlined,
                color: Colors.purple,
                onDownload: () =>
                    _showExportConfirm('Activity Completion Masterlist'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onDownload,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              minimumSize: const Size(double.infinity, 36),
            ),
            icon: const Icon(Icons.download, size: 16),
            label: const Text(
              'Generate / Download',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }

  void _showExportConfirm(String reportName) {
    AppModals.showSuccessDialog(
      context: context,
      title: 'Report Generated',
      message:
          '$reportName has been compiled and saved locally. Ready for printing or official school archiving.',
    );
  }

  // ===================================================================
  // --- 12. STUDENT MANAGEMENT WITH COMPLETE CRUD & ARCHIVE RECOVERY ---
  // ===================================================================
  final Set<String> _selectedStudentIds = {};
  String _selectedClassFilter = '— Select a class —';
  String _sortColumn = 'lastName';
  bool _sortAscending = true;

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _showTransferSectionDialog(BuildContext context, UserModel student) {
    String selectedTargetSection = MockDatabase.instance.sections.firstWhere(
      (sec) => sec != student.departmentOrSection,
      orElse: () => MockDatabase.instance.sections.first,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.swap_horiz,
                  color: Color(0xFF1A56DB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Transfer to Another Section',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer student ${student.fullName} from ${student.departmentOrSection ?? "current section"} to a new section.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Destination Section:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedTargetSection,
                      items: MockDatabase.instance.sections
                          .map(
                            (sec) => DropdownMenuItem(
                              value: sec,
                              child: Text(
                                sec,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setModalState(() => selectedTargetSection = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  MockDatabase.instance.updateStudent(
                    student.id,
                    student.fullName,
                    student.studentId ?? '',
                    selectedTargetSection,
                  );
                });
                Navigator.pop(ctx);
                AppModals.showSuccessDialog(
                  context: context,
                  title: 'Section Transferred',
                  message:
                      '${student.fullName} has been transferred to $selectedTargetSection successfully.',
                );
              },
              child: const Text(
                'Confirm Transfer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentManagementTab(
    List<UserModel> activeStudents,
    List<UserModel> archivedStudents,
  ) {
    var displayList =
        (_showArchivedStudents ? archivedStudents : activeStudents).where((s) {
          final matchesSearch =
              s.fullName.toLowerCase().contains(
                _studentSearchQuery.toLowerCase(),
              ) ||
              (s.studentId?.toLowerCase().contains(
                    _studentSearchQuery.toLowerCase(),
                  ) ??
                  false) ||
              (s.email.toLowerCase().contains(
                _studentSearchQuery.toLowerCase(),
              ));
          final matchesClass =
              _selectedClassFilter == '— Select a class —' ||
              (s.departmentOrSection == _selectedClassFilter);
          return matchesSearch && matchesClass;
        }).toList();

    // Sort logic
    displayList.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'lastName':
          final aLast =
              a.lastName ??
              (a.fullName.contains(' ')
                  ? a.fullName.split(' ').last
                  : a.fullName);
          final bLast =
              b.lastName ??
              (b.fullName.contains(' ')
                  ? b.fullName.split(' ').last
                  : b.fullName);
          cmp = aLast.compareTo(bLast);
          break;
        case 'firstName':
          final aFirst =
              a.firstName ??
              (a.fullName.contains(' ') ? a.fullName.split(' ').first : '');
          final bFirst =
              b.firstName ??
              (b.fullName.contains(' ') ? b.fullName.split(' ').first : '');
          cmp = aFirst.compareTo(bFirst);
          break;
        case 'lrn':
          cmp = (a.studentId ?? '').compareTo(b.studentId ?? '');
          break;
        case 'gender':
          cmp = (a.id.hashCode % 2).compareTo(b.id.hashCode % 2);
          break;
        case 'birthdate':
          final aDate = a.birthday ?? DateTime(2006);
          final bDate = b.birthday ?? DateTime(2006);
          cmp = aDate.compareTo(bDate);
          break;
        case 'email':
          cmp = a.email.compareTo(b.email);
          break;
        case 'contact':
          cmp = (a.contactNumber ?? '').compareTo(b.contactNumber ?? '');
          break;
        case 'status':
          cmp = a.status.name.compareTo(b.status.name);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });

    bool allSelected =
        displayList.isNotEmpty &&
        displayList.every((s) => _selectedStudentIds.contains(s.id));

    // Column widths definition for horizontal scroll
    const colCheckWidth = 48.0;
    const colNumWidth = 56.0;
    const colLastNameWidth = 150.0;
    const colFirstNameWidth = 140.0;
    const colLrnWidth = 150.0;
    const colGenderWidth = 110.0;
    const colBirthdateWidth = 160.0;
    const colEmailWidth = 240.0;
    const colContactWidth = 160.0;
    const colStatusWidth = 120.0;
    const colActionsWidth = 170.0;

    const totalTableWidth =
        colCheckWidth +
        colNumWidth +
        colLastNameWidth +
        colFirstNameWidth +
        colLrnWidth +
        colGenderWidth +
        colBirthdateWidth +
        colEmailWidth +
        colContactWidth +
        colStatusWidth +
        colActionsWidth;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & Export / Add buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage Students',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C41),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text(
                      'Export Excel',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      AppModals.showSuccessDialog(
                        context: context,
                        title: 'Exported to Excel',
                        message: 'Student roster has been successfully exported to Excel (.xlsx).',
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A56DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text(
                      'Add Students',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => AddStudentDialog.show(
                      context,
                      onStudentCreated: () => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter & Search bar row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClassFilter,
                    items:
                        [
                              '— Select a class —',
                              ...MockDatabase.instance.sections,
                            ]
                            .map(
                              (sec) => DropdownMenuItem(
                                value: sec,
                                child: Text(
                                  sec,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _selectedClassFilter = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _studentSearchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or LRN (12 digits)...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _showArchivedStudents
                      ? const Color(0xFF1A56DB)
                      : AppColors.textSecondary,
                  side: BorderSide(
                    color: _showArchivedStudents
                        ? const Color(0xFF1A56DB)
                        : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                icon: Icon(
                  _showArchivedStudents
                      ? Icons.people_outline
                      : Icons.archive_outlined,
                  size: 18,
                ),
                label: Text(
                  _showArchivedStudents
                      ? 'View Active'
                      : 'View Archive (${archivedStudents.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => setState(
                  () => _showArchivedStudents = !_showArchivedStudents,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Table Container with dual-axis scroll (horizontal & vertical)
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: totalTableWidth,
                        child: Column(
                          children: [
                            // Table Header Row
                            Container(
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A56DB),
                              ),
                              child: Row(
                                children: [
                                  // Checkbox column
                                  _buildHeaderCell(
                                    width: colCheckWidth,
                                    child: Center(
                                      child: Checkbox(
                                        value: allSelected,
                                        activeColor: Colors.white,
                                        checkColor: const Color(0xFF1A56DB),
                                        side: const BorderSide(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              for (var s in displayList) {
                                                _selectedStudentIds.add(s.id);
                                              }
                                            } else {
                                              for (var s in displayList) {
                                                _selectedStudentIds.remove(
                                                  s.id,
                                                );
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  // # column
                                  _buildHeaderCell(
                                    width: colNumWidth,
                                    child: const Center(
                                      child: Text(
                                        '#',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // LAST NAME
                                  _buildHeaderCell(
                                    width: colLastNameWidth,
                                    child: _buildClickableHeaderTitle(
                                      'LAST NAME',
                                      'lastName',
                                    ),
                                  ),
                                  // FIRST NAME
                                  _buildHeaderCell(
                                    width: colFirstNameWidth,
                                    child: _buildClickableHeaderTitle(
                                      'FIRST NAME',
                                      'firstName',
                                    ),
                                  ),
                                  // LRN
                                  _buildHeaderCell(
                                    width: colLrnWidth,
                                    child: _buildClickableHeaderTitle(
                                      'LRN',
                                      'lrn',
                                    ),
                                  ),
                                  // GENDER
                                  _buildHeaderCell(
                                    width: colGenderWidth,
                                    child: _buildClickableHeaderTitle(
                                      'GENDER',
                                      'gender',
                                    ),
                                  ),
                                  // BIRTHDATE
                                  _buildHeaderCell(
                                    width: colBirthdateWidth,
                                    child: _buildClickableHeaderTitle(
                                      'BIRTHDATE',
                                      'birthdate',
                                    ),
                                  ),
                                  // EMAIL
                                  _buildHeaderCell(
                                    width: colEmailWidth,
                                    child: _buildClickableHeaderTitle(
                                      'EMAIL',
                                      'email',
                                    ),
                                  ),
                                  // CONTACT NO.
                                  _buildHeaderCell(
                                    width: colContactWidth,
                                    child: _buildClickableHeaderTitle(
                                      'CONTACT NO.',
                                      'contact',
                                    ),
                                  ),
                                  // STATUS
                                  _buildHeaderCell(
                                    width: colStatusWidth,
                                    child: _buildClickableHeaderTitle(
                                      'STATUS',
                                      'status',
                                    ),
                                  ),
                                  // ACTIONS
                                  _buildHeaderCell(
                                    width: colActionsWidth,
                                    hasRightBorder: false,
                                    child: const Center(
                                      child: Text(
                                        'ACTIONS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table Data List (Vertical scroll)
                            Expanded(
                              child: displayList.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _showArchivedStudents
                                                ? Icons.archive_outlined
                                                : Icons.school_outlined,
                                            size: 48,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _showArchivedStudents
                                                ? 'No archived students found.'
                                                : 'No students found matching filters.',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: displayList.length,
                                      itemBuilder: (ctx, i) {
                                        final s = displayList[i];
                                        final isSelected = _selectedStudentIds
                                            .contains(s.id);
                                        final lastName =
                                            s.lastName ??
                                            (s.fullName.contains(' ')
                                                ? s.fullName.split(' ').last
                                                : s.fullName);
                                        final firstName =
                                            s.firstName ??
                                            (s.fullName.contains(' ')
                                                ? s.fullName.split(' ').first
                                                : '');
                                        final lrn =
                                            s.studentId ?? '123456789112';
                                        final gender = (s.id.hashCode % 2 == 0)
                                            ? 'Male'
                                            : 'Female';
                                        final bday = s.birthday != null
                                            ? '${s.birthday!.year}-${s.birthday!.month.toString().padLeft(2, '0')}-${s.birthday!.day.toString().padLeft(2, '0')}'
                                            : '2006-05-12';
                                        final age = s.birthday != null
                                            ? (DateTime.now().year -
                                                  s.birthday!.year)
                                            : 18;
                                        final contact =
                                            s.parentGuardianContact ??
                                            s.contactNumber ??
                                            '09123456663';

                                        return Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFEFF6FF)
                                                : (i % 2 == 1
                                                      ? const Color(0xFFFBFDFF)
                                                      : Colors.white),
                                            border: const Border(
                                              bottom: BorderSide(
                                                color: Color(0xFFE2E8F0),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Checkbox cell
                                              _buildDataCell(
                                                width: colCheckWidth,
                                                child: Center(
                                                  child: Checkbox(
                                                    value: isSelected,
                                                    activeColor: const Color(
                                                      0xFF1A56DB,
                                                    ),
                                                    onChanged: (val) {
                                                      setState(() {
                                                        if (val == true) {
                                                          _selectedStudentIds
                                                              .add(s.id);
                                                        } else {
                                                          _selectedStudentIds
                                                              .remove(s.id);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                              // # cell
                                              _buildDataCell(
                                                width: colNumWidth,
                                                child: Center(
                                                  child: Text(
                                                    '${i + 1}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // LAST NAME
                                              _buildDataCell(
                                                width: colLastNameWidth,
                                                child: Text(
                                                  lastName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // FIRST NAME
                                              _buildDataCell(
                                                width: colFirstNameWidth,
                                                child: Text(
                                                  firstName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // LRN
                                              _buildDataCell(
                                                width: colLrnWidth,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF1F5F9,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    lrn,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: 'monospace',
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // GENDER
                                              _buildDataCell(
                                                width: colGenderWidth,
                                                child: Text(
                                                  gender,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                              // BIRTHDATE (Age)
                                              _buildDataCell(
                                                width: colBirthdateWidth,
                                                child: Text(
                                                  '$bday ($age)',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                              // EMAIL
                                              _buildDataCell(
                                                width: colEmailWidth,
                                                child: Text(
                                                  s.email,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // CONTACT NO.
                                              _buildDataCell(
                                                width: colContactWidth,
                                                child: Text(
                                                  contact,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // STATUS
                                              _buildDataCell(
                                                width: colStatusWidth,
                                                child:
                                                    StatusBadge.fromAccountStatus(
                                                      s.status,
                                                    ),
                                              ),
                                              // ACTIONS (Edit, Transfer, Archive)
                                              _buildDataCell(
                                                width: colActionsWidth,
                                                hasRightBorder: false,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Edit icon button
                                                    IconButton(
                                                      tooltip: 'Edit Student Details',
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                        size: 18,
                                                      ),
                                                      splashRadius: 18,
                                                      onPressed: () =>
                                                          EditStudentDialog.show(
                                                            context,
                                                            student: s,
                                                            onStudentUpdated:
                                                                () => setState(
                                                                  () {},
                                                                ),
                                                          ),
                                                    ),
                                                    // Transfer to another section icon button
                                                    IconButton(
                                                      tooltip: 'Transfer to another section',
                                                      icon: const Icon(
                                                        Icons.swap_horiz,
                                                        color: Color(
                                                          0xFF1A56DB,
                                                        ),
                                                        size: 18,
                                                      ),
                                                      splashRadius: 18,
                                                      onPressed: () =>
                                                          _showTransferSectionDialog(
                                                            context,
                                                            s,
                                                          ),
                                                    ),
                                                    // Archive / Delete or Restore button
                                                    if (!_showArchivedStudents)
                                                      IconButton(
                                                        tooltip:
                                                            'Archive Student',
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          color: Color(
                                                            0xFF94A3B8,
                                                          ),
                                                          size: 18,
                                                        ),
                                                        splashRadius: 18,
                                                        onPressed: () async {
                                                          final messenger =
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              );
                                                          final confirm =
                                                              await AppModals.showConfirmDialog(
                                                                context:
                                                                    context,
                                                                title: 'Archive Student',
                                                                message:
                                                                    'Are you sure you want to move ${s.fullName} to the archive?',
                                                                confirmLabel:
                                                                    'Archive',
                                                                confirmColor:
                                                                    AppColors
                                                                        .warning,
                                                              );
                                                          if (confirm == true) {
                                                            setState(
                                                              () => MockDatabase
                                                                  .instance
                                                                  .archiveStudent(
                                                                    s.id,
                                                                  ),
                                                            );
                                                            messenger.showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  '${s.fullName} moved to archive.',
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                      )
                                                    else
                                                      IconButton(
                                                        tooltip: 'Restore',
                                                        icon: const Icon(
                                                          Icons.restore,
                                                          color:
                                                              AppColors.success,
                                                          size: 18,
                                                        ),
                                                        splashRadius: 18,
                                                        onPressed: () {
                                                          setState(
                                                            () => MockDatabase
                                                                .instance
                                                                .restoreStudent(
                                                                  s.id,
                                                                ),
                                                          );
                                                          AppModals.showSuccessDialog(
                                                            context: context,
                                                            title: 'Restored',
                                                            message:
                                                                '${s.fullName} restored.',
                                                          );
                                                        },
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            // Footer status bar inside the table width
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              alignment: Alignment.centerRight,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Text(
                                '${displayList.length} students enrolled',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Floating Action Bar for Selected Items
                if (_selectedStudentIds.isNotEmpty)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_selectedStudentIds.length} selected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 16),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                              onPressed: () =>
                                  setState(() => _selectedStudentIds.clear()),
                              child: const Text(
                                'Clear',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text(
                                'Remove Selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final selectedCount =
                                    _selectedStudentIds.length;
                                final confirm = await AppModals.showConfirmDialog(
                                  context: context,
                                  title: 'Remove Selected Students',
                                  message:
                                      'Are you sure you want to archive $selectedCount selected student(s)?',
                                  confirmLabel: 'Remove Selected',
                                  confirmColor: AppColors.error,
                                );
                                if (confirm == true) {
                                  setState(() {
                                    for (var id in _selectedStudentIds) {
                                      MockDatabase.instance.archiveStudent(id);
                                    }
                                    _selectedStudentIds.clear();
                                  });
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$selectedCount student(s) moved to archive.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell({
    required double width,
    required Widget child,
    bool hasRightBorder = true,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? const Border(
                right: BorderSide(color: Color(0xFF2563EB), width: 1),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildClickableHeaderTitle(String title, String columnKey) {
    final isCurrent = _sortColumn == columnKey;
    final icon = !isCurrent ? ' ↕' : (_sortAscending ? ' ▴' : ' ▾');
    return InkWell(
      onTap: () => _onSort(columnKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$title$icon',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
                fontSize: 12.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell({
    required double width,
    required Widget child,
    bool hasRightBorder = true,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? const Border(
                right: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              )
            : null,
      ),
      child: child,
    );
  }

  void _showAddStudentModal(BuildContext context) {
    _studentNameCtrl.clear();
    _studentIdCtrl.clear();
    _studentSectionCtrl.text = 'STEM 11-A';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enroll New Senior High Student'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _studentNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name (Last Name, First Name)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _studentIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Student LRN (12-digit number)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _studentSectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assigned Section (e.g. STEM 11-A)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
                    email:
                        '${_studentNameCtrl.text.trim().toLowerCase().replaceAll(" ", ".")}@barretto-shs.edu.ph',
                    role: UserRole.student,
                    status: AccountStatus.active,
                    studentId: _studentIdCtrl.text.trim().isEmpty
                        ? '2024-SHS-0199'
                        : _studentIdCtrl.text.trim(),
                    departmentOrSection: _studentSectionCtrl.text.trim(),
                  ),
                );
              });
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(
                context: context,
                title: 'Student Enrolled',
                message:
                    'New student enrolled successfully in the active roster.',
              );
            },
            width: 130,
            height: 40,
          ),
        ],
      ),
    );
  }

  void _showEditStudentModal(BuildContext context, UserModel student) {
    _studentNameCtrl.text = student.fullName;
    _studentIdCtrl.text = student.studentId ?? '';
    _studentSectionCtrl.text = student.departmentOrSection ?? 'STEM 11-A';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Student Information'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _studentNameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _studentIdCtrl,
                decoration: const InputDecoration(labelText: 'Student ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _studentSectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assigned Section',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppPrimaryButton(
            label: 'Save Changes',
            onPressed: () {
              setState(() {
                MockDatabase.instance.updateStudent(
                  student.id,
                  _studentNameCtrl.text.trim(),
                  _studentIdCtrl.text.trim(),
                  _studentSectionCtrl.text.trim(),
                );
              });
              Navigator.pop(ctx);
              AppModals.showSuccessDialog(
                context: context,
                title: 'Student Updated',
                message: 'Student information updated successfully.',
              );
            },
            width: 130,
            height: 40,
          ),
        ],
      ),
    );
  }

  // --- 11. Academic Setup ---
  Widget _buildClassroomSetupTab() {
    final sections = _classroomSections;
    final teacherName =
        MockDatabase.instance.currentUser?.fullName ?? 'Lj Calica';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6F5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$teacherName's Classroom",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Solo Teacher — Self-managed',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text(
                    'New School Year',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _schoolYearCtrl.text = 'SY 2026-2027';
                    setState(
                      () => _showNewSchoolYearForm = !_showNewSchoolYearForm,
                    );
                  },
                ),
              ],
            ),
          ),
          if (_showNewSchoolYearForm) ...[
            const SizedBox(height: 12),
            _buildNewSchoolYearForm(),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6F5)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildSchoolYearSelector()),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Edit school year',
                  onPressed: () =>
                      setState(() => _showNewSchoolYearForm = true),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete school year',
                  onPressed: () {},
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textSecondary,
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    'Add Class${sections.isEmpty ? '' : ' (${sections.length}/10)'}',
                  ),
                  onPressed: () =>
                      setState(() => _showAddClassForm = !_showAddClassForm),
                ),
              ],
            ),
          ),
          if (_showAddClassForm) ...[
            const SizedBox(height: 12),
            _buildAddClassForm(),
          ],
          const SizedBox(height: 20),
          sections.isEmpty
              ? _buildEmptyClassroomState()
              : Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: sections.map(_buildClassroomCard).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildAcademicSetupTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Teacher Academic Setup',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Define your active academic year, grade level, sections, and subjects.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: TextEditingController(
                text: MockDatabase.instance.academicYear,
              ),
              decoration: const InputDecoration(labelText: 'Academic Year'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(
                text: MockDatabase.instance.gradeLevel,
              ),
              decoration: const InputDecoration(labelText: 'Grade Level'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(
                text: MockDatabase.instance.currentSubject,
              ),
              decoration: const InputDecoration(labelText: 'Primary Subject'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Managed Sections:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: MockDatabase.instance.sections
                  .map((sec) => Chip(label: Text(sec)))
                  .toList(),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Save Academic Configuration',
              onPressed: () {
                AppModals.showSuccessDialog(
                  context: context,
                  title: 'Configuration Saved',
                  message: 'Your academic setup has been updated successfully.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: const Color(0xFFC9D8F5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            'SY $_selectedSchoolYear (Current)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildNewSchoolYearForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New School Year',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _buildSetupField('YEAR NAME', _schoolYearCtrl)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newSchoolYearStructure,
                  decoration: const InputDecoration(
                    labelText: 'STRUCTURE',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Quarterly (4 quarters)',
                      child: Text('Quarterly (4 quarters)'),
                    ),
                    DropdownMenuItem(
                      value: 'Semester (2 semesters)',
                      child: Text('Semester (2 semesters)'),
                    ),
                    DropdownMenuItem(
                      value: 'Trimester (3 terms)',
                      child: Text('Trimester (3 terms)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _newSchoolYearStructure = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField('START DATE', _schoolYearStartCtrl),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildDateField('END DATE', _schoolYearEndCtrl)),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _showNewSchoolYearForm = false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedSchoolYear = _schoolYearCtrl.text
                          .trim()
                          .replaceFirst('SY ', '');
                      MockDatabase.instance.academicYear = _selectedSchoolYear;
                      _showNewSchoolYearForm = false;
                    });
                  },
                  child: const Text('Create School Year'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
          initialDate: DateTime.now(),
        );
        if (picked != null) {
          controller.text =
              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        }
      },
    );
  }

  Widget _buildAddClassForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Class',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newClassSchoolYear,
                  decoration: const InputDecoration(
                    labelText: 'SCHOOL YEAR',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SY 2026-2027',
                      child: Text('SY 2026-2027'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _newClassSchoolYear = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newClassGradeLevel,
                  decoration: const InputDecoration(
                    labelText: 'GRADE LEVEL',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Kinder', child: Text('Kinder')),
                    DropdownMenuItem(value: 'Grade 1', child: Text('Grade 1')),
                    DropdownMenuItem(value: 'Grade 2', child: Text('Grade 2')),
                    DropdownMenuItem(value: 'Grade 3', child: Text('Grade 3')),
                    DropdownMenuItem(value: 'Grade 4', child: Text('Grade 4')),
                    DropdownMenuItem(value: 'Grade 5', child: Text('Grade 5')),
                    DropdownMenuItem(value: 'Grade 6', child: Text('Grade 6')),
                    DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7')),
                    DropdownMenuItem(value: 'Grade 8', child: Text('Grade 8')),
                    DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
                    DropdownMenuItem(
                      value: 'Grade 10',
                      child: Text('Grade 10'),
                    ),
                    DropdownMenuItem(
                      value: 'Grade 11',
                      child: Text('Grade 11'),
                    ),
                    DropdownMenuItem(
                      value: 'Grade 12',
                      child: Text('Grade 12'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _newClassGradeLevel = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSetupField('SECTION NAME', _classSectionCtrl),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _showAddClassForm = false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final section = _classSectionCtrl.text.trim();
                    if (section.isEmpty ||
                        _classroomSections.contains(section) ||
                        _classroomSections.length >= 10) {
                      return;
                    }
                    setState(() {
                      _classroomSections.add(section);
                      _classSectionCtrl.clear();
                      _showAddClassForm = false;
                    });
                  },
                  child: const Text('Add Class'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyClassroomState() {
    return Container(
      height: 235,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBFD3F5),
          style: BorderStyle.solid,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 38, color: Color(0xFF94A8C4)),
          SizedBox(height: 16),
          Text(
            'No classes in this school year yet.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Click Add Class to create your first section.',
            style: TextStyle(fontSize: 14, color: Color(0xFF8DA4C8)),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomCard(String section) {
    final studentCount = MockDatabase.instance.users
        .where(
          (u) =>
              u.role == UserRole.student &&
              u.departmentOrSection == section &&
              !u.isArchived,
        )
        .length;
    return Container(
      width: 295,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          top: BorderSide(color: AppColors.primary, width: 3),
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
          left: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1E3A8A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  MockDatabase.instance.gradeLevel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section,
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$studentCount students',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.people_outline, size: 16),
            label: const Text('Get a class code'),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFFF4),
              border: Border.all(color: const Color(0xFFB6E8C9)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'General Mathematics',
              style: TextStyle(
                color: Color(0xFF167342),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 12),
                  icon: const Icon(Icons.people_outline, size: 16),
                  label: const Text('Add Students'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Dashboard'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddClassDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Class'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Section name',
            hintText: 'e.g. STEM 11-A',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final section = controller.text.trim();
              if (section.isEmpty ||
                  MockDatabase.instance.sections.contains(section))
                return;
              setState(() => _classroomSections.add(section));
              Navigator.pop(dialogContext);
            },
            child: const Text('Add Class'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  // --- 5. Attendance Tracker ---
  Widget _buildAttendanceTab(List<AttendanceRecord> attendance) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attendance & RFID Tap Log (ESP32 Simulation)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                icon: const Icon(Icons.nfc),
                label: const Text('Simulate RFID Tap'),
                onPressed: () {
                  setState(() {
                    MockDatabase.instance.toggleAttendance(
                      '123456789004',
                      AttendanceStatus.present,
                    );
                  });
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'RFID Tap Detected',
                    message: 'Student Carlos Yulo tapped RFID at Gate 1 (08:05 AM). Marked Present.',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                itemCount: attendance.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final att = attendance[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.infoLight,
                      child: Icon(Icons.badge, color: AppColors.info),
                    ),
                    title: Text(
                      att.studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'ID: ${att.studentId} • Section: ${att.section} • Time: ${att.timeIn} • Method: ${att.method}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge.fromAttendance(att.status),
                        const SizedBox(width: 12),
                        DropdownButton<AttendanceStatus>(
                          value: att.status,
                          items: AttendanceStatus.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (newStatus) {
                            if (newStatus != null) {
                              setState(() {
                                MockDatabase.instance.toggleAttendance(
                                  att.studentId,
                                  newStatus,
                                );
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

  // --- 1. Activities ---
  Widget _buildActivitiesTab(List<ActivityModel> activities) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activities & Requirements Management',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create, publish, and review student work submissions per class section.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
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
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.assignment,
                        color: AppColors.primary,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              act.description,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Section: ${act.section} • Max Score: ${act.maxScore.toInt()} • Submissions: ${act.submissionsCount}/${act.totalStudents}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSecondaryButton(
                        label: 'View Submissions',
                        icon: Icons.people_outline,
                        height: 38,
                        onPressed: () =>
                            ActivitySubmissionsScreen.show(context, act),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
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
        title: const Text('Create New Activity / Requirement'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _actTitleCtrl,
                decoration: const InputDecoration(labelText: 'Activity Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _actDescCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instructions / Description',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
              AppModals.showSuccessDialog(
                context: context,
                title: 'Activity Published',
                message:
                    'Activity successfully broadcasted to student portals.',
              );
            },
            width: 140,
            height: 40,
          ),
        ],
      ),
    );
  }

  // --- 2. Quizzes & Exams ---
  Widget _buildQuizzesTab(List<QuizOrExamModel> quizzes) {
    final quizList = quizzes.where((q) => !q.isExam).toList();
    final examList = quizzes.where((q) => q.isExam).toList();

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assessments (Quizzes & Periodical Examinations)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create and manage Formative Unit Quizzes and Summative Periodical Examinations separately.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                AppPrimaryButton(
                  label: 'Create Assessment',
                  icon: Icons.add_circle_outline,
                  onPressed: () {
                    CreateAssessmentFlowDialog.show(
                      context,
                      onAssessmentCreated: () => setState(() {}),
                    );
                  },
                  height: 42,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs for All, Quizzes, and Periodical Exams
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'All Assessments'),
                  Tab(text: 'Unit Quizzes (Formative)'),
                  Tab(text: 'Periodical Examinations (Summative)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                children: [
                  _buildAssessmentList(quizzes),
                  _buildAssessmentList(quizList),
                  _buildAssessmentList(examList),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentList(List<QuizOrExamModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No assessments in this category yet.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Now'),
              onPressed: () {
                CreateAssessmentFlowDialog.show(
                  context,
                  onAssessmentCreated: () => setState(() {}),
                );
              },
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final q = items[i];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: q.isExam ? AppColors.errorLight : AppColors.infoLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  q.isExam ? Icons.description : Icons.quiz,
                  color: q.isExam ? AppColors.error : AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          q.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          text: q.isExam ? 'PERIODICAL EXAM' : 'UNIT QUIZ',
                          backgroundColor: q.isExam
                              ? AppColors.errorLight
                              : AppColors.infoLight,
                          textColor: q.isExam
                              ? AppColors.error
                              : AppColors.info,
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
                    const SizedBox(height: 6),
                    Text(
                      'Section: ${q.section} • Duration: ${q.durationMinutes} mins • Items: ${q.questions.length} • Total Points: ${q.totalPoints.toInt()} pts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              AppSecondaryButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                height: 36,
                width: 80,
                onPressed: () {
                  EditAssessmentFlowDialog.show(
                    context,
                    assessment: q,
                    onAssessmentUpdated: () => setState(() {}),
                  );
                },
              ),
              const SizedBox(width: 8),
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
    );
  }

  // --- 6. Exam Checker ---
  Widget _buildExamCheckerTab(
    List<ExamSubmissionReview> examReviews,
    List<QuizOrExamModel> quizzes,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exam Auto-Checker & Scoring',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Review student submissions, compare answers against the key, and finalize scores.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: examReviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final rev = examReviews[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fact_check,
                        color: AppColors.success,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rev.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Calculated Auto-Score: ${rev.calculatedScore} / 20.0',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppPrimaryButton(
                        label: 'Review Answers',
                        height: 38,
                        width: 130,
                        onPressed: () {
                          AppModals.showSuccessDialog(
                            context: context,
                            title: 'Exam Verified',
                            message:
                                'All objective answers for ${rev.studentName} verified and matched with answer key.',
                          );
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
          const Text(
            'Item Analysis Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Evaluate question difficulty index and student correctness percentages.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quiz 1: Functions & Domain/Range - Item Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(color: AppColors.border, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                  },
                  children: const [
                    TableRow(
                      decoration: BoxDecoration(color: AppColors.background),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Q #',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Question Concept',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            '% Correct',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Difficulty',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: EdgeInsets.all(10), child: Text('1')),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Domain of rational function'),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('85%'),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Easy',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: EdgeInsets.all(10), child: Text('2')),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Vertical asymptote properties'),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('65%'),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Moderate',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  // --- 8. Grading System ---
  Widget _buildGradingSystemTab(List<GradingCriteria> criteria) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Teacher-Defined Grading Weighting System',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Configure your quarterly grading component percentages according to DepEd / school criteria.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ...criteria.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${c.percentage}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),
            AppPrimaryButton(
              label: 'Update Weighting Criteria',
              onPressed: () {
                AppModals.showSuccessDialog(
                  context: context,
                  title: 'Criteria Updated',
                  message: 'Grading percentages successfully updated for score calculations.',
                );
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
          const Text(
            'Quarterly Grades Computation',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                itemCount: students.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final s = students[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent,
                      child: Text(
                        s.fullName.substring(0, 1),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      s.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'ID: ${s.studentId} • Calculated Quarter Grade',
                    ),
                    trailing: const Text(
                      '92.5 (Outstanding)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
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

  // --- 13. Performance Analytics ---
  Widget _buildPerformanceTab(List<UserModel> students) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Academic Performance & At-Risk Alerts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTopSummaryCard(
                  title: 'Quarter Class Average',
                  mainValue: '88.4%',
                  subText: '↑ 2.1% improvement from Q1',
                  subColor: AppColors.success,
                  icon: Icons.trending_up,
                  iconColor: AppColors.success,
                  iconBgColor: AppColors.successLight,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildTopSummaryCard(
                  title: 'Students At-Risk (< 75)',
                  mainValue: '2',
                  subText: 'Requires remedial interventions',
                  subColor: AppColors.error,
                  icon: Icons.warning_amber_outlined,
                  iconColor: AppColors.error,
                  iconBgColor: AppColors.errorLight,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildTopSummaryCard(
                  title: 'Honor Students (> 90)',
                  mainValue: '14',
                  subText: 'High academic distinction',
                  subColor: AppColors.primary,
                  icon: Icons.emoji_events_outlined,
                  iconColor: AppColors.primary,
                  iconBgColor: const Color(0xFFDBEAFE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Lesson Planning ---
  Widget _buildLessonPlanningTab(List<LessonPlanModel> lessonPlans) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI Lesson Plan Generator (Simulated)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
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
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'AI Lesson Plan Generated',
                    message: 'Simulated AI generated a comprehensive lesson plan for Logarithmic Properties.',
                  );
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
                            lp.topic,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          const StatusBadge(
                            text: 'AI Generated',
                            backgroundColor: AppColors.infoLight,
                            textColor: AppColors.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${lp.duration} • Created: ${lp.createdAt.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Objectives:\n${lp.objectives}',
                        style: const TextStyle(fontSize: 13, height: 1.3),
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

  // --- 4. Learning Materials ---
  Widget _buildLearningMaterialsTab(List<LearningMaterialModel> materials) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Learning Materials Repository',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              AppPrimaryButton(
                label: 'Upload Material',
                icon: Icons.upload_file,
                onPressed: () {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Material Uploaded',
                    message: 'Simulated document successfully added to student repository.',
                  );
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf,
                        color: AppColors.error,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mat.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mat.description,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'File: ${mat.fileName} • Size: ${mat.fileSize}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download'),
                        onPressed: () {
                          AppModals.showSuccessDialog(
                            context: context,
                            title: 'Download Simulated',
                            message: 'File downloaded successfully.',
                          );
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

  // --- 14. Schedule ---
  Widget _buildScheduleTab(List<ScheduleModel> schedules) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Class Schedule & Timetable',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final s = schedules[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Section: ${s.section} • Room: ${s.room}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${s.dayOfWeek} • ${s.startTime} - ${s.endTime}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
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

  // --- 15. Notifications ---
  Widget _buildNotificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications & Institutional Alerts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: MockDatabase.instance.notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final n = MockDatabase.instance.notifications[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: AppColors.warning,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 16. Profile ---
  Widget _buildProfileTab() {
    final t = MockDatabase.instance.currentUser!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Faculty Educator Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Full Name'),
              subtitle: Text(t.fullName),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Institutional Email'),
              subtitle: Text(t.email),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('School Institution'),
              subtitle: const Text('Eduardo Barretto Senior Integrated School'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science),
              title: const Text('Department / Subject Specialization'),
              subtitle: Text(t.departmentOrSection ?? 'General Mathematics'),
            ),
          ],
        ),
      ),
    );
  }
}
