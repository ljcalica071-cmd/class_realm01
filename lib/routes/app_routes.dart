import 'package:flutter/material.dart';
import 'package:class_realm/models/user_model.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String adminAddTeacher = '/admin/add-teacher';
  static const String forgotPassword = '/forgot-password';
  static const String studentFirstLogin = '/student/first-login';
  static const String parentFirstLogin = '/parent/first-login';
  static const String teacherFirstLogin = '/teacher/first-login';

  // Dashboards & Wizards
  static const String academicSetup = '/teacher/academic-setup';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminBroadcasts = '/admin/broadcasts';
  static const String adminTeacherManagement = '/admin/teacher-management';
  static const String adminActivityAnalytics = '/admin/activity-analytics';
  static const String adminProfile = '/admin/profile';
  static const String teacherDashboard = '/teacher/dashboard';
  static const String teacherClassroomSetup = '/teacher/classroom-setup';
  static const String teacherGradebook = '/teacher/gradebook';
  static const String teacherManageStudents = '/teacher/manage-students';
  static const String teacherManageParents = '/teacher/manage-parents';
  static const String teacherClasswork = '/teacher/classwork';
  static const String teacherLessonPlanning = '/teacher/lesson-planning';
  static const String teacherLearningMaterials = '/teacher/learning-materials';
  static const String teacherAttendance = '/teacher/attendance';
  static const String teacherGrades = '/teacher/grades';
  static const String teacherSchedule = '/teacher/schedule';
  static const String teacherNotifications = '/teacher/notifications';
  static const String teacherProfile = '/teacher/profile';
  static const String teacherSettings = '/teacher/settings';

  // Student Sub-Routes
  static const String studentHome = '/student/home';
  static const String studentClasswork = '/student/classwork';
  static const String studentAlerts = '/student/alerts';
  static const String studentProfile = '/student/profile';
  static const String studentAttendance = '/student/attendance';
  static const String studentSchedule = '/student/schedule';
  static const String studentMaterials = '/student/materials';
  static const String studentGrades = '/student/grades';
  static const String studentPerformance = '/student/performance';

  // Parent Sub-Routes
  static const String parentHome = '/parent/home';
  static const String parentAttendance = '/parent/attendance';
  static const String parentSchedule = '/parent/schedule';
  static const String parentAlerts = '/parent/alerts';
  static const String parentProfile = '/parent/profile';
  static const String parentGrades = '/parent/grades';

  static String getFirstLoginRouteForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminDashboard;
      case UserRole.teacher:
        return teacherFirstLogin;
      case UserRole.student:
        return studentFirstLogin;
      case UserRole.parent:
        return parentFirstLogin;
    }
  }

  static String getDashboardRouteForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminDashboard;
      case UserRole.teacher:
        return teacherDashboard;
      case UserRole.student:
        return studentHome;
      case UserRole.parent:
        return parentHome;
    }
  }

  /// Normalizes a route path by stripping query parameters, hash fragments, and trailing slashes.
  static String normalizeRoutePath(String rawPath) {
    var clean = rawPath.split('?').first.split('#').first.trim();
    if (clean.length > 1 && clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean.isEmpty ? '/' : clean;
  }

  /// Strictly validates whether [route] is permitted for a user with [role] and [status].
  /// Enforces horizontal & vertical role isolation:
  /// - Admin can ONLY access `/admin/*` routes.
  /// - Teacher can ONLY access `/teacher/*` routes.
  /// - Student can ONLY access `/student/*` routes.
  /// - Parent can ONLY access `/parent/*` routes.
  /// - Accounts in `pendingFirstLogin` or `pending` status can ONLY access their role's first-login route.
  static bool isRouteAllowedForRole(
    String route,
    UserRole role, {
    AccountStatus status = AccountStatus.active,
    bool isArchived = false,
  }) {
    if (isArchived ||
        status == AccountStatus.archived ||
        status == AccountStatus.deactivated ||
        status == AccountStatus.rejected) {
      return false;
    }

    final clean = normalizeRoutePath(route);
    if (clean.isEmpty ||
        clean == '/' ||
        clean == login ||
        clean == splash ||
        clean == forgotPassword) {
      return false;
    }

    final isFirstLoginPending =
        status == AccountStatus.pendingFirstLogin ||
        status == AccountStatus.pending;

    if (isFirstLoginPending) {
      return switch (role) {
        UserRole.admin => false,
        UserRole.teacher =>
          clean == teacherFirstLogin || clean == '/teacher/first_login',
        UserRole.student =>
          clean == studentFirstLogin || clean == '/student/first_login',
        UserRole.parent =>
          clean == parentFirstLogin || clean == '/parent/first_login',
      };
    }

    // Active users cannot visit first-login setup screens or other roles' routes
    return switch (role) {
      UserRole.admin => const {
        adminDashboard,
        adminBroadcasts,
        adminTeacherManagement,
        adminAddTeacher,
        adminActivityAnalytics,
        adminProfile,
      }.contains(clean),
      UserRole.teacher => const {
        academicSetup,
        teacherDashboard,
        teacherClassroomSetup,
        teacherGradebook,
        teacherManageStudents,
        teacherManageParents,
        teacherClasswork,
        teacherLessonPlanning,
        teacherLearningMaterials,
        teacherAttendance,
        teacherGrades,
        teacherSchedule,
        teacherNotifications,
        teacherProfile,
        teacherSettings,
      }.contains(clean),
      UserRole.student => const {
        studentHome,
        studentClasswork,
        studentAlerts,
        studentProfile,
        studentAttendance,
        studentSchedule,
        studentMaterials,
        studentGrades,
        studentPerformance,
      }.contains(clean),
      UserRole.parent => const {
        parentHome,
        parentAttendance,
        parentSchedule,
        parentAlerts,
        parentProfile,
        parentGrades,
      }.contains(clean),
    };
  }

  /// Resolves a safe, role-isolated route for [user]. If [candidateRoute] belongs to
  /// another role or is invalid for the user's current status, returns the user's
  /// legitimate dashboard (or first-login route).
  static String resolveSafeRouteForUser(
    UserModel user, {
    String? candidateRoute,
    String? fallbackSavedRoute,
  }) {
    if (user.isArchived ||
        user.status == AccountStatus.archived ||
        user.status == AccountStatus.deactivated ||
        user.status == AccountStatus.rejected) {
      return login;
    }

    if (user.status == AccountStatus.pendingFirstLogin ||
        user.status == AccountStatus.pending) {
      return getFirstLoginRouteForRole(user.role);
    }

    if (candidateRoute != null &&
        candidateRoute.isNotEmpty &&
        isRouteAllowedForRole(
          candidateRoute,
          user.role,
          status: user.status,
          isArchived: user.isArchived,
        )) {
      return normalizeRoutePath(candidateRoute);
    }

    if (fallbackSavedRoute != null &&
        fallbackSavedRoute.isNotEmpty &&
        isRouteAllowedForRole(
          fallbackSavedRoute,
          user.role,
          status: user.status,
          isArchived: user.isArchived,
        )) {
      return normalizeRoutePath(fallbackSavedRoute);
    }

    return getDashboardRouteForRole(user.role);
  }
}
