import 'package:flutter/material.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/logout_helper.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/activity_submissions_screen.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/features/teacher/widgets/tabs/tabs.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/data/repositories/supabase_teacher_classwork_repository.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/session_activity_tracker.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/routes/app_routes.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({
    super.key,
    this.teacher,
    this.initialSelectedIndex = 0,
  });

  final UserModel? teacher;
  final int initialSelectedIndex;

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late int _selectedIndex = widget.initialSelectedIndex;
  bool _isSidebarExpanded = true;
  final String _selectedClassSection = 'All Sections';
  ActivityModel? _viewingSubmissionsFor;
  bool _isLoading = true;
  List<ActivityModel>? _persistedActivities;
  List<UserModel> _allStudents = [];
  List<UserModel> _parents = [];
  final List<LearningMaterialModel> _materials = [];
  final List<QuizOrExamModel> _quizzesAndExams = [];
  final List<LessonPlanModel> _lessonPlans = [];
  final List<GradingCriteria> _criteria = [
    GradingCriteria(id: 'ww', name: 'Written Works', percentage: 25.0),
    GradingCriteria(id: 'pt', name: 'Performance Tasks', percentage: 50.0),
    GradingCriteria(id: 'qa', name: 'Quarterly Assessment', percentage: 25.0),
  ];
  final List<ExamSubmissionReview> _examReviews = [];

  bool _isGradebookLocked = true;
  DateTime? _lastGradebookCheck;

  String _routeForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.teacherDashboard;
      case 17:
        return AppRoutes.teacherClassroomSetup;
      case 18:
        return AppRoutes.teacherGradebook;
      case 12:
        return AppRoutes.teacherManageStudents;
      case 19:
        return AppRoutes.teacherManageParents;
      case 1:
        return AppRoutes.teacherClasswork;
      case 3:
        return AppRoutes.teacherLessonPlanning;
      case 4:
        return AppRoutes.teacherLearningMaterials;
      case 5:
        return AppRoutes.teacherAttendance;
      case 9:
        return AppRoutes.teacherGrades;
      case 14:
        return AppRoutes.teacherSchedule;
      case 15:
        return AppRoutes.teacherNotifications;
      case 16:
        return AppRoutes.teacherProfile;
      default:
        return AppRoutes.teacherDashboard;
    }
  }

  void _onSelectTab(int index) {
    setState(() => _selectedIndex = index);
    LocalStorageService.saveActiveDashboardTab('teacher', index);
    final route = _routeForIndex(index);
    LocalStorageService.saveLastActiveRoute(route);
    updateBrowserUrl(route);
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
    final currentRoute = _routeForIndex(_selectedIndex);
    LocalStorageService.saveLastActiveRoute(currentRoute);
    updateBrowserUrl(currentRoute);
    _loadData();
    _loadActivities();
    _checkGradebookLockStatus();
  }

  Future<void> _checkGradebookLockStatus() async {
    final user = widget.teacher ?? AuthRepository.instance.currentUser;
    if (user == null) return;
    
    // Debounce to prevent spamming the database
    if (_lastGradebookCheck != null && 
        DateTime.now().difference(_lastGradebookCheck!).inSeconds < 3) {
      return;
    }
    _lastGradebookCheck = DateTime.now();

    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        user.id,
        onlyWithEnrolledStudents: true,
      );
      if (mounted) {
        setState(() {
          _isGradebookLocked = subjects.isEmpty;
        });
      }
    } catch (e) {
      // Ignore errors silently for background checks
    }
  }

  Future<void> _loadActivities() async {
    try {
      final list =
          await SupabaseTeacherClassworkRepository.instance.getActivities();
      if (mounted) {
        setState(() => _persistedActivities = list);
      }
    } catch (_) {
      // Fallback gracefully to mock data if offline or error
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = false);
    }
    final user = widget.teacher ?? AuthRepository.instance.currentUser;
    if (user == null) return;
    try {
      final studentRepo = SupabaseStudentRepository();
      final parentRepo = SupabaseParentRepository();
      final results = await Future.wait([
        studentRepo.getStudentsForTeacher(user.id),
        parentRepo.getParentsForTeacher(user.id),
      ]);
      if (mounted) {
        setState(() {
          _allStudents = results[0];
          _parents = results[1];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
        ),
      );
    }
    final allStudents = _allStudents;
    final parents = _parents;
    final activeStudents = allStudents.where((u) => !u.isArchived).toList();
    final archivedStudents = allStudents.where((u) => u.isArchived).toList();

    final activities = _persistedActivities ?? <ActivityModel>[];
    final quizzesAndExams = _quizzesAndExams;
    final lessonPlans = _lessonPlans;
    final materials = _materials;
    final criteria = _criteria;
    final examReviews = _examReviews;

    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    final sidebar = Material(
      color: theme.colorScheme.surface, // 30% Surface
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isMobile ? 260 : (_isSidebarExpanded ? 260 : 80),
        child: Column(
          children: [
            // Brand Header
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  if (!isMobile && !_isSidebarExpanded)
                    IconButton(
                      icon: Icon(
                        LucideIcons.menu,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () =>
                          setState(() => _isSidebarExpanded = true),
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
                    if (!isMobile)
                      IconButton(
                        icon: Icon(
                          LucideIcons.panelLeftClose,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _isSidebarExpanded = false),
                      ),
                  ],
                ],
              ),
            ),
            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              height: 1,
            ),

            // Grouped Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildNavItem(
                    0,
                    'Dashboard',
                    LucideIcons.layoutDashboard,
                    theme,
                  ),
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
                  _buildNavItem(3, 'Lesson Planning', LucideIcons.brain, theme),
                  _buildNavItem(
                    4,
                    'Learning Materials',
                    LucideIcons.library,
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _buildSectionHeader('MONITORING & EVALUATION', theme),
                  _buildNavItem(
                    5,
                    'Attendance',
                    LucideIcons.checkSquare,
                    theme,
                  ),
                  _buildNavItem(9, 'Grades', LucideIcons.award, theme),
                  const SizedBox(height: 8),
                  _buildSectionHeader('INSIGHTS & MANAGEMENT', theme),
                  _buildNavItem(14, 'My Schedule', LucideIcons.calendar, theme),
                  _buildNavItem(15, 'Notifications', LucideIcons.bell, theme),
                  _buildNavItem(16, 'Profile', LucideIcons.user, theme),
                ],
              ),
            ),

            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              height: 1,
            ),
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
                AppModals.showConfirmationDialog(
                  context: context,
                  title: 'Confirm Logout',
                  message:
                      'Are you sure you want to log out of the teacher portal?',
                  confirmLabel: 'Logout',
                  confirmColor: Colors.redAccent,
                  onConfirm: () async {
                    await LogoutHelper.logout(context);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    final mainContent = Column(
      children: [
        // Top Header Navbar
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface, // 30% Surface
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              if (isMobile)
                Builder(
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      icon: Icon(
                        LucideIcons.menu,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                ),
              _selectedIndex == 0
                  ? const SchoolYearSelectorWidget()
                  : Expanded(
                      child: Text(
                        _getTeacherTitle(_selectedIndex),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              if (!isMobile) const Spacer(),
              if (!isMobile) const SyncStatusBadge(),
              if (!isMobile) const SizedBox(width: 16),
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
                  final newIsDark = !isDark;
                  AppTheme.themeModeNotifier.value = newIsDark
                      ? ThemeMode.dark
                      : ThemeMode.light;
                  final teacher =
                      widget.teacher ?? AuthRepository.instance.currentUser;
                  if (teacher != null) {
                    LocalStorageService.saveUserThemeMode(teacher.id, newIsDark, email: teacher.email);
                  } else {
                    LocalStorageService.saveThemeMode(newIsDark);
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  LucideIcons.bellRing,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => _onSelectTab(15),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                radius: 18,
                child: Text(
                  (widget.teacher ?? AuthRepository.instance.currentUser)
                          ?.firstName
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      (widget.teacher ?? AuthRepository.instance.currentUser)
                          ?.fullName
                          .substring(0, 1)
                          .toUpperCase() ??
                      'T',
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
                    (widget.teacher ?? AuthRepository.instance.currentUser)
                            ?.firstName ??
                        (widget.teacher ?? AuthRepository.instance.currentUser)
                            ?.fullName ??
                        'Teacher',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Faculty',
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
          child: StaggeredEntrance(
            key: ValueKey(_selectedIndex),
            index: 0,
            duration: const Duration(milliseconds: 280),
            child: _buildTeacherBodyContent(
              activeStudents,
              archivedStudents,
              parents,
              activities,
              quizzesAndExams,
              lessonPlans,
              materials,
              criteria,
              examReviews,
            ),
          ),
        ),
      ),
    ],
  );

    return PopScope(
      canPop: false,
      child: SessionActivityTracker(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: isMobile ? sidebar : null,
          body: isMobile
              ? mainContent
              : Row(
                  children: [
                    sidebar,
                    Expanded(child: mainContent),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    if (!_isSidebarExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          height: 1,
        ),
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
      case 8:
        return 'Grading Weights';
      case 9:
        return 'Student Achievement Records';
      case 12:
        return 'Student Directory';
      case 13:
        return 'Institutional Analytics';
      case 14:
        return 'My Teaching Schedule';
      case 15:
        return 'Message & Alert Center';
      case 16:
        return 'Faculty Profile';
      default:
        return 'Teacher Portal';
    }
  }

  Widget _buildNavItem(
    int index,
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = _selectedIndex == index;
    final isGradebook = index == 18;
    final isLocked = isGradebook && _isGradebookLocked;

    final item = Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLocked 
              ? null 
              : () {
                  _onSelectTab(index);
                  if (!isGradebook) {
                    _checkGradebookLockStatus();
                  }
                },
          hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Icon(
                  isLocked ? LucideIcons.lock : icon,
                  color: isLocked
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : (isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                  size: 18,
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isLocked
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : (isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.9,
                                  )),
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

    if (isGradebook) {
      return MouseRegion(
        onEnter: (_) {
          if (_isGradebookLocked) {
             _checkGradebookLockStatus();
          }
        },
        child: isLocked 
            ? Tooltip(
                message: 'Gradebook feature is not yet available. Please add subjects and enroll students in Classroom Setup first.',
                waitDuration: const Duration(milliseconds: 300),
                child: item,
              )
            : item,
      );
    }

    return item;
  }

  Widget _buildTeacherBodyContent(
    List<UserModel> activeStudents,
    List<UserModel> archivedStudents,
    List<UserModel> parents,
    List<ActivityModel> activities,
    List<QuizOrExamModel> quizzesAndExams,
    List<LessonPlanModel> lessonPlans,
    List<LearningMaterialModel> materials,
    List<GradingCriteria> criteria,
    List<ExamSubmissionReview> examReviews,
  ) {
    switch (_selectedIndex) {
      case 0:
        return TeacherDashboardOverviewTab(
          activeStudents: activeStudents,
          quizzesAndExams: quizzesAndExams,
          onNavigateTo: (idx) => _onSelectTab(idx),
          onCreateChooser: () => _showUnifiedCreateChooser(context),
        );
      case 1:
        return _viewingSubmissionsFor == null
            ? TeacherUnifiedAssessmentsTab(
                activities: activities,
                assessments: quizzesAndExams,
                selectedClassSection: _selectedClassSection,
                repository: SupabaseTeacherClassworkRepository.instance,
                onRefresh: _loadActivities,
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
        return const TeacherAttendanceTab();
      case 6:
        return TeacherExamCheckerTab(
          examReviews: examReviews,
          quizzes: quizzesAndExams,
        );
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
          onNavigateTo: (idx) => _onSelectTab(idx),
        );
      case 18:
        return const TeacherGradebookTab();
      case 12:
        return const TeacherStudentManagementTab();
      case 19:
        return TeacherParentManagementTab(parents: parents);
      case 14:
        return const TeacherScheduleTab();
      case 15:
        return const TeacherNotificationsTab();
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
        isPerformanceTask: true,
        repository: SupabaseTeacherClassworkRepository.instance,
        onRequirementCreated: () {
          _loadActivities();
          setState(() {});
        },
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
                  repository: SupabaseTeacherClassworkRepository.instance,
                  onRequirementCreated: () {
                    _loadActivities();
                    setState(() {});
                  },
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
                  isPerformanceTask: true,
                  repository: SupabaseTeacherClassworkRepository.instance,
                  onRequirementCreated: () {
                    _loadActivities();
                    setState(() {});
                  },
                );
              },
              child: const Text('Performance Task'),
            ),
        ],
      ),
    );
  }
}

class SchoolYearSelectorWidget extends StatefulWidget {
  const SchoolYearSelectorWidget({super.key});

  @override
  State<SchoolYearSelectorWidget> createState() =>
      _SchoolYearSelectorWidgetState();
}

class _SchoolYearSelectorWidgetState extends State<SchoolYearSelectorWidget> {
  List<String> _schoolYears = [];
  String _selectedSy = '';

  @override
  void initState() {
    super.initState();
    _initializeSchoolYears();
  }

  void _initializeSchoolYears() {
    final currentYear = DateTime.now().year;
    // System absolute minimum is 2026
    final startYear = 2026;
    // If the current year is somehow before 2026, default to 2026
    int maxYear = currentYear >= 2026 ? currentYear : 2026;

    List<String> years = [];
    for (int y = startYear; y <= maxYear; y++) {
      years.add('$y-${y + 1}');
    }

    setState(() {
      _schoolYears = years;
      _selectedSy = years.last;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          'School Year: ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSy,
              isDense: true,
              padding: EdgeInsets.zero,
              icon: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  LucideIcons.chevronDown,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0,
                color: theme.colorScheme.primary,
              ),
              items: _schoolYears
                  .map(
                    (sy) => DropdownMenuItem(
                      value: sy,
                      child: Text(sy, style: const TextStyle(letterSpacing: 0)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSy = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
