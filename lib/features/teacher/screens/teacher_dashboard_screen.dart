import 'dart:async';
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
import 'package:class_realm/shared/services/in_app_notification_service.dart';
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
  final Set<int> _loadedTabIndices = {};
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
      case 10:
        return AppRoutes.teacherSettings;
      default:
        return AppRoutes.teacherDashboard;
    }
  }

  void _onSelectTab(int index) {
    if (index == 18) {
      TeacherGradebookTab.gradebookRefreshNotifier.value++;
    } else if (index == 1) {
      unawaited(_loadActivities(forceRefresh: true));
    }
    setState(() {
      _selectedIndex = index;
      _loadedTabIndices.add(index);
    });
    LocalStorageService.saveActiveDashboardTab('teacher', index);
    final route = _routeForIndex(index);
    LocalStorageService.saveLastActiveRoute(route);
    if (index == 1) {
      final nav = LocalStorageService.getTeacherClassworkNavState();
      final catIdx = (nav['categoryTabIndex'] as num?)?.toInt() ?? 0;
      final tabParam = catIdx == 0 ? 'ww' : (catIdx == 1 ? 'pt' : 'ex');
      final assessId = nav['activeAssessmentId']?.toString();
      final actId = nav['activeActivityId']?.toString();
      if (assessId != null && assessId.isNotEmpty) {
        updateBrowserUrl('$route?tab=$tabParam&assessment=$assessId');
      } else if (actId != null && actId.isNotEmpty) {
        updateBrowserUrl('$route?tab=$tabParam&activity=$actId');
      } else {
        updateBrowserUrl('$route?tab=$tabParam');
      }
    } else {
      updateBrowserUrl(route);
    }
  }

  void _onClassworkSyncTriggered() {
    if (!mounted) return;
    unawaited(_loadActivities(forceRefresh: true));
  }

  @override
  void initState() {
    super.initState();
    TeacherGradebookTab.classworkSyncNotifier.addListener(
      _onClassworkSyncTriggered,
    );
    SubjectRepository.classworkSyncedNotifier.addListener(
      _onClassworkSyncTriggered,
    );
    final savedTab = LocalStorageService.getActiveDashboardTab('teacher');
    _selectedIndex = (widget.initialSelectedIndex != 0)
        ? widget.initialSelectedIndex
        : (savedTab > 0 ? savedTab : 0);
    _loadedTabIndices.add(_selectedIndex);
    final currentRoute = _routeForIndex(_selectedIndex);
    LocalStorageService.saveLastActiveRoute(currentRoute);
    if (_selectedIndex == 1) {
      final nav = LocalStorageService.getTeacherClassworkNavState();
      final catIdx = (nav['categoryTabIndex'] as num?)?.toInt() ?? 0;
      final tabParam = catIdx == 0 ? 'ww' : (catIdx == 1 ? 'pt' : 'ex');
      final assessId = nav['activeAssessmentId']?.toString();
      final actId = nav['activeActivityId']?.toString();
      if (assessId != null && assessId.isNotEmpty) {
        updateBrowserUrl('$currentRoute?tab=$tabParam&assessment=$assessId');
      } else if (actId != null && actId.isNotEmpty) {
        updateBrowserUrl('$currentRoute?tab=$tabParam&activity=$actId');
      } else {
        updateBrowserUrl('$currentRoute?tab=$tabParam');
      }
    } else {
      updateBrowserUrl(currentRoute);
    }
    _loadData();
    _loadActivities();
    _checkGradebookLockStatus();
    InAppNotificationService.subscribeToAnnouncements(role: 'teacher');
  }

  @override
  void dispose() {
    InAppNotificationService.unsubscribeFromAnnouncements();
    TeacherGradebookTab.classworkSyncNotifier.removeListener(
      _onClassworkSyncTriggered,
    );
    SubjectRepository.classworkSyncedNotifier.removeListener(
      _onClassworkSyncTriggered,
    );
    super.dispose();
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

  Future<void> _loadActivities({bool forceRefresh = false}) async {
    try {
      final teacherId =
          widget.teacher?.id ?? AuthRepository.instance.currentUser?.id;
      final activitiesFuture = SupabaseTeacherClassworkRepository.instance
          .getActivities(teacherId: teacherId, forceRefresh: forceRefresh);
      final assessmentsFuture = SupabaseTeacherClassworkRepository.instance
          .getAssessments(teacherId: teacherId);
      final results = await Future.wait([activitiesFuture, assessmentsFuture]);
      if (mounted) {
        final loadedActs = results[0] as List<ActivityModel>;
        final loadedAssess = results[1] as List<QuizOrExamModel>;
        final navState = LocalStorageService.getTeacherClassworkNavState();
        final savedActId = navState['activeActivityId']?.toString();
        ActivityModel? restoredAct;
        if (savedActId != null && savedActId.isNotEmpty) {
          for (final a in loadedActs) {
            if (a.id == savedActId) {
              restoredAct = a;
              break;
            }
          }
          if (restoredAct == null) {
            for (final q in loadedAssess) {
              if (q.id == savedActId && q.completionMode == 'in_person') {
                restoredAct = ActivityModel(
                  id: q.id,
                  title: q.title,
                  description: q.description,
                  instructions: q.description,
                  subject: q.subject,
                  section: q.section,
                  deadline: q.scheduleDate,
                  maxScore: q.totalPoints,
                  isPublished: q.isPublished,
                  isRequirement: false,
                  subjectOfferingId: q.subjectOfferingId,
                  termNumber: q.termNumber,
                  gradebookColumnIndex: q.gradebookColumnIndex,
                  completionMode: 'in_person',
                  gradingCategory: q.isExam ? 'ex' : 'ww',
                );
                break;
              }
            }
          }
        }
        setState(() {
          _persistedActivities = loadedActs;
          _quizzesAndExams
            ..clear()
            ..addAll(loadedAssess);
          if (_viewingSubmissionsFor == null && restoredAct != null) {
            _viewingSubmissionsFor = restoredAct;
          }
        });
      }
    } catch (_) {
      // Fallback gracefully if offline or error
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
    final isSidebarExpanded = isMobile || _isSidebarExpanded;

    final sidebar = Material(
      color: theme.colorScheme.surface, // 30% Surface
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        decoration: const BoxDecoration(),
        clipBehavior: Clip.hardEdge,
        width: isMobile ? 260 : (_isSidebarExpanded ? 260 : 76),
        child: Column(
          children: [
            // Brand Header
            Container(
              height: 70,
              padding: EdgeInsets.symmetric(
                horizontal: isSidebarExpanded ? 16 : 0,
              ),
              alignment: Alignment.centerLeft,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 180;
                  if (!isSidebarExpanded || (!isMobile && !isWide)) {
                    return Center(
                      child: IconButton(
                        icon: Icon(
                          LucideIcons.panelLeftOpen,
                          color: theme.colorScheme.onSurface,
                          size: 22,
                        ),
                        tooltip: 'Expand Menu',
                        onPressed: () =>
                            setState(() => _isSidebarExpanded = true),
                      ),
                    );
                  }
                  return Row(
                    children: [
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                            Text(
                              'TEACHER PORTAL',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
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
                          tooltip: 'Collapse Menu',
                          onPressed: () =>
                              setState(() => _isSidebarExpanded = false),
                        ),
                    ],
                  );
                },
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
                  _buildNavItem(
                    9,
                    'Performance Analytics',
                    LucideIcons.barChart3,
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _buildSectionHeader('INSIGHTS & MANAGEMENT', theme),
                  _buildNavItem(14, 'My Schedule', LucideIcons.calendar, theme),
                  _buildNavItem(15, 'Notifications', LucideIcons.bell, theme),
                  _buildNavItem(16, 'Profile', LucideIcons.user, theme),
                  _buildNavItem(10, 'Settings', LucideIcons.settings, theme),
                ],
              ),
            ),

            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              height: 1,
            ),
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Tooltip(
                  message: !isSidebarExpanded ? 'Log Out' : '',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Builder(
                    builder: (logoutContext) => InkWell(
                      onTap: () {
                        if (isMobile) {
                          final scaffold = Scaffold.maybeOf(logoutContext);
                          if (scaffold?.isDrawerOpen == true) {
                            scaffold!.closeDrawer();
                          }
                        }
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
                      hoverColor: Colors.redAccent.withValues(alpha: 0.08),
                      child: SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 56,
                              child: Center(
                                child: Icon(
                                  LucideIcons.logOut,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                              ),
                            ),
                            if (isSidebarExpanded)
                              const Expanded(
                                child: Text(
                                  'Log Out',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header Navbar
        Container(
          width: double.infinity,
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
                  ? (isMobile
                      ? const Flexible(child: SchoolYearSelectorWidget())
                      : const SchoolYearSelectorWidget())
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
              if (_selectedIndex == 0) const Spacer(),
              if (!isMobile) const SyncStatusBadge(),
              if (!isMobile) const SizedBox(width: 16),
              // THEME TOGGLE
              IconButton(
                tooltip: theme.brightness == Brightness.dark
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    theme.brightness == Brightness.dark
                        ? LucideIcons.sun
                        : LucideIcons.moon,
                    key: ValueKey<bool>(theme.brightness == Brightness.dark),
                    color: theme.colorScheme.onSurface,
                  ),
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
                    LocalStorageService.saveUserThemeMode(
                      teacher.id,
                      newIsDark,
                      email: teacher.email,
                    );
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
              Builder(
                builder: (context) {
                  final teacherUser =
                      widget.teacher ?? AuthRepository.instance.currentUser;
                  final teacherFullName = [
                    teacherUser?.firstName ?? '',
                    teacherUser?.lastName ?? '',
                  ].where((s) => s.trim().isNotEmpty).join(' ');
                  final displayName = teacherFullName.isNotEmpty
                      ? teacherFullName
                      : (teacherUser?.fullName ?? 'Teacher');

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Dynamic Body View
        Expanded(
          child: Container(
            color: Colors.transparent, // Inherits Scaffold 60% Background
            child: IndexedStack(
              index: (_selectedIndex >= 0 && _selectedIndex < 20)
                  ? _selectedIndex
                  : 0,
              children: List<Widget>.generate(20, (idx) {
                if (!_loadedTabIndices.contains(idx)) {
                  return const SizedBox.shrink();
                }
                return TickerMode(
                  enabled: idx == _selectedIndex,
                  child: RepaintBoundary(
                    child: _buildTeacherBodyContent(
                      idx,
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
                );
              }),
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
    final isMobile = MediaQuery.of(context).size.width < 900;
    if (!isMobile && !_isSidebarExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Divider(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          height: 1,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 12, bottom: 4, right: 16),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
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
        return 'Manage Parents';
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
        return 'Performance Analytics';
      case 12:
        return 'Manage Students';
      case 13:
        return 'Institutional Analytics';
      case 14:
        return 'My Teaching Schedule';
      case 15:
        return 'Message & Alert Center';
      case 16:
        return 'Faculty Profile';
      case 10:
        return 'Settings & Privacy';
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
    final isMobile = MediaQuery.of(context).size.width < 900;
    final isExpanded = isMobile || _isSidebarExpanded;

    final tooltipMessage = isLocked
        ? 'Gradebook feature is not yet available. Please add subjects and enroll students in Classroom Setup first.'
        : (!isExpanded ? label : '');

    final item = Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Tooltip(
          message: tooltipMessage,
          waitDuration: const Duration(milliseconds: 300),
          child: Builder(
            builder: (itemContext) => InkWell(
              onTap: isLocked
                  ? null
                  : () {
                      if (isMobile) {
                        final scaffold = Scaffold.maybeOf(itemContext);
                        if (scaffold?.isDrawerOpen == true) {
                          scaffold!.closeDrawer();
                        }
                      }
                      _onSelectTab(index);
                      if (!isGradebook) {
                        _checkGradebookLockStatus();
                      }
                    },
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: Icon(
                          isLocked ? LucideIcons.lock : icon,
                          color: isLocked
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                              : (isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.75,
                                      )),
                          size: 20,
                        ),
                      ),
                    ),
                    if (isExpanded)
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                  ],
                ),
              ),
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
        child: item,
      );
    }

    return item;
  }

  Widget _buildTeacherBodyContent(
    int tabIndex,
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
    switch (tabIndex) {
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
                onRefresh: () => _loadActivities(forceRefresh: true),
                onViewSubmissions: (act) {
                  LocalStorageService.saveTeacherClassworkNavState(
                    activeActivityId: act.id,
                  );
                  final catParam = act.isRequirement
                      ? 'pt'
                      : (act.gradingCategory == 'ex' ? 'ex' : 'ww');
                  updateBrowserUrl(
                    '${AppRoutes.teacherClasswork}?tab=$catParam&activity=${act.id}',
                  );
                  setState(() => _viewingSubmissionsFor = act);
                },
              )
            : ActivitySubmissionsScreen(
                activity: _viewingSubmissionsFor!,
                embedded: true,
                onBack: () {
                  final act = _viewingSubmissionsFor!;
                  LocalStorageService.saveTeacherClassworkNavState(
                    clearActiveActivity: true,
                  );
                  final catParam = act.isRequirement
                      ? 'pt'
                      : (act.gradingCategory == 'ex' ? 'ex' : 'ww');
                  updateBrowserUrl('${AppRoutes.teacherClasswork}?tab=$catParam');
                  setState(() => _viewingSubmissionsFor = null);
                },
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
        return TeacherGradesTab(
          students: activeStudents,
          onNavigateToGradebook: () => _onSelectTab(18),
        );
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
      case 10:
        return const TeacherSettingsTab();
      default:
        return TeacherDashboardOverviewTab(
          activeStudents: activeStudents,
          quizzesAndExams: quizzesAndExams,
          onNavigateTo: (idx) => _onSelectTab(idx),
          onCreateChooser: () => _showUnifiedCreateChooser(context),
        );
    }
  }

  void _showUnifiedCreateChooser(BuildContext context, [String? category]) {
    if (category == 'EX') {
      CreateAssessmentFlowDialog.show(
        context,
        initialSection: _selectedClassSection,
        initialIsExam: true,
        skipTypeSelection: true,
        onAssessmentCreated: () {
          _loadActivities();
          setState(() {});
        },
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

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
