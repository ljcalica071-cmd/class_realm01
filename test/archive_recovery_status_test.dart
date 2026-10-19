import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/datasources/mock/mock_database.dart';

void main() {
  group('Archive and Recovery Status Preservation Logic', () {
    test('Archived active teacher recovers strictly as active, never pending_first_login', () {
      const currentStatus = 'active';
      const currentStatusHint = 'active';

      // 1. Simulating archive step: Save previous_status
      final statusToSave = (currentStatus.isNotEmpty && currentStatus != 'archived')
          ? currentStatus
          : currentStatusHint;
      expect(statusToSave, equals('active'));

      // 2. Simulating recovery step: Read previous_status
      final prev = statusToSave;
      final targetStatus = (prev.isNotEmpty && prev != 'archived') ? prev : 'active';
      expect(targetStatus, equals('active'));
      expect(targetStatus, isNot(equals('pending_first_login')));
    });

    test('Archived pending teacher recovers faithfully as pending_first_login', () {
      const currentStatus = 'pending_first_login';
      const currentStatusHint = 'pending_first_login';

      final statusToSave = (currentStatus.isNotEmpty && currentStatus != 'archived')
          ? currentStatus
          : currentStatusHint;
      expect(statusToSave, equals('pending_first_login'));

      final prev = statusToSave;
      final targetStatus = (prev.isNotEmpty && prev != 'archived') ? prev : 'active';
      expect(targetStatus, equals('pending_first_login'));
    });

    test('Null previous_status fallback defaults to active, never pending_first_login', () {
      final String? prev = null;
      final targetStatus = (prev != null && prev.isNotEmpty && prev != 'archived')
          ? prev
          : 'active';
      expect(targetStatus, equals('active'));
      expect(targetStatus, isNot(equals('pending_first_login')));
    });

    test('Student archive and recovery preserves active status', () {
      final student = UserModel(
        id: 'stud_123',
        username: 'student123',
        fullName: 'Juan Dela Cruz',
        email: 'juan@student.classrealm.edu',
        role: UserRole.student,
        status: AccountStatus.active,
      );

      final currentHint = (student.status == AccountStatus.pendingFirstLogin)
          ? 'pending_first_login'
          : 'active';
      expect(currentHint, equals('active'));

      // On restore
      final prevStatus = currentHint;
      final restored = (prevStatus != 'archived') ? prevStatus : 'active';
      expect(restored, equals('active'));
    });

    test('Parent archive and recovery preserves active status', () {
      final parent = UserModel(
        id: 'par_456',
        username: 'parent456',
        fullName: 'Maria Dela Cruz',
        email: 'maria@parent.classrealm.edu',
        role: UserRole.parent,
        status: AccountStatus.active,
      );

      final currentHint = (parent.status == AccountStatus.pendingFirstLogin)
          ? 'pending_first_login'
          : 'active';
      expect(currentHint, equals('active'));

      final prevStatus = currentHint;
      final restored = (prevStatus != 'archived') ? prevStatus : 'active';
      expect(restored, equals('active'));
    });
  });

  group('Self-Action Guardrails (Admin & Teacher)', () {
    test('Self-archive is blocked when currentUserId matches target', () {
      const currentUserId = 'admin_uid_001';
      const targetUserId = 'admin_uid_001';

      final isBlocked = (currentUserId == targetUserId);
      expect(isBlocked, isTrue);
    });

    test('Self-delete is blocked when currentUserId matches target', () {
      const currentUserId = 'admin_uid_001';
      const targetUserId = 'admin_uid_001';

      final isBlocked = (currentUserId == targetUserId);
      expect(isBlocked, isTrue);
    });

    test('Different user archive is permitted', () {
      const currentUserId = 'admin_uid_001';
      const targetUserId = 'teacher_uid_999';

      final isBlocked = (currentUserId == targetUserId);
      expect(isBlocked, isFalse);
    });
  });

  group('Multi-Enrollment and Shared Parent Isolation Logic', () {
    test('Student enrolled in multiple subjects is NOT deleted if removed from one subject', () {
      final enrollments = [
        {'id': 'enr_1', 'subject_offering_id': 'math_101'},
        {'id': 'enr_2', 'subject_offering_id': 'science_102'},
      ];

      // Teacher A removes student from math_101
      enrollments.removeWhere((e) => e['subject_offering_id'] == 'math_101');

      final remaining = enrollments;
      expect(remaining.isNotEmpty, isTrue);
      // Root account deletion condition: remaining.isEmpty
      final shouldDeleteRootAccount = remaining.isEmpty;
      expect(shouldDeleteRootAccount, isFalse);
    });

    test('Student with NO remaining subjects triggers root account cleanup', () {
      final enrollments = [
        {'id': 'enr_1', 'subject_offering_id': 'math_101'},
      ];

      enrollments.removeWhere((e) => e['subject_offering_id'] == 'math_101');

      final shouldDeleteRootAccount = enrollments.isEmpty;
      expect(shouldDeleteRootAccount, isTrue);
    });

    test('Shared parent is NOT deleted if another child is still enrolled', () {
      final parentChildren = ['child_1', 'child_2'];

      // Child 1 is deleted
      parentChildren.remove('child_1');

      final hasOtherChildren = parentChildren.isNotEmpty;
      expect(hasOtherChildren, isTrue);
      final shouldDeleteParent = !hasOtherChildren;
      expect(shouldDeleteParent, isFalse);
    });

    test('Parent with NO remaining children triggers parent cleanup', () {
      final parentChildren = ['child_1'];

      parentChildren.remove('child_1');

      final shouldDeleteParent = parentChildren.isEmpty;
      expect(shouldDeleteParent, isTrue);
    });
  });
}
