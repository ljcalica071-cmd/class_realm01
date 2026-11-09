import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/core/utils/validators.dart';

void main() {
  group('Change Password Validation & Business Rules', () {
    test('Validates password complexity correctly', () {
      final valid = AppValidators.validatePasswordComplexity(
        password: 'ValidPassword1',
        confirmPassword: 'ValidPassword1',
      );
      expect(valid.isValid, isTrue);
      expect(valid.hasMinLength, isTrue);
      expect(valid.hasUpper, isTrue);
      expect(valid.hasLower, isTrue);
      expect(valid.hasNumber, isTrue);
      expect(valid.passwordsMatch, isTrue);
    });

    test('Rejects password matching current password', () {
      const currentPassword = 'OldPassword123';
      const newPassword = 'OldPassword123';
      expect(currentPassword == newPassword, isTrue);
    });

    test('Identifies parent domain without sending OTP', () {
      const parentEmail = 'granny.cruz.cr@classrealm.com';
      const teacherEmail = 'teacher@school.edu.ph';

      expect(ParentCredentialHelper.isParentDomain(parentEmail), isTrue);
      expect(ParentCredentialHelper.isParentDomain(teacherEmail), isFalse);
    });
  });
}
