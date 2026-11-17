import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';

void main() {
  group('Notification Isolation & At-Risk Grade Alerts Tests', () {
    late UserModel studentA;
    late UserModel studentB;
    late UserModel parentA;
    late UserModel parentB;

    setUp(() {
      studentA = UserModel(
        id: 'student-A',
        email: 'studentA@school.edu',
        username: 'studentA',
        fullName: 'Juan Dela Cruz',
        role: UserRole.student,
        status: AccountStatus.active,
        firstName: 'Juan',
        lastName: 'Dela Cruz',
      );

      studentB = UserModel(
        id: 'student-B',
        email: 'studentB@school.edu',
        username: 'studentB',
        fullName: 'Maria Santos',
        role: UserRole.student,
        status: AccountStatus.active,
        firstName: 'Maria',
        lastName: 'Santos',
      );

      parentA = UserModel(
        id: 'parent-A',
        email: 'parentA@family.edu',
        username: 'parentA',
        fullName: 'Pedro Dela Cruz',
        role: UserRole.parent,
        status: AccountStatus.active,
        firstName: 'Pedro',
        lastName: 'Dela Cruz',
      );

      parentB = UserModel(
        id: 'parent-B',
        email: 'parentB@family.edu',
        username: 'parentB',
        fullName: 'Ana Santos',
        role: UserRole.parent,
        status: AccountStatus.active,
        firstName: 'Ana',
        lastName: 'Santos',
      );
    });

    test('Class suspension is strictly visible only to enrolled students', () {
      final notif = AppNotificationModel(
        id: 'notif-susp-1',
        title: 'Class Suspended: Typhoon in General Mathematics (STEM-11A)',
        message: 'Classes and RFID attendance are suspended on Nov 18 (Typhoon) for General Mathematics (STEM-11A). You are excused for this session.',
        type: 'announcement',
        targetAudience: 'students',
        isArchived: false,
        timestamp: DateTime.now(),
        scope: 'class',
        subjectOfferingId: 'offering-math-1',
      );

      // Student A is enrolled in General Mathematics
      final visibleStudentA = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(
            notif,
            studentA,
            handledOrEnrolledSubjects: ['General Mathematics'],
          );
      expect(visibleStudentA, isTrue, reason: 'Enrolled student must see the class suspension.');

      // Student B is only enrolled in English 10
      final visibleStudentB = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(
            notif,
            studentB,
            handledOrEnrolledSubjects: ['English 10'],
          );
      expect(visibleStudentB, isFalse, reason: 'Unenrolled student must NEVER see another class suspension.');
    });

    test('Parent receives suspension notice ONLY for classes their linked child is enrolled in', () {
      final notif = AppNotificationModel(
        id: 'notif-susp-parent-1',
        title: 'Class Suspension Notice: General Mathematics (STEM-11A)',
        message: 'Notice for Parents/Guardians: Classes and RFID attendance for your child in General Mathematics (STEM-11A) are suspended on Nov 18 (Typhoon). Enrolled learners are excused for this session.',
        type: 'announcement',
        targetAudience: 'parents',
        isArchived: false,
        timestamp: DateTime.now(),
        scope: 'class',
        subjectOfferingId: 'offering-math-1',
      );

      // Parent A is linked to Student A (enrolled in General Mathematics)
      final visibleParentA = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(
            notif,
            parentA,
            handledOrEnrolledSubjects: ['General Mathematics'],
            linkedChildren: [studentA],
          );
      expect(visibleParentA, isTrue, reason: 'Linked parent must receive suspension notice for child class.');

      // Parent B is linked to Student B (enrolled only in Science 9)
      final visibleParentB = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(
            notif,
            parentB,
            handledOrEnrolledSubjects: ['Science 9'],
            linkedChildren: [studentB],
          );
      expect(visibleParentB, isFalse, reason: 'Unlinked parent must NEVER receive another class suspension notice.');
    });

    test('At-risk grade alert (<= 74) is delivered to failing student and linked parent, never to others', () {
      // Failing Student Alert (Term Grade: no section, no literal threshold tag)
      final studentGradeAlert = AppNotificationModel(
        id: 'notif-grade-s1',
        title: 'Academic Grade Alert: General Mathematics - Term 1',
        message: 'Your official grade for Term 1 in General Mathematics is 72. Please coordinate with your teacher for academic remediation and intervention.',
        type: 'grade',
        targetAudience: 'students',
        recipientId: 'student-A',
        studentId: 'student-A',
        isArchived: false,
        timestamp: DateTime.now(),
        scope: 'class',
        subjectOfferingId: 'offering-math-1',
      );

      // Student A sees their own alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          studentGradeAlert,
          studentA,
          handledOrEnrolledSubjects: ['General Mathematics'],
        ),
        isTrue,
      );

      // Student B must NEVER see Student A's grade alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          studentGradeAlert,
          studentB,
          handledOrEnrolledSubjects: ['General Mathematics'],
        ),
        isFalse,
      );

      // Parent Grade Alert with parent-tailored copy
      final parentGradeAlert = AppNotificationModel(
        id: 'notif-grade-p1',
        title: 'Academic Alert: Dela Cruz, Juan (72 in General Mathematics - Term 1)',
        message: 'Dear Parent/Guardian, your child Dela Cruz, Juan received an official grade of 72 for Term 1 in General Mathematics (STEM-11A). Please coordinate with the teacher for remediation support.',
        type: 'grade',
        targetAudience: 'parents',
        recipientId: 'parent-A',
        studentId: 'student-A',
        isArchived: false,
        timestamp: DateTime.now(),
        scope: 'class',
        subjectOfferingId: 'offering-math-1',
      );

      // Parent A (linked to Student A) sees the alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          parentGradeAlert,
          parentA,
          handledOrEnrolledSubjects: ['General Mathematics'],
          linkedChildren: [studentA],
        ),
        isTrue,
      );

      // Parent B (linked to Student B) must NEVER see Student A's alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          parentGradeAlert,
          parentB,
          handledOrEnrolledSubjects: ['General Mathematics'],
          linkedChildren: [studentB],
        ),
        isFalse,
      );
    });

    test('Final grade alert (<= 74) triggers separate Final Grade copy for student and parent', () {
      // Failing Student Alert (Final Grade: no section, no literal threshold tag)
      final finalGradeStudentAlert = AppNotificationModel(
        id: 'notif-final-grade-s1',
        title: 'Academic Final Grade Alert: General Mathematics',
        message: 'Your official Final Grade in General Mathematics is 74. Please coordinate with your teacher immediately regarding academic remediation and course completion.',
        type: 'grade',
        targetAudience: 'students',
        recipientId: 'student-A',
        studentId: 'student-A',
        isArchived: false,
        timestamp: DateTime.now(),
        scope: 'class',
        subjectOfferingId: 'offering-math-1',
      );

      final finalGradeParentAlert = AppNotificationModel(
        id: 'notif-final-grade-p1',
        title: 'Academic Alert: Dela Cruz, Juan (74 Final Grade in General Mathematics)',
        message: 'Dear Parent/Guardian, your child Dela Cruz, Juan received an official Final Grade of 74 in General Mathematics (STEM-11A). Please coordinate with the teacher immediately to arrange academic intervention and remediation.',
        type: 'grade',
        targetAudience: 'parents',
        recipientId: 'parent-A',
        studentId: 'student-A',
        isArchived: false,
        timestamp: DateTime.now(),
        scope: 'class',
        subjectOfferingId: 'offering-math-1',
      );

      // Student A sees their Final Grade alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          finalGradeStudentAlert,
          studentA,
          handledOrEnrolledSubjects: ['General Mathematics'],
        ),
        isTrue,
      );

      // Student B cannot see Student A's Final Grade alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          finalGradeStudentAlert,
          studentB,
          handledOrEnrolledSubjects: ['General Mathematics'],
        ),
        isFalse,
      );

      // Parent A sees child Final Grade alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          finalGradeParentAlert,
          parentA,
          handledOrEnrolledSubjects: ['General Mathematics'],
          linkedChildren: [studentA],
        ),
        isTrue,
      );

      // Parent B cannot see Student A's Final Grade alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          finalGradeParentAlert,
          parentB,
          handledOrEnrolledSubjects: ['General Mathematics'],
          linkedChildren: [studentB],
        ),
        isFalse,
      );
    });

    test('Attendance absence warning (3 absences) contains parent copy and isolates between parents', () {
      final parentAbsenceWarning = AppNotificationModel(
        id: 'notif-abs-3-p',
        title: 'Dela Cruz, Juan (Attendance Alert: 3 Absences)',
        message: 'Dear Parent/Guardian, your child Dela Cruz, Juan has recorded 3 absences in General Mathematics (STEM-11A). Please assist in ensuring regular attendance and coordinate with the subject teacher if excuse documentation is needed.',
        type: 'attendance',
        targetAudience: 'parents',
        studentId: 'student-A',
        isArchived: false,
        timestamp: DateTime.now(),
        scope: 'class',
        subjectOfferingId: 'offering-math-1',
      );

      // Parent A receives notice for their child Juan
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          parentAbsenceWarning,
          parentA,
          handledOrEnrolledSubjects: ['General Mathematics'],
          linkedChildren: [studentA],
        ),
        isTrue,
      );

      // Parent B must NEVER see Juan's absence alert
      expect(
        SupabaseNotificationRepository.instance.isNotificationVisibleForUser(
          parentAbsenceWarning,
          parentB,
          handledOrEnrolledSubjects: ['General Mathematics'],
          linkedChildren: [studentB],
        ),
        isFalse,
      );
    });
  });
}
