// Legacy prototype tabs remain available for future wiring.
// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'create_requirement_flow.dart';
import 'edit_assessment_flow.dart';
import 'activity_submissions_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedIndex = 0;
  String? _monitoringAssessmentId;
  bool _isSidebarExpanded = true;
  bool _showArchivedStudents = false;
  bool _showNewSchoolYearForm = false;
  bool _showAddClassForm = false;
  final List<String> _classroomSections = ['Section A', 'Section B'];
  final Map<String, String> _classroomGrades = {
    'Section A': 'Grade 11',
    'Section B': 'Grade 11',
  };
  final Map<String, String> _classroomSubjects = {
    'Section A': 'General Mathematics',
    'Section B': 'General Mathematics',
  };
  final Map<String, int> _classroomStudentCounts = {
    'Section A': 5,
    'Section B': 5,
  };
  String _selectedSchoolYear = '2026-2027';
  String _newSchoolYearStructure = 'Quarterly (4 quarters)';
  String _newClassSchoolYear = 'SY 2026-2027';
  String _newClassGradeLevel = 'Grade 11';
  String _studentSearchQuery = '';
  String _parentSearchQuery = '';
  final Set<String> _selectedParentIds = {};
  String _parentSortColumn = 'lastName';
  bool _parentSortAscending = true;
  String _selectedClassFilter = '— Select a class —';
  String _sortColumn = 'lastName';
  bool _sortAscending = true;
  final Set<String> _selectedStudentIds = {};
  String _gradesSectionFilter = 'All Sections';
  String _gradesRankingOrder = 'None';
  String _selectedClassSection = 'Section A';
  ActivityModel? _viewingSubmissionsFor;

  // Gradebook weighting state
  bool _isEditingWeights = false;
  final _weightWWCtrl = TextEditingController(text: '20');
  final _weightPTCtrl = TextEditingController(text: '50');
  final _weightEXCtrl = TextEditingController(text: '30');

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
  final _classSubjectCtrl = TextEditingController();

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
    _classSubjectCtrl.dispose();
    _weightWWCtrl.dispose();
    _weightPTCtrl.dispose();
    _weightEXCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allStudents = MockDatabase.instance.users
        .where((u) => u.role == UserRole.student)
        .toList();
    final parents = MockDatabase.instance.users
        .where((u) => u.role == UserRole.parent)
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
                      Image.asset('lib/school_logo.png', width: 32, height: 32),
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
                      _buildSectionHeader('MY CLASSROOM'),
                      _buildNavItem(
                        17,
                        'Classroom Setup',
                        Icons.apartment_outlined,
                      ),
                      _buildNavItem(18, 'Gradebook', Icons.menu_book_outlined),
                      _buildNavItem(
                        12,
                        'Manage Students',
                        Icons.groups_outlined,
                      ),
                      _buildNavItem(
                        19,
                        'Manage Parents',
                        Icons.family_restroom_outlined,
                      ),
                      const SizedBox(height: 8),
                      _buildSectionHeader('TEACHING'),
                      _buildNavItem(1, 'Classwork', Icons.assignment_outlined),
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
                      _buildNavItem(
                        20,
                        'Assessment Monitoring',
                        Icons.security,
                      ),
                      _buildNavItem(7, 'Item Analysis', Icons.insights),
                      _buildNavItem(9, 'Grades', Icons.grade_outlined),
                      const SizedBox(height: 8),
                      _buildSectionHeader('INSIGHTS & MANAGEMENT'),
                      _buildNavItem(
                        13,
                        'Performance Analytics',
                        Icons.trending_up,
                      ),
                      _buildNavItem(
                        14,
                        'My Schedule',
                        Icons.calendar_today_outlined,
                      ),
                      _buildNavItem(
                        15,
                        'Notifications',
                        Icons.notifications_outlined,
                      ),
                      _buildNavItem(16, 'Profile', Icons.person_outline),
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
                          Icons.campaign_outlined,
                          color: AppColors.primary,
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
                                'Ma\'am Karen',
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
                      parents,
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
        return 'Classroom';
      case 18:
        return 'Grades Management';
      case 19:
        return 'Parent Directory';
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'Assessments';
      case 3:
        return 'Lesson Planning';
      case 4:
        return 'Materials Repository';
      case 5:
        return 'Attendance Logs';
      case 6:
        return 'Exam Checker';
      case 7:
        return 'Item Analysis';
      case 8:
        return 'Grading Weights';
      case 9:
        return 'Student Achievement Records';
      case 13:
        return 'Institutional Analytics';
      case 14:
        return 'My Teaching Schedule';
      case 15:
        return 'Message & Alert Center';
      case 16:
        return 'Faculty Profile';
      case 20:
        return 'Assessment Monitoring';
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
    List<UserModel> parents,
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
        return _viewingSubmissionsFor == null
            ? _buildUnifiedAssessmentsTab(activities, quizzesAndExams)
            : ActivitySubmissionsScreen(
                activity: _viewingSubmissionsFor!,
                embedded: true,
                onBack: () => setState(() => _viewingSubmissionsFor = null),
              );
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
      case 18:
        return _buildGradebookTab();
      case 12:
        return _buildStudentManagementTab(activeStudents, archivedStudents);
      case 19:
        return _buildParentManagementTab(parents);
      case 13:
        return _buildPerformanceTab(activeStudents);
      case 14:
        return _buildScheduleTab(schedules);
      case 15:
        return _buildNotificationsTab();
      case 20:
        return _buildAssessmentMonitoringTab(quizzesAndExams);
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
    final todaysClassesCount = 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back, Ma\'am Karen!',
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
                  mainValue: '${activeStudents.length}',
                  subText: 'Across 2 sections (Grade 11)',
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
                        subject: 'General Mathematics',
                        sectionAndRoom: 'Grade 11 - Section A • Room 304',
                        time: '07:30 AM - 09:00 AM',
                        isDone: true,
                        attendanceStats: 'Attendance: 4 / 5 present',
                      ),
                      const SizedBox(height: 12),
                      _buildClassItem(
                        subject: 'General Mathematics',
                        sectionAndRoom: 'Grade 11 - Section B • Room 305',
                        time: '09:15 AM - 10:45 AM',
                        isDone: true,
                        attendanceStats: 'Attendance: 5 / 5 present',
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
                        title: 'Record Attendance',
                        icon: Icons.checklist_rtl_outlined,
                        onTap: () => setState(() => _selectedIndex = 5),
                      ),
                      const Divider(height: 1),
                      _buildQuickActionTile(
                        title: 'Create Classwork',
                        icon: Icons.assignment_outlined,
                        onTap: () => _showUnifiedCreateChooser(context),
                      ),
                      const Divider(height: 1),
                      _buildQuickActionTile(
                        title: 'Add Assessment',
                        icon: Icons.post_add_outlined,
                        onTap: () => _showUnifiedCreateChooser(context),
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
                    student.lrn ?? student.studentId ?? '',
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

  int _calculateAge(DateTime birthday) {
    final today = DateTime.now();
    var age = today.year - birthday.year;
    final birthdayThisYear = DateTime(today.year, birthday.month, birthday.day);
    if (today.isBefore(birthdayThisYear)) age--;
    return age;
  }

  String _formatStudentDisplayName(UserModel student) {
    final lastName = student.lastName?.trim().isNotEmpty == true
        ? student.lastName!.trim()
        : student.fullName.split(' ').last;
    final firstName = student.firstName?.trim().isNotEmpty == true
        ? student.firstName!.trim()
        : (student.fullName.split(' ').isNotEmpty
              ? student.fullName.split(' ').first
              : student.fullName);
    final middleName = student.middleName?.trim() ?? '';
    final middleInitial = middleName.isEmpty ? '' : ' ${middleName[0]}.';
    return '$lastName, $firstName$middleInitial';
  }

  Widget _buildParentManagementTab(List<UserModel> parents) {
    var displayList = parents.where((p) {
      final linkedStudent = MockDatabase.instance.users
          .where((user) => user.id == p.linkedStudentId)
          .firstOrNull;
      final matchesSearch =
          p.fullName.toLowerCase().contains(_parentSearchQuery.toLowerCase()) ||
          p.email.toLowerCase().contains(_parentSearchQuery.toLowerCase()) ||
          (p.contactNumber ?? '').contains(_parentSearchQuery) ||
          (linkedStudent?.fullName.toLowerCase().contains(
                _parentSearchQuery.toLowerCase(),
              ) ??
              false);
      final matchesClass =
          _selectedClassFilter == '— Select a class —' ||
          (linkedStudent?.departmentOrSection == _selectedClassFilter);
      return matchesSearch && matchesClass;
    }).toList();

    // Sort logic
    displayList.sort((a, b) {
      int cmp = 0;
      switch (_parentSortColumn) {
        case 'lastName':
          cmp = a.fullName
              .split(' ')
              .last
              .compareTo(b.fullName.split(' ').last);
          break;
        case 'firstName':
          cmp = a.fullName
              .split(' ')
              .first
              .compareTo(b.fullName.split(' ').first);
          break;
        case 'email':
          cmp = a.email.compareTo(b.email);
          break;
        case 'contact':
          cmp = (a.contactNumber ?? '').compareTo(b.contactNumber ?? '');
          break;
        default:
          cmp = 0;
      }
      return _parentSortAscending ? cmp : -cmp;
    });

    bool allSelected =
        displayList.isNotEmpty &&
        displayList.every((p) => _selectedParentIds.contains(p.id));

    const colCheckWidth = 48.0;
    const colNumWidth = 56.0;
    const colLastNameWidth = 150.0;
    const colFirstNameWidth = 140.0;
    const colRelWidth = 130.0;
    const colStudentWidth = 190.0;
    const colSectionWidth = 130.0;
    const colEmailWidth = 250.0;
    const colContactWidth = 160.0;
    const colStatusWidth = 140.0;
    const colActionsWidth = 120.0;

    const totalTableWidth =
        colCheckWidth +
        colNumWidth +
        colLastNameWidth +
        colFirstNameWidth +
        colRelWidth +
        colStudentWidth +
        colSectionWidth +
        colEmailWidth +
        colContactWidth +
        colStatusWidth +
        colActionsWidth;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage Parents / Guardians',
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
                      backgroundColor: const Color(0xFF0F8A48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text(
                      'Import Excel',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {},
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
                      'Add Parent',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _showAddParentDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'View and manage parent or guardian accounts linked to enrolled students.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
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
                  onChanged: (v) => setState(() => _parentSearchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by parent name, student, or email...',
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
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text(
                  'View Archive',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: totalTableWidth,
                        child: Column(
                          children: [
                            Container(
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A56DB),
                              ),
                              child: Row(
                                children: [
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
                                              for (var p in displayList)
                                                _selectedParentIds.add(p.id);
                                            } else {
                                              for (var p in displayList)
                                                _selectedParentIds.remove(p.id);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
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
                                  _buildHeaderCell(
                                    width: colLastNameWidth,
                                    child: _buildClickableParentHeaderTitle(
                                      'LAST NAME',
                                      'lastName',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colFirstNameWidth,
                                    child: _buildClickableParentHeaderTitle(
                                      'FIRST NAME',
                                      'firstName',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colRelWidth,
                                    child: const Text(
                                      'RELATIONSHIP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colStudentWidth,
                                    child: const Text(
                                      'LINKED STUDENT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colSectionWidth,
                                    child: const Text(
                                      'SECTION',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colEmailWidth,
                                    child: _buildClickableParentHeaderTitle(
                                      'EMAIL',
                                      'email',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colContactWidth,
                                    child: _buildClickableParentHeaderTitle(
                                      'CONTACT NO.',
                                      'contact',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colStatusWidth,
                                    child: const Text(
                                      'STATUS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
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
                            Expanded(
                              child: displayList.isEmpty
                                  ? const Center(
                                      child: Text('No parents found.'),
                                    )
                                  : ListView.builder(
                                      itemCount: displayList.length,
                                      itemBuilder: (ctx, i) {
                                        final p = displayList[i];
                                        final isSelected = _selectedParentIds
                                            .contains(p.id);
                                        final linkedStudent = MockDatabase
                                            .instance
                                            .users
                                            .where(
                                              (user) =>
                                                  user.id == p.linkedStudentId,
                                            )
                                            .firstOrNull;
                                        final nameParts = p.fullName
                                            .trim()
                                            .split(' ');
                                        final lastName = nameParts.isEmpty
                                            ? p.fullName
                                            : nameParts.last;
                                        final firstName = nameParts.length > 1
                                            ? nameParts
                                                  .sublist(
                                                    0,
                                                    nameParts.length - 1,
                                                  )
                                                  .join(' ')
                                            : '';

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
                                              _buildDataCell(
                                                width: colCheckWidth,
                                                child: Center(
                                                  child: Checkbox(
                                                    value: isSelected,
                                                    onChanged: (val) => setState(
                                                      () => val == true
                                                          ? _selectedParentIds
                                                                .add(p.id)
                                                          : _selectedParentIds
                                                                .remove(p.id),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colNumWidth,
                                                child: Center(
                                                  child: Text(
                                                    '${i + 1}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colLastNameWidth,
                                                child: Text(
                                                  lastName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colFirstNameWidth,
                                                child: Text(
                                                  firstName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colRelWidth,
                                                child: Text(
                                                  p.parentGuardianRelationship ??
                                                      'Parent/Guardian',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colStudentWidth,
                                                child: Text(
                                                  linkedStudent?.fullName ??
                                                      'Unlinked student',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colSectionWidth,
                                                child: Text(
                                                  linkedStudent
                                                          ?.departmentOrSection ??
                                                      'Unlinked',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colEmailWidth,
                                                child: Text(
                                                  p.email,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colContactWidth,
                                                child: Text(
                                                  p.contactNumber ?? 'N/A',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colStatusWidth,
                                                child:
                                                    StatusBadge.fromAccountStatus(
                                                      p.status,
                                                    ),
                                              ),
                                              _buildDataCell(
                                                width: colActionsWidth,
                                                hasRightBorder: false,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                      onPressed: () =>
                                                          _showEditParentDialog(
                                                            p,
                                                          ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                        color: Colors.redAccent,
                                                      ),
                                                      onPressed: () async {
                                                        final confirm =
                                                            await AppModals.showConfirmDialog(
                                                              context: context,
                                                              title: 'Remove Parent Account',
                                                              message:
                                                                  'Are you sure you want to remove the account for ${p.fullName}?',
                                                              confirmLabel:
                                                                  'Remove',
                                                              confirmColor:
                                                                  AppColors
                                                                      .warning,
                                                            );
                                                        if (confirm == true) {
                                                          setState(() {
                                                            MockDatabase
                                                                .instance
                                                                .users
                                                                .removeWhere(
                                                                  (u) =>
                                                                      u.id ==
                                                                      p.id,
                                                                );
                                                          });
                                                        }
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
                          ],
                        ),
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

  Widget _buildClickableParentHeaderTitle(String title, String columnKey) {
    final isCurrent = _parentSortColumn == columnKey;
    final icon = !isCurrent ? ' ↕' : (_parentSortAscending ? ' ▴' : ' ▾');
    return InkWell(
      onTap: () => setState(() {
        if (_parentSortColumn == columnKey) {
          _parentSortAscending = !_parentSortAscending;
        } else {
          _parentSortColumn = columnKey;
          _parentSortAscending = true;
        }
      }),
      child: Text(
        '$title$icon',
        style: TextStyle(
          color: Colors.white,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Future<void> _showAddParentDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final contactController = TextEditingController();
    String? relationship;
    String? linkedStudentId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Parent / Guardian'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Parent / Guardian Name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Relationship to Student',
                    ),
                    items: const ['Mother', 'Father', 'Guardian', 'Other']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => relationship = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Linked Student',
                    ),
                    items: MockDatabase.instance.users
                        .where((u) => u.role == UserRole.student)
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => linkedStudentId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    MockDatabase.instance.createParentAccount(
                      fullName: nameController.text,
                      email: emailController.text,
                      contactNumber: contactController.text,
                      relationship: relationship!,
                      linkedStudentId: linkedStudentId!,
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Parent'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditParentDialog(UserModel parent) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: parent.fullName);
    final emailController = TextEditingController(text: parent.email);
    final contactController = TextEditingController(text: parent.contactNumber);
    String? relationship = parent.parentGuardianRelationship;
    String? linkedStudentId = parent.linkedStudentId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Parent / Guardian'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Parent / Guardian Name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: relationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship to Student',
                    ),
                    items: const ['Mother', 'Father', 'Guardian', 'Other']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => relationship = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: linkedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Linked Student',
                    ),
                    items: MockDatabase.instance.users
                        .where((u) => u.role == UserRole.student)
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => linkedStudentId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    MockDatabase.instance.updateParentAccount(
                      id: parent.id,
                      fullName: nameController.text,
                      email: emailController.text,
                      contactNumber: contactController.text,
                      relationship: relationship!,
                      linkedStudentId: linkedStudentId!,
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Changes'),
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
              (s.lrn?.toLowerCase().contains(
                    _studentSearchQuery.toLowerCase(),
                  ) ??
                  false);
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
          cmp = (a.lrn ?? a.studentId ?? '').compareTo(
            b.lrn ?? b.studentId ?? '',
          );
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Students',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'View and manage your student directory, update profiles, and handle account archives.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F8A48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text(
                      'Import Excel',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showImportStudentsDialog(context),
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
                    hintText: 'Search by name or LRN...',
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
                                    child: const Text(
                                      'EMAIL',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  // CONTACT NO.
                                  _buildHeaderCell(
                                    width: colContactWidth,
                                    child: const Text(
                                      'CONTACT NO.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
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
                                            s.lrn ?? s.studentId ?? 'N/A';
                                        final gender = (s.id.hashCode % 2 == 0)
                                            ? 'Male'
                                            : 'Female';
                                        final bday = s.birthday != null
                                            ? '${s.birthday!.year}-${s.birthday!.month.toString().padLeft(2, '0')}-${s.birthday!.day.toString().padLeft(2, '0')}'
                                            : '2006-05-12';
                                        final age = s.birthday != null
                                            ? _calculateAge(s.birthday!)
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
                                                child: Text(
                                                  lrn.replaceAll(' ', ''),
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontFamily: 'monospace',
                                                    color: Color(0xFF475569),
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

  void _showImportStudentsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Students'),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'File Selected',
                    message: 'Prototype only: the selected CSV or Excel file will be processed here.',
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.upload_file_outlined,
                        size: 42,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Click to select a CSV or Excel file',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Accepted: .csv, .xlsx, .xls',
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Required: LRN, Last Name, First Name, Gender, Birthday, Email, Contact Number',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Optional: Middle Name',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please follow the format shown above so the system can accept the file. Download the template to ensure the columns and format are correct.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569), fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F8A48),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Download Template'),
                onPressed: () {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Template Ready',
                    message: 'Student import template downloaded. Fill in the required columns before importing.',
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddStudentModal(BuildContext context) {
    _studentNameCtrl.clear();
    _studentIdCtrl.clear();
    _studentSectionCtrl.text = 'Section A';

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
                  labelText: 'Assigned Section (e.g. Section A)',
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
                        '${_studentNameCtrl.text.trim().toLowerCase().replaceAll(" ", ".")}@gmail.com',
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
    _studentIdCtrl.text = student.lrn ?? student.studentId ?? '';
    _studentSectionCtrl.text = student.departmentOrSection ?? 'Section A';

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
                decoration: const InputDecoration(labelText: 'LRN'),
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
        MockDatabase.instance.currentUser?.fullName ?? 'Karen P. Gonzaga';

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
                  children: sections
                      .map(
                        (section) => _buildClassroomPrototypeCard(
                          section: section,
                          teacherName: teacherName,
                          gradeLevel: _classroomGrades[section] ?? 'Grade 11',
                          subject:
                              _classroomSubjects[section] ??
                              'General Mathematics',
                          studentCount: _classroomStudentCounts[section] ?? 0,
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildClassroomPrototypeCard({
    required String section,
    required String teacherName,
    required String gradeLevel,
    required String subject,
    required int studentCount,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildClassroomBadge(gradeLevel),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                onPressed: () {},
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: () {
                  setState(() {
                    _classroomSections.remove(section);
                    _classroomGrades.remove(section);
                    _classroomSubjects.remove(section);
                    _classroomStudentCounts.remove(section);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildClassroomInfoTile(
            icon: Icons.people_outline,
            text: '$studentCount students',
            color: const Color(0xFFF3F6FC),
            iconColor: const Color(0xFF1A56DB),
          ),
          const SizedBox(height: 16),
          const Text(
            'SUBJECT',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildClassroomInfoTile(
            text: subject,
            color: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFDBEAFE),
            textColor: const Color(0xFF1E293B),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _selectedIndex = 12),
              icon: const Icon(Icons.person_add_alt, size: 17),
              label: const Text(
                'Add Students',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8F8F0),
                foregroundColor: const Color(0xFF166534),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFB9F6CA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE0EDFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1A56DB),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildClassroomInfoTile({
    required String text,
    required Color color,
    IconData? icon,
    Color? iconColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSchoolYear,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
                items: const [
                  DropdownMenuItem(
                    value: '2026-2027',
                    child: Text('SY 2026-2027 (Current)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSchoolYear = value);
                  }
                },
              ),
            ),
          ),
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
                  menuMaxHeight: 280,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
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
                  menuMaxHeight: 280,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
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
              const SizedBox(width: 16),
              Expanded(child: _buildSetupField('SUBJECT', _classSubjectCtrl)),
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
                  onPressed: _addClassFromForm,
                  child: const Text('Add Class'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addClassFromForm() {
    final section = _classSectionCtrl.text.trim();
    final subject = _classSubjectCtrl.text.trim();

    String? errorMessage;
    if (section.isEmpty) {
      errorMessage = 'Please enter a section name.';
    } else if (subject.isEmpty) {
      errorMessage = 'Please enter the subject handled for this class.';
    } else if (_classroomSections.contains(section)) {
      errorMessage = 'That section has already been added.';
    } else if (_classroomSections.length >= 10) {
      errorMessage = 'You can add up to 10 classes.';
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    setState(() {
      _classroomSections.add(section);
      _classroomGrades[section] = _newClassGradeLevel;
      _classroomSubjects[section] = subject;
      _classroomStudentCounts[section] = 0;
      _classSectionCtrl.clear();
      _classSubjectCtrl.clear();
      _showAddClassForm = false;
    });
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
    final gradeLevel = _classroomGrades[section] ?? 'Grade 11';
    final subject = _classroomSubjects[section] ?? 'General Mathematics';
    final studentCount = _classroomStudentCounts[section] ?? 0;
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFFF59E0B)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0EDFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  gradeLevel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A56DB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 16,
                  color: Color(0xFF1A56DB),
                ),
                const SizedBox(width: 8),
                Text(
                  '$studentCount students',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SUBJECT',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFDBEAFE)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              subject,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _selectedIndex = 12),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8F8F0),
                foregroundColor: const Color(0xFF166534),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFB9F6CA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.person_add_alt,
                size: 18,
                color: Color(0xFF166534),
              ),
              label: const Text(
                'Add Students',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Attendance Tracker ---
  String _attendanceClassFilter = 'Grade 11 - Section A • General Mathematics';
  String _selectedAttendanceView =
      'Take Attendance'; // 'Take Attendance' or 'View History'
  DateTime _attendanceSelectedDate = DateTime(2026, 9, 13);
  String _attendanceSearchQuery = '';

  // Keep state for selected attendance status of students
  // Key is student ID, value is active selected status
  final Map<String, AttendanceStatus> _tempAttendanceStates = {};

  Widget _buildAttendanceTab(List<AttendanceRecord> attendance) {
    final allActiveStudents = MockDatabase.instance.users
        .where((u) => u.role == UserRole.student && !u.isArchived)
        .toList();
    allActiveStudents.sort((a, b) {
      final aLast = (a.lastName ?? a.fullName.split(' ').last).toLowerCase();
      final bLast = (b.lastName ?? b.fullName.split(' ').last).toLowerCase();
      return aLast.compareTo(bLast);
    });
    final activeStudents = allActiveStudents.where((student) {
      final query = _attendanceSearchQuery.trim().toLowerCase();
      return query.isEmpty ||
          _formatStudentDisplayName(student).toLowerCase().contains(query) ||
          (student.lrn?.toLowerCase().contains(query) ?? false);
    }).toList();

    // Initialize temporary states for mock students if empty
    for (var s in allActiveStudents) {
      if (!_tempAttendanceStates.containsKey(s.id)) {
        // Set some default states matching: 1 present, 1 absent, 1 late, others present
        if (s.fullName.contains('alu')) {
          _tempAttendanceStates[s.id] = AttendanceStatus.present;
        } else if (s.fullName.contains('Calicss')) {
          _tempAttendanceStates[s.id] = AttendanceStatus.absent;
        } else if (s.fullName.contains('jowa')) {
          _tempAttendanceStates[s.id] = AttendanceStatus.late;
        } else {
          _tempAttendanceStates[s.id] = AttendanceStatus.present;
        }
      }
    }

    int presentCount = _tempAttendanceStates.values
        .where((st) => st == AttendanceStatus.present)
        .length;
    int absentCount = _tempAttendanceStates.values
        .where((st) => st == AttendanceStatus.absent)
        .length;
    int lateCount = _tempAttendanceStates.values
        .where((st) => st == AttendanceStatus.late)
        .length;
    int excusedCount = _tempAttendanceStates.values
        .where((st) => st == AttendanceStatus.excused)
        .length;
    // Calculated stats
    int totalCount = activeStudents.length;
    double percentPresent = totalCount > 0
        ? (presentCount / totalCount) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A56DB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Take Attendance & RFID Logs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _attendanceClassFilter,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab View Headers
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAttendanceView == 'Take Attendance'
                      ? const Color(0xFF1A56DB)
                      : Colors.white,
                  foregroundColor: _selectedAttendanceView == 'Take Attendance'
                      ? Colors.white
                      : const Color(0xFF475569),
                  side: BorderSide(
                    color: _selectedAttendanceView == 'Take Attendance'
                        ? Colors.transparent
                        : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () =>
                    setState(() => _selectedAttendanceView = 'Take Attendance'),
                child: const Text(
                  'Take Attendance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAttendanceView == 'View History'
                      ? const Color(0xFF1A56DB)
                      : Colors.white,
                  foregroundColor: _selectedAttendanceView == 'View History'
                      ? Colors.white
                      : const Color(0xFF475569),
                  side: BorderSide(
                    color: _selectedAttendanceView == 'View History'
                        ? Colors.transparent
                        : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () =>
                    setState(() => _selectedAttendanceView = 'View History'),
                child: const Text(
                  'View History',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search bar (Left side of date picker)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Student Input
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _attendanceSearchQuery = value),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search student name or LRN',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Picker Input Box
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _attendanceSelectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null)
                          setState(() => _attendanceSelectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_attendanceSelectedDate.day.toString().padLeft(2, '0')}/${_attendanceSelectedDate.month.toString().padLeft(2, '0')}/${_attendanceSelectedDate.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Students Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 16,
                            color: Color(0xFF107B41),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalCount Students',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Percent Present Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Color(0xFF107B41),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${percentPresent.toStringAsFixed(1)}% Present',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF107B41),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Config Buttons Row (Aligned with Class Dropdown)
                Row(
                  children: [
                    // Class / Section Dropdown Aligned Here
                    const Text(
                      'Class / Section:  ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _attendanceClassFilter,
                          style: const TextStyle(
                            color: Color(0xFF1A56DB),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          isDense: true,
                          items:
                              [
                                    'Grade 11 - Section A • General Mathematics',
                                    'Grade 11 - Section B • General Mathematics',
                                  ]
                                  .map(
                                    (val) => DropdownMenuItem(
                                      value: val,
                                      child: Text(val),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null)
                              setState(() => _attendanceClassFilter = v);
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildHeaderConfigButton(
                      label: 'Group by Gender',
                      icon: Icons.grid_view_outlined,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderConfigButton(
                      label: 'Sort: A-Z',
                      icon: Icons.sort_by_alpha,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderConfigButton(
                      label: 'Holiday / Suspension',
                      icon: Icons.celebration_outlined,
                      onPressed: () {
                        AppModals.showSuccessDialog(
                          context: context,
                          title: 'Holiday Registered',
                          message:
                              'All students will be marked excused for today.',
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    // MARK ALL PRESENT BUTTON
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          for (var s in activeStudents) {
                            _tempAttendanceStates[s.id] =
                                AttendanceStatus.present;
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF107B41),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFF107B41)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Mark All Present',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // MARK ALL ABSENT BUTTON
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          for (var s in activeStudents) {
                            _tempAttendanceStates[s.id] =
                                AttendanceStatus.absent;
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Mark All Absent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Attendance status summary boxes
          Row(
            children: [
              _buildAttendanceCountBadge(
                label: '$presentCount PRESENT',
                color: const Color(0xFF107B41),
              ),
              const SizedBox(width: 8),
              _buildAttendanceCountBadge(
                label: '$absentCount ABSENT',
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              _buildAttendanceCountBadge(
                label: '$lateCount LATE',
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              _buildAttendanceCountBadge(
                label: '$excusedCount EXCUSED',
                color: const Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Student Attendance Status Row Checklist List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeStudents.length,
            itemBuilder: (ctx, i) {
              final student = activeStudents[i];
              final currentStatus =
                  _tempAttendanceStates[student.id] ?? AttendanceStatus.present;
              final initials =
                  student.fullName.substring(0, 1).toUpperCase() +
                  (student.fullName.contains(' ')
                      ? student.fullName
                            .split(' ')[1]
                            .substring(0, 1)
                            .toUpperCase()
                      : '');

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Index
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    // Initials Avatar
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1A56DB),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Student name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatStudentDisplayName(student),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.nfc_outlined,
                                size: 12,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'RFID Ready • ESP32 Sync Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (currentStatus ==
                                  AttendanceStatus.present) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Logged via RFID',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Rounded check buttons row
                    Row(
                      children: [
                        // PRESENT check
                        _buildAttendanceActionButton(
                          icon: Icons.check,
                          color: const Color(0xFF107B41),
                          isActive: currentStatus == AttendanceStatus.present,
                          onPressed: () {
                            setState(
                              () => _tempAttendanceStates[student.id] =
                                  AttendanceStatus.present,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // ABSENT check
                        _buildAttendanceActionButton(
                          icon: Icons.close,
                          color: const Color(0xFFEF4444),
                          isActive: currentStatus == AttendanceStatus.absent,
                          onPressed: () {
                            setState(
                              () => _tempAttendanceStates[student.id] =
                                  AttendanceStatus.absent,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // LATE check
                        _buildAttendanceActionButton(
                          icon: Icons.access_time,
                          color: const Color(0xFFD97706),
                          isActive: currentStatus == AttendanceStatus.late,
                          onPressed: () {
                            setState(
                              () => _tempAttendanceStates[student.id] =
                                  AttendanceStatus.late,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // EXCUSED check
                        _buildAttendanceActionButton(
                          icon: Icons.assignment_turned_in_outlined,
                          color: const Color(0xFF64748B),
                          isActive: currentStatus == AttendanceStatus.excused,
                          onPressed: () {
                            setState(
                              () => _tempAttendanceStates[student.id] =
                                  AttendanceStatus.excused,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Bottom Action Save Attendance Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text(
                  'Save Attendance for September 13, 2026',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Attendance Saved',
                    message: 'Roster attendance has been committed successfully to system logs.',
                  );
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text(
                  'Clear',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {
                    _tempAttendanceStates.clear();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderConfigButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: const Color(0xFF64748B),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(icon, size: 16, color: const Color(0xFF64748B)),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildAttendanceStatusChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label $count',
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCountBadge({
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceActionButton({
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isActive ? color : const Color(0xFFF1F5F9),
          foregroundColor: isActive ? Colors.white : const Color(0xFF94A3B8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isActive
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 15),
      ),
    );
  }

  Widget _buildUnifiedAssessmentsTab(
    List<ActivityModel> activities,
    List<QuizOrExamModel> assessments,
  ) {
    final writtenWork = <Widget>[
      ...activities
          .where(
            (item) =>
                !item.isRequirement &&
                item.assignedSections.contains(_selectedClassSection),
          )
          .map((item) => _buildUnifiedActivityCard(item, 'WW')),
      ...assessments
          .where(
            (item) =>
                !item.isExam &&
                item.assignedSections.contains(_selectedClassSection),
          )
          .map((item) => _buildUnifiedAssessmentCard(item, 'WW')),
    ];
    final performanceTasks = activities
        .where(
          (item) =>
              item.isRequirement &&
              item.assignedSections.contains(_selectedClassSection),
        )
        .map((item) => _buildUnifiedActivityCard(item, 'PT'))
        .toList();
    final examinations = assessments
        .where(
          (item) =>
              item.isExam &&
              item.assignedSections.contains(_selectedClassSection),
        )
        .map((item) => _buildUnifiedAssessmentCard(item, 'EX'))
        .toList();

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
                      'Classwork',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create activities, performance tasks, quizzes, and exams in one place.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                  Tab(text: 'Written Works (WW)'),
                  Tab(text: 'Performance Tasks (PT)'),
                  Tab(text: 'Examinations (EX)'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUnifiedCategoryView(
                    label: 'Written Works',
                    items: writtenWork,
                    emptyMessage: 'No written work for this section yet.',
                    onCreate: () => _showUnifiedCreateChooser(context, 'WW'),
                  ),
                  _buildUnifiedCategoryView(
                    label: 'Performance Tasks',
                    items: performanceTasks,
                    emptyMessage: 'No performance tasks for this section yet.',
                    onCreate: () => _showUnifiedCreateChooser(context, 'PT'),
                  ),
                  _buildUnifiedCategoryView(
                    label: 'Examinations',
                    items: examinations,
                    emptyMessage: 'No examinations for this section yet.',
                    onCreate: () => _showUnifiedCreateChooser(context, 'EX'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedCategoryView({
    required String label,
    required List<Widget> items,
    required String emptyMessage,
    required VoidCallback onCreate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: AppPrimaryButton(
            label: 'Create $label',
            icon: Icons.add,
            onPressed: onCreate,
            height: 38,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildUnifiedItemList(items, emptyMessage)),
      ],
    );
  }

  Widget _buildUnifiedItemList(List<Widget> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => items[index],
    );
  }

  Widget _buildUnifiedActivityCard(ActivityModel item, String category) {
    final dueDate = item.deadlineForSection(_selectedClassSection);
    return _buildUnifiedCard(
      title: item.title,
      description: item.isRequirement ? '' : item.description,
      category: category,
      details: item.isRequirement
          ? '${item.section} • ${item.maxScore.toInt()} pts • Due ${_monthName(dueDate.month)} ${dueDate.day}, ${_formatTime(dueDate)}'
          : '${item.section} • ${item.maxScore.toInt()} pts • Due ${_monthName(dueDate.month)} ${dueDate.day}',
      icon: Icons.assignment_outlined,
      onPressed: () => setState(() {
        _viewingSubmissionsFor = item;
      }),
      actionLabel: 'View Submissions',
      onEdit: () => _showEditActivityModal(item),
      onDelete: () => _confirmDeleteActivity(item),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _buildUnifiedAssessmentCard(QuizOrExamModel item, String category) {
    return _buildUnifiedCard(
      title: item.title,
      description: item.description,
      category: category,
      details:
          '${item.section} • ${item.totalPoints.toInt()} pts • Start ${_monthName(item.scheduleDate.month)} ${item.scheduleDate.day}, ${_formatTime(item.scheduleDate)}',
      icon: item.isExam ? Icons.description_outlined : Icons.quiz_outlined,
      onPressed: () {},
      actionLabel: 'View Scores',
      onEdit: () => EditAssessmentFlowDialog.show(
        context,
        assessment: item,
        onAssessmentUpdated: () => setState(() {}),
      ),
      onDelete: () => _confirmDeleteAssessment(item),
    );
  }

  Widget _buildUnifiedCard({
    required String title,
    required String description,
    required String category,
    required String details,
    required IconData icon,
    required VoidCallback onPressed,
    required String actionLabel,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final isPerformanceTask = category == 'PT';
    final isExam = category == 'EX';
    final badgeBackground = isPerformanceTask
        ? const Color(0xFFE8F8F0)
        : isExam
        ? const Color(0xFFF3F0FF)
        : const Color(0xFFE8F0FF);
    final badgeText = isPerformanceTask
        ? const Color(0xFF166534)
        : isExam
        ? const Color(0xFF6D28D9)
        : const Color(0xFF1D4ED8);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAssessmentCategoryBadge(
                      category,
                      badgeBackground,
                      badgeText,
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 4,
            children: [
              AppSecondaryButton(
                label: actionLabel,
                icon: Icons.open_in_new,
                height: 38,
                onPressed: onPressed,
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteActivity(ActivityModel item) {
    _showDeleteConfirmation(
      title: item.title,
      onDelete: () {
        setState(() => MockDatabase.instance.deleteActivity(item.id));
      },
    );
  }

  void _confirmDeleteAssessment(QuizOrExamModel item) {
    _showDeleteConfirmation(
      title: item.title,
      onDelete: () {
        setState(() => MockDatabase.instance.deleteQuizOrExam(item.id));
      },
    );
  }

  void _showDeleteConfirmation({
    required String title,
    required VoidCallback onDelete,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?\n\n$title'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              onDelete();
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditActivityModal(ActivityModel item) {
    if (!item.isRequirement) {
      return;
    }
    CreateRequirementFlowDialog.show(
      context,
      existingTask: item,
      initialSection: item.assignedSections.first,
      onRequirementCreated: () => setState(() {}),
    );
  }

  void _showUnifiedCreateChooser(BuildContext context, [String? category]) {
    if (category == 'EX') {
      CreateAssessmentFlowDialog.show(
        context,
        initialSection: _selectedClassSection,
        initialIsExam: true,
        skipTypeSelection: true,
        onAssessmentCreated: () => setState(() {}),
      );
      return;
    }
    if (category == 'PT') {
      CreateRequirementFlowDialog.show(
        context,
        initialSection: _selectedClassSection,
        onRequirementCreated: () => setState(() {}),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category == null ? 'Create Classwork' : 'Create $category Item',
        ),
        content: const Text(
          'Choose the grading category and use the appropriate creation flow.',
        ),
        actions: [
          if (category != 'PT' && category != 'EX')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                CreateRequirementFlowDialog.show(
                  context,
                  initialSection: _selectedClassSection,
                  isPerformanceTask: false,
                  onRequirementCreated: () => setState(() {}),
                );
              },
              child: const Text('Activity / Assignment'),
            ),
          if (category != 'PT')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                CreateAssessmentFlowDialog.show(
                  context,
                  initialSection: _selectedClassSection,
                  initialIsExam: category == 'EX',
                  skipTypeSelection: true,
                  onAssessmentCreated: () => setState(() {}),
                );
              },
              child: Text(category == 'EX' ? 'Exam' : 'Quiz'),
            ),
          if (category != 'WW' && category != 'EX')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                CreateRequirementFlowDialog.show(
                  context,
                  initialSection: _selectedClassSection,
                  onRequirementCreated: () => setState(() {}),
                );
              },
              child: const Text('Classwork'),
            ),
        ],
      ),
    );
  }

  // --- Legacy activity renderer ---
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
                    'Legacy classwork view',
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
                            _buildAssessmentCategoryBadge(
                              act.isRequirement ? 'PT' : 'WW',
                              act.isRequirement
                                  ? const Color(0xFFE8F8F0)
                                  : const Color(0xFFE8F0FF),
                              act.isRequirement
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF1D4ED8),
                            ),
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

  void _showCreateActivityModal(
    BuildContext context, {
    bool isPerformanceTask = false,
  }) {
    CreateRequirementFlowDialog.show(
      context,
      initialSection: _selectedClassSection,
      isPerformanceTask: false,
      onRequirementCreated: () => setState(() {}),
    );
  }

  // --- Legacy assessment renderer ---
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
                      'Legacy assessment view',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This legacy renderer is retained for compatibility.',
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
                        _buildAssessmentCategoryBadge(
                          q.isExam ? 'EX' : 'WW',
                          q.isExam
                              ? const Color(0xFFF3F0FF)
                              : const Color(0xFFE8F0FF),
                          q.isExam
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFF1D4ED8),
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

  Widget _buildAssessmentCategoryBadge(
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
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
  String _selectedItemAnalysisAssessment = 'Summative Test 1 (ST1)';

  Widget _buildItemAnalysisTab(List<QuizOrExamModel> quizzes) {
    final Map<String, List<Map<String, dynamic>>> mockItemData = {
      'Summative Test 1 (ST1)': [
        {
          'q': '1',
          'concept': 'Domain of rational function',
          'correct': 8,
          'wrong': 2,
          'percent': '80%',
          'difficulty': 'Easy',
        },
        {
          'q': '2',
          'concept': 'Vertical asymptote properties',
          'correct': 6,
          'wrong': 4,
          'percent': '60%',
          'difficulty': 'Moderate',
        },
        {
          'q': '3',
          'concept': 'Piecewise function evaluation',
          'correct': 7,
          'wrong': 3,
          'percent': '70%',
          'difficulty': 'Moderate',
        },
      ],
      'Summative Test 2 (ST2)': [
        {
          'q': '1',
          'concept': 'Exponential growth modeling',
          'correct': 9,
          'wrong': 1,
          'percent': '90%',
          'difficulty': 'Easy',
        },
        {
          'q': '2',
          'concept': 'Logarithmic properties',
          'correct': 5,
          'wrong': 5,
          'percent': '50%',
          'difficulty': 'Hard',
        },
      ],
      'Term Examination (TE)': [
        {
          'q': '1',
          'concept': 'Comprehensive Functions',
          'correct': 7,
          'wrong': 3,
          'percent': '70%',
          'difficulty': 'Moderate',
        },
        {
          'q': '2',
          'concept': 'Inverse Functions',
          'correct': 8,
          'wrong': 2,
          'percent': '80%',
          'difficulty': 'Easy',
        },
        {
          'q': '3',
          'concept': 'Compound Interest Applications',
          'correct': 4,
          'wrong': 6,
          'percent': '40%',
          'difficulty': 'Hard',
        },
        {
          'q': '4',
          'concept': 'Exponential Equations',
          'correct': 6,
          'wrong': 4,
          'percent': '60%',
          'difficulty': 'Moderate',
        },
      ],
    };

    final currentData =
        mockItemData[_selectedItemAnalysisAssessment] ??
        mockItemData.values.first;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Analysis Dashboard',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Evaluate question difficulty index and student correctness percentages.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedItemAnalysisAssessment,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    items: mockItemData.keys
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        setState(() => _selectedItemAnalysisAssessment = v);
                    },
                  ),
                ),
              ),
            ],
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
                Text(
                  '$_selectedItemAnalysisAssessment - Item Breakdown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(
                    color: AppColors.border,
                    width: 1,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(4),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: [
                        _buildTableHeader('Q #'),
                        _buildTableHeader('Question Concept'),
                        _buildTableHeader('Correct'),
                        _buildTableHeader('Wrong'),
                        _buildTableHeader('% Correct'),
                        _buildTableHeader('Difficulty'),
                      ],
                    ),
                    ...currentData.map((item) {
                      final diffColor = item['difficulty'] == 'Easy'
                          ? AppColors.success
                          : (item['difficulty'] == 'Moderate'
                                ? AppColors.warning
                                : AppColors.error);
                      return TableRow(
                        children: [
                          _buildTableCell(item['q'].toString()),
                          _buildTableCell(item['concept'].toString()),
                          _buildTableCell(
                            item['correct'].toString(),
                            alignment: Alignment.center,
                          ),
                          _buildTableCell(
                            item['wrong'].toString(),
                            alignment: Alignment.center,
                          ),
                          _buildTableCell(
                            item['percent'].toString(),
                            alignment: Alignment.center,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          _buildTableCell(
                            item['difficulty'].toString(),
                            alignment: Alignment.center,
                            textStyle: TextStyle(
                              color: diffColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    Alignment alignment = Alignment.centerLeft,
    TextStyle? textStyle,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.all(12),
      child: Text(text, style: textStyle ?? const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildAssessmentMonitoringTab(List<QuizOrExamModel> quizzes) {
    if (_monitoringAssessmentId == null && quizzes.isNotEmpty) {
      _monitoringAssessmentId = quizzes.first.id;
    }

    final results = MockDatabase.instance.assessmentResults
        .where((r) => r.assessmentId == _monitoringAssessmentId)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assessment Monitoring Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Monitor student progress, completion status, and anti-cheating violations in real-time.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Assessment Selector
          Row(
            children: [
              const Text(
                'Select Assessment: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _monitoringAssessmentId,
                  underline: const SizedBox(),
                  items: quizzes
                      .map(
                        (q) =>
                            DropdownMenuItem(value: q.id, child: Text(q.title)),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _monitoringAssessmentId = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Results Table
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Student',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Submission Time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Duration',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Score',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Violations',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: results.map((res) {
                    final status = res.violationCount == 0
                        ? 'Normal'
                        : res.violationCount == 1
                        ? 'Warning'
                        : res.violationCount == 2
                        ? 'Suspicious'
                        : 'Auto-Submitted';
                    final statusColor = res.violationCount == 0
                        ? AppColors.success
                        : res.violationCount == 1
                        ? AppColors.warning
                        : AppColors.error;

                    return DataRow(
                      onSelectChanged: (_) => _showViolationDetail(res),
                      cells: [
                        DataCell(Text(res.studentName)),
                        DataCell(
                          Text(res.submittedAt.toString().substring(11, 16)),
                        ),
                        DataCell(Text('${res.durationTakenMinutes}m')),
                        DataCell(
                          StatusBadge(
                            text: status,
                            backgroundColor: statusColor.withValues(alpha: 0.1),
                            textColor: statusColor,
                          ),
                        ),
                        DataCell(
                          Text(
                            '${res.scoreEarned.toInt()} / ${res.totalPoints.toInt()}',
                          ),
                        ),
                        DataCell(
                          Text(
                            res.violationCount.toString(),
                            style: TextStyle(
                              color: res.violationCount > 0
                                  ? AppColors.error
                                  : null,
                              fontWeight: res.violationCount > 0
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showViolationDetail(AssessmentResultModel result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Violation History: ${result.studentName}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Violations: ${result.violationCount}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (result.violationLog.isEmpty)
                const Text('No violations recorded for this session.')
              else
                ...result.violationLog.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          '[${v['timestamp'] ?? 'N/A'}]',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(v['type'] ?? 'Violation')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
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

  // --- 18. Gradebook ---
  Widget _buildGradebookTab() {
    final gradeItems = <String, List<Map<String, String>>>{
      'Written Works (WW)': [],
      'Performance Task (PT)': [],
      'Examinations (EX)': [],
    };
    final database = MockDatabase.instance;

    String formatDate(DateTime date) =>
        '${_monthName(date.month)} ${date.day}, ${date.year}';

    for (final activity in database.activities) {
      gradeItems[activity.isRequirement
              ? 'Performance Task (PT)'
              : 'Written Works (WW)']!
          .add({
            'name': activity.title,
            'points': '${activity.maxScore.toStringAsFixed(0)} pts',
            'date': formatDate(activity.dateAssigned),
          });
    }

    for (final assessment in database.quizzesAndExams) {
      if (!assessment.isExam) {
        gradeItems['Written Works (WW)']!.add({
          'name': assessment.title,
          'points': '${assessment.totalPoints.toStringAsFixed(0)} pts',
          'date': formatDate(assessment.scheduleDate),
        });
        continue;
      }

      gradeItems['Examinations (EX)']!.add({
        'header': assessment.id == 'EX3'
            ? 'Term Examination'
            : assessment.title,
        'name': assessment.title,
        'weight': assessment.id == 'EX3' ? '40%' : '30%',
        'points': '${assessment.totalPoints.toStringAsFixed(0)}pts',
        'date': formatDate(assessment.scheduleDate),
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDCE6F5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A1E3A8A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      const Text(
                        'Grading Period:',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildGradebookDropdown(
                        label: '',
                        value: 'Quarter 1',
                        options: const [
                          'Quarter 1',
                          'Quarter 2',
                          'Quarter 3',
                          'Quarter 4',
                        ],
                        width: 120,
                      ),
                      const Text(
                        'Class:',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildGradebookDropdown(
                        label: '',
                        value: 'Grade 11 - Section A - General Mathematics',
                        options: const [
                          'Grade 11 - Section A - General Mathematics',
                          'Grade 11 - Section B - General Mathematics',
                        ],
                        width: 270,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCE6F5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gradebook - Quarter 1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Grade 11 - Section A - General Mathematics',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Grades are automatically computed from grade items:',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Build the grade from written work, performance tasks and exams. ClassRealm computes it based on the weighted components defined below.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_isEditingWeights)
                        _buildGradeWeightEditor()
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildGradebookInfoChip(
                                    'DepEd Order No. 015, s. 2026',
                                    const Color(0xFFE8F8F0),
                                    const Color(0xFF166534),
                                  ),
                                  _buildGradeWeightChip(
                                    'WW',
                                    '${_weightWWCtrl.text}%',
                                  ),
                                  _buildGradeWeightChip(
                                    'PT',
                                    '${_weightPTCtrl.text}%',
                                  ),
                                  _buildGradeWeightChip(
                                    'EX',
                                    '${_weightEXCtrl.text}%',
                                  ),
                                  _buildGradebookInfoChip(
                                    'EX = ST-1:30% + ST-2:30% + EX:40%',
                                    const Color(0xFFF3F0FF),
                                    const Color(0xFF6D28D9),
                                  ),
                                ],
                              ),
                            ),
                            AppSecondaryButton(
                              label: 'Edit Weights',
                              icon: Icons.tune,
                              height: 36,
                              onPressed: () =>
                                  setState(() => _isEditingWeights = true),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...gradeItems.entries.expand(
            (entry) => entry.key == 'Examinations (EX)'
                ? entry.value.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildGradebookSection(
                        item['header'] ?? item['name']!,
                        [item],
                        showItemName: true,
                        sectionWeight: item['weight'],
                      ),
                    ),
                  )
                : [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildGradebookSection(entry.key, entry.value),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradebookFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildGradebookDropdown(
              label: 'Grading Period',
              value: 'Quarter 1',
              options: const [
                'Quarter 1',
                'Quarter 2',
                'Quarter 3',
                'Quarter 4',
              ],
              width: 200,
            ),
            const SizedBox(width: 16),
            _buildGradebookDropdown(
              label: 'Class',
              value: 'Grade 11 - Section A - General Mathematics',
              options: const [
                'Grade 11 - Section A - General Mathematics',
                'Grade 11 - Section B - General Mathematics',
              ],
              width: 380,
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildGradeWeightEditor() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Text(
            'WW',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeightInputField(_weightWWCtrl),
          const SizedBox(width: 6),
          const Text(
            '%',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            'PT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeightInputField(_weightPTCtrl),
          const SizedBox(width: 6),
          const Text(
            '%',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            'EX',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeightInputField(_weightEXCtrl),
          const SizedBox(width: 6),
          const Text(
            '%  =',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '100%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF059669),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _isEditingWeights = false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              final ww = int.tryParse(_weightWWCtrl.text) ?? 0;
              final pt = int.tryParse(_weightPTCtrl.text) ?? 0;
              final ex = int.tryParse(_weightEXCtrl.text) ?? 0;
              final total = ww + pt + ex;

              if (total != 100) {
                AppModals.showErrorDialog(
                  context: context,
                  title: 'Invalid Configuration',
                  message:
                      'The total percentage must equal exactly 100%. Current total: $total%',
                );
                return;
              }

              setState(() => _isEditingWeights = false);
              AppModals.showSuccessDialog(
                context: context,
                title: 'Weights Updated',
                message: 'Gradebook weighting criteria has been updated successfully.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInputField(TextEditingController controller) {
    return Container(
      width: 50,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildGradebookDropdown({
    required String label,
    required String value,
    required List<String> options,
    double width = 350,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label.isEmpty ? null : label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          isDense: true,
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
        onChanged: (_) {},
      ),
    );
  }

  Widget _buildGradebookInfoChip(
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGradebookTabChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGradeWeightChip(String label, String weight) {
    return Chip(
      label: Text('$label  $weight'),
      backgroundColor: const Color(0xFFE0F2FE),
      labelStyle: const TextStyle(
        color: Color(0xFF0369A1),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
    );
  }

  Widget _buildGradebookSection(
    String title,
    List<Map<String, String>> items, {
    bool showItemName = true,
    String? sectionWeight,
  }) {
    final isWrittenWork = title == 'Written Works (WW)';
    final isPerformance = title == 'Performance Task (PT)';
    final headerColor = isWrittenWork
        ? const Color(0xFF1D4ED8)
        : isPerformance
        ? const Color(0xFF059669)
        : const Color(0xFF6D28D9);
    final headerIcon = isWrittenWork
        ? Icons.description_outlined
        : isPerformance
        ? Icons.task_alt
        : Icons.edit_note_outlined;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  headerColor,
                  Color.lerp(headerColor, Colors.black, 0.18) ?? headerColor,
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(headerIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${items.length} ITEM${items.length == 1 ? '' : 'S'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    sectionWeight ?? _gradebookSectionWeight(title),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      showItemName ? item['name']! : item['points']!,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                    label: const Text('View Scores'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1D4ED8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      side: const BorderSide(color: Color(0xFFBFD3F5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      item['points']!,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 90,
                    child: Text(
                      item['date']!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _gradebookSectionWeight(String title) {
    if (title == 'Written Works (WW)') return '20%';
    if (title == 'Performance Task (PT)') return '50%';
    return '30%';
  }

  // --- 9. Grades ---
  Widget _buildGradesTab(List<UserModel> students) {
    var filteredList = students.where((s) {
      if (_gradesSectionFilter == 'All Sections') return true;
      return s.departmentOrSection == _gradesSectionFilter;
    }).toList();

    if (_gradesRankingOrder == 'Highest to Lowest') {
      filteredList.sort(
        (a, b) => MockDatabase.instance
            .quarterlyGradeFor(b.id)
            .compareTo(MockDatabase.instance.quarterlyGradeFor(a.id)),
      );
    } else if (_gradesRankingOrder == 'Lowest to Highest') {
      filteredList.sort(
        (a, b) => MockDatabase.instance
            .quarterlyGradeFor(a.id)
            .compareTo(MockDatabase.instance.quarterlyGradeFor(b.id)),
      );
    }

    String getDescriptor(double grade) {
      if (grade >= 90) return 'Outstanding';
      if (grade >= 85) return 'Very Satisfactory';
      if (grade >= 80) return 'Satisfactory';
      if (grade >= 75) return 'Fairly Satisfactory';
      return 'Did Not Meet Expectations';
    }

    String getRemarks(double grade) {
      return grade >= 75 ? 'Passed' : 'Failed';
    }

    Color getGradeColor(double grade) {
      if (grade >= 90) return AppColors.success;
      if (grade >= 75) return const Color(0xFF1D4ED8);
      return AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quarterly Grades Computation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _buildGradesFilterDropdown(
                    label: 'Section:',
                    value: _gradesSectionFilter,
                    items: ['All Sections', ...MockDatabase.instance.sections],
                    onChanged: (val) =>
                        setState(() => _gradesSectionFilter = val!),
                  ),
                  const SizedBox(width: 16),
                  _buildGradesFilterDropdown(
                    label: 'Ranking:',
                    value: _gradesRankingOrder,
                    items: ['None', 'Highest to Lowest', 'Lowest to Highest'],
                    onChanged: (val) =>
                        setState(() => _gradesRankingOrder = val!),
                  ),
                ],
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
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'STUDENT NAME',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'LRN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              'GRADE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'DESCRIPTOR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              'REMARKS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final s = filteredList[i];
                        final grade = MockDatabase.instance.quarterlyGradeFor(
                          s.id,
                        );
                        final descriptor = getDescriptor(grade);
                        final remarks = getRemarks(grade);
                        final color = getGradeColor(grade);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.accent,
                                      child: Text(
                                        s.fullName.substring(0, 1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      s.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  s.lrn ?? s.studentId ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text(
                                    grade.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      descriptor,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text(
                                    remarks,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradesFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: AppColors.primary),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
                final isPdf = mat.fileName.toLowerCase().endsWith('.pdf');
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPdf
                            ? Icons.picture_as_pdf
                            : Icons.description_outlined,
                        color: isPdf
                            ? AppColors.error
                            : const Color(0xFF2563EB),
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
    final sortedSchedules = List<ScheduleModel>.from(schedules);
    const dayOrder = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    sortedSchedules.sort((a, b) {
      final dayA = dayOrder[a.dayOfWeek] ?? 8;
      final dayB = dayOrder[b.dayOfWeek] ?? 8;
      if (dayA != dayB) return dayA.compareTo(dayB);
      return a.startTime.compareTo(b.startTime);
    });

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
                    'Class Schedule & Timetable',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage your weekly teaching hours and room assignments.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              AppPrimaryButton(
                label: 'Add Schedule Entry',
                icon: Icons.add,
                onPressed: () => _showScheduleEntryDialog(context),
                height: 40,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: sortedSchedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final s = sortedSchedules[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: AppColors.primary,
                          size: 24,
                        ),
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
                                color: AppColors.textPrimary,
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
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
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onPressed: () =>
                                _showScheduleEntryDialog(context, schedule: s),
                            tooltip: 'Edit entry',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppColors.error,
                            ),
                            onPressed: () async {
                              final confirm = await AppModals.showConfirmDialog(
                                context: context,
                                title: 'Delete Schedule Entry',
                                message:
                                    'Are you sure you want to remove this entry for ${s.section}?',
                                confirmLabel: 'Delete',
                                confirmColor: AppColors.error,
                              );
                              if (confirm == true) {
                                setState(() {
                                  MockDatabase.instance.deleteSchedule(s.id);
                                });
                              }
                            },
                            tooltip: 'Delete entry',
                          ),
                        ],
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

  void _showScheduleEntryDialog(
    BuildContext context, {
    ScheduleModel? schedule,
  }) {
    final isEditing = schedule != null;
    final subjectCtrl = TextEditingController(
      text: schedule?.subject ?? 'General Mathematics',
    );
    final roomCtrl = TextEditingController(text: schedule?.room ?? '');
    final startCtrl = TextEditingController(text: schedule?.startTime ?? '');
    final endCtrl = TextEditingController(text: schedule?.endTime ?? '');
    String selectedSection = schedule?.section ?? _classroomSections.first;
    String selectedDay = schedule?.dayOfWeek ?? 'Monday';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(isEditing ? 'Edit Schedule Entry' : 'Add Schedule Entry'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSetupField('SUBJECT', subjectCtrl),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedSection,
                    decoration: const InputDecoration(
                      labelText: 'SECTION',
                      border: OutlineInputBorder(),
                    ),
                    items: _classroomSections
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedSection = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildSetupField('ROOM / VENUE', roomCtrl),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    decoration: const InputDecoration(
                      labelText: 'DAY OF WEEK',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const [
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                            ]
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: (v) => setModalState(() => selectedDay = v!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSetupField('START TIME', startCtrl),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSetupField('END TIME', endCtrl)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            AppPrimaryButton(
              label: isEditing ? 'Update Entry' : 'Add Entry',
              onPressed: () {
                final newSchedule = ScheduleModel(
                  id:
                      schedule?.id ??
                      'sch_${DateTime.now().millisecondsSinceEpoch}',
                  subject: subjectCtrl.text.trim(),
                  section: selectedSection,
                  room: roomCtrl.text.trim(),
                  dayOfWeek: selectedDay,
                  startTime: startCtrl.text.trim(),
                  endTime: endCtrl.text.trim(),
                );
                setState(() {
                  if (isEditing) {
                    MockDatabase.instance.updateSchedule(newSchedule);
                  } else {
                    MockDatabase.instance.addSchedule(newSchedule);
                  }
                });
                Navigator.pop(ctx);
              },
              width: 120,
              height: 40,
            ),
          ],
        ),
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
    final t =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (user) => user.id == 'T001' || user.role == UserRole.teacher,
          orElse: () => const UserModel(
            id: 'T001',
            username: 'teacher',
            fullName: 'Teacher',
            email: 'teacher@classrealm.edu',
            role: UserRole.teacher,
          ),
        );
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
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Username / Faculty ID'),
              subtitle: Text(t.username),
            ),
            const Divider(),
            ListTile(
              leading: Image.asset(
                'lib/school_logo.png',
                width: 24,
                height: 24,
              ),
              title: const Text('School Institution'),
              subtitle: const Text('Eduardo Barretto Senior Integrated School'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science),
              title: const Text('Department / Subject Specialization'),
              subtitle: Text(t.departmentOrSection ?? 'General Mathematics'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Role'),
              subtitle: Text(t.role.name),
            ),
          ],
        ),
      ),
    );
  }
}
