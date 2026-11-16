import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/supabase_notification_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  group('SupabaseNotificationRepository Multi-Tenant Isolation Tests', () {
    final teacherA = UserModel(
      id: 'teacher_001',
      username: 'teacher_alice',
      email: 'teacher.a@school.com',
      fullName: 'Teacher Alice',
      role: UserRole.teacher,
      status: AccountStatus.active,
    );

    final teacherB = UserModel(
      id: 'teacher_002',
      username: 'teacher_bob',
      email: 'teacher.b@school.com',
      fullName: 'Teacher Bob',
      role: UserRole.teacher,
      status: AccountStatus.active,
    );

    final student1 = UserModel(
      id: 'student_101',
      username: 'student_juan',
      email: 'student1@school.com',
      fullName: 'Student Juan',
      role: UserRole.student,
      status: AccountStatus.active,
    );

    final student2 = UserModel(
      id: 'student_102',
      username: 'student_maria',
      email: 'student2@school.com',
      fullName: 'Student Maria',
      role: UserRole.student,
      status: AccountStatus.active,
    );

    final parent1 = UserModel(
      id: 'parent_201',
      username: 'parent_gomez',
      email: 'parent1@school.com',
      fullName: 'Parent Gomez',
      role: UserRole.parent,
      status: AccountStatus.active,
    );

    final parent2 = UserModel(
      id: 'parent_202',
      username: 'parent_santos',
      email: 'parent2@school.com',
      fullName: 'Parent Santos',
      role: UserRole.parent,
      status: AccountStatus.active,
    );

    test('Teacher A cannot see notifications specifically addressed to Teacher B', () {
      final notifForTeacherB = AppNotificationModel(
        id: 'notif_1',
        title: 'Student 2 (3 Absences)',
        message: 'Student 2 has reached 3 absences in Math.',
        timestamp: DateTime.now(),
        type: 'attendance',
        targetAudience: 'teachers',
        recipientId: teacherB.id,
        studentId: student2.id,
        scope: 'individual',
      );

      final visibleToA = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(notifForTeacherB, teacherA);
      final visibleToB = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(notifForTeacherB, teacherB);

      expect(visibleToA, isFalse);
      expect(visibleToB, isTrue);
    });

    test('Student 2 cannot see absence warning specifically scoped to Student 1', () {
      final notifForStudent1 = AppNotificationModel(
        id: 'notif_2',
        title: 'Math (3 Absences)',
        message: 'You have reached 3 absences in Math.',
        timestamp: DateTime.now(),
        type: 'attendance',
        targetAudience: 'students',
        recipientId: student1.id,
        studentId: student1.id,
        scope: 'individual',
      );

      final visibleToStudent1 = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(notifForStudent1, student1);
      final visibleToStudent2 = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(notifForStudent1, student2);

      expect(visibleToStudent1, isTrue);
      expect(visibleToStudent2, isFalse);
    });

    test('Parent 1 sees notification for linked child Student 1, Parent 2 cannot', () {
      final notifForParent1 = AppNotificationModel(
        id: 'notif_3',
        title: 'Student Juan (3 Absences)',
        message: 'Your child Student Juan has missed 3 sessions in Math.',
        timestamp: DateTime.now(),
        type: 'attendance',
        targetAudience: 'parents',
        recipientId: parent1.id,
        studentId: student1.id,
        scope: 'individual',
      );

      final visibleToParent1 = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(
        notifForParent1,
        parent1,
        linkedChildren: [student1],
      );
      final visibleToParent2 = SupabaseNotificationRepository.instance
          .isNotificationVisibleForUser(
        notifForParent1,
        parent2,
        linkedChildren: [student2],
      );

      expect(visibleToParent1, isTrue);
      expect(visibleToParent2, isFalse);
    });

    test('School-wide announcement is visible to all active users matching audience', () {
      final schoolAnnouncement = AppNotificationModel(
        id: 'notif_4',
        title: 'General Assembly',
        message: 'All students and teachers please attend tomorrow.',
        timestamp: DateTime.now(),
        type: 'announcement',
        targetAudience: 'all',
        scope: 'school_wide',
      );

      expect(
        SupabaseNotificationRepository.instance
            .isNotificationVisibleForUser(schoolAnnouncement, teacherA),
        isTrue,
      );
      expect(
        SupabaseNotificationRepository.instance
            .isNotificationVisibleForUser(schoolAnnouncement, student1),
        isTrue,
      );
      expect(
        SupabaseNotificationRepository.instance
            .isNotificationVisibleForUser(schoolAnnouncement, parent1),
        isTrue,
      );
    });
  });
}
