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
}
