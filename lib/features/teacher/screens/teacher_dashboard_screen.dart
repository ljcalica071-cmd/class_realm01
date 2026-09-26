import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/sync_status_badge.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/activity_submissions_screen.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/features/teacher/widgets/tabs/tabs.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final String _selectedClassSection = 'Section A';
  ActivityModel? _viewingSubmissionsFor;

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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // 60% Background
      body: Row(
        children: [
          // Collapsible Categorized Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarExpanded ? 260 : 80,
            color: theme.colorScheme.surface, // 30% Surface
            child: Column(
              children: [
                // Brand Header
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (!_isSidebarExpanded)
                        IconButton(
                          icon: Icon(LucideIcons.menu, color: theme.colorScheme.onSurface),
                          onPressed: () => setState(() => _isSidebarExpanded = true),
                        )
                      else ...[
                        Image.asset(
                          'assets/branding/school_logo.png',
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CLASSREALM',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'TEACHER PORTAL',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(LucideIcons.panelLeftClose, color: theme.colorScheme.onSurface, size: 20),
                          onPressed: () => setState(() => _isSidebarExpanded = false),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), height: 1),

                // Grouped Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(0, 'Dashboard', LucideIcons.layoutDashboard, theme),
                      const SizedBox(height: 8),
                      _buildSectionHeader('MY CLASSROOM', theme),
                      _buildNavItem(
                        17,
                        'Classroom Setup',
                        LucideIcons.building,
                        theme,
                      ),
                      _buildNavItem(18, 'Gradebook', LucideIcons.bookOpen, theme),
                      _buildNavItem(
                        12,
                        'Manage Students',
                        LucideIcons.users,
                        theme,
                      ),
                      _buildNavItem(
                        19,
                        'Manage Parents',
                        LucideIcons.heartHandshake,
                        theme,
                      ),
                      const SizedBox(height: 8),
                      _buildSectionHeader('TEACHING', theme),
                      _buildNavItem(1, 'Classwork', LucideIcons.fileText, theme),
                      _buildNavItem(
                        3,
                        'Lesson Planning',
                        LucideIcons.brain,
                        theme,
                      ),
                      _buildNavItem(
                        4,
                        'Learning Materials',
                        LucideIcons.library,
                        theme,
                      ),
                      const SizedBox(height: 8),
                      _buildSectionHeader('MONITORING & EVALUATION', theme),
                      _buildNavItem(5, 'Attendance', LucideIcons.checkSquare, theme),
                      _buildNavItem(
                        20,
                        'Assessment Monitoring',
                        LucideIcons.shield,
                        theme,
                      ),
                      _buildNavItem(7, 'Item Analysis', LucideIcons.lineChart, theme),
                      _buildNavItem(9, 'Grades', LucideIcons.award, theme),
                      const SizedBox(height: 8),
                      _buildSectionHeader('INSIGHTS & MANAGEMENT', theme),
                      _buildNavItem(
                        13,
                        'Performance Analytics',
                        LucideIcons.trendingUp,
                        theme,
                      ),
                      _buildNavItem(
                        14,
                        'My Schedule',
                        LucideIcons.calendar,
                        theme,
                      ),
                      _buildNavItem(
                        15,
                        'Notifications',
                        LucideIcons.bell,
                        theme,
                      ),
                      _buildNavItem(16, 'Profile', LucideIcons.user, theme),
                    ],
                  ),
                ),

                Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.logOut, color: Colors.redAccent),
                  title: _isSidebarExpanded
                      ? const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.redAccent,
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
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface, // 30% Surface
                    border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.05))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getTeacherTitle(_selectedIndex),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      const SyncStatusBadge(),
                      const SizedBox(width: 16),
                      // THEME TOGGLE
                      IconButton(
                        icon: Icon(
                          theme.brightness == Brightness.dark
                              ? LucideIcons.sun
                              : LucideIcons.moon,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: () {
                          final isDark = theme.brightness == Brightness.dark;
                          AppTheme.themeModeNotifier.value =
                              isDark ? ThemeMode.light : ThemeMode.dark;
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          LucideIcons.bellRing,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => setState(() => _selectedIndex = 15),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'General Mathematics',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: Colors.transparent, // Inherits Scaffold 60% Background
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

  Widget _buildSectionHeader(String title, ThemeData theme) {
    if (!_isSidebarExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.4,
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

  Widget _buildNavItem(int index, String label, IconData icon, ThemeData theme) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  size: 18,
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
        return TeacherDashboardOverviewTab(
          activeStudents: activeStudents,
          quizzesAndExams: quizzesAndExams,
          schedules: schedules,
          onNavigateTo: (idx) => setState(() => _selectedIndex = idx),
          onCreateChooser: () => _showUnifiedCreateChooser(context),
        );
      case 1:
        return _viewingSubmissionsFor == null
            ? TeacherUnifiedAssessmentsTab(
                activities: activities,
                assessments: quizzesAndExams,
                selectedClassSection: _selectedClassSection,
                onViewSubmissions: (act) =>
                    setState(() => _viewingSubmissionsFor = act),
              )
            : ActivitySubmissionsScreen(
                activity: _viewingSubmissionsFor!,
                embedded: true,
                onBack: () => setState(() => _viewingSubmissionsFor = null),
              );
      case 3:
        return TeacherLessonPlanningTab(
          lessonPlans: lessonPlans,
          onPlanGenerated: () => setState(() {}),
        );
      case 4:
        return TeacherLearningMaterialsTab(materials: materials);
      case 5:
        return TeacherAttendanceTab(attendance: attendance);
      case 6:
        return TeacherExamCheckerTab(
          examReviews: examReviews,
          quizzes: quizzesAndExams,
        );
      case 7:
        return TeacherItemAnalysisTab(quizzes: quizzesAndExams);
      case 8:
        return TeacherGradingSystemTab(criteria: criteria);
      case 9:
        return TeacherGradesTab(students: activeStudents);
      case 10:
        return const TeacherReportsTab();
      case 11:
        return const TeacherAcademicSetupTab();
      case 17:
        return TeacherClassroomSetupTab(
          onNavigateTo: (idx) => setState(() => _selectedIndex = idx),
        );
      case 18:
        return const TeacherGradebookTab();
      case 12:
        return TeacherStudentManagementTab(
          activeStudents: activeStudents,
          archivedStudents: archivedStudents,
        );
      case 19:
        return TeacherParentManagementTab(parents: parents);
      case 13:
        return TeacherPerformanceTab(students: activeStudents);
      case 14:
        return TeacherScheduleTab(schedules: schedules);
      case 15:
        return const TeacherNotificationsTab();
      case 20:
        return TeacherAssessmentMonitoringTab(quizzes: quizzesAndExams);
      case 16:
        return const TeacherProfileTab();
      default:
        return const Center(child: Text('Feature coming up'));
    }
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
}
