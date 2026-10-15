import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/utils/validators.dart';

void main() {
  group('Password Complexity Validators', () {
    test('hasMinLength checks for minimum length correctly', () {
      expect(AppValidators.hasMinLength('Pass1'), isFalse);
      expect(AppValidators.hasMinLength('Password1'), isTrue);
    });

    test('hasUppercase checks for uppercase letters correctly', () {
      expect(AppValidators.hasUppercase('password123'), isFalse);
      expect(AppValidators.hasUppercase('Password123'), isTrue);
    });

    test('hasLowercase checks for lowercase letters correctly', () {
      expect(AppValidators.hasLowercase('PASSWORD123'), isFalse);
      expect(AppValidators.hasLowercase('Password123'), isTrue);
    });

    test('hasNumber checks for numeric digits correctly', () {
      expect(AppValidators.hasNumber('Password'), isFalse);
      expect(AppValidators.hasNumber('Password1'), isTrue);
    });

    test('passwordsMatch checks if confirmation matches', () {
      expect(AppValidators.passwordsMatch('Password1', 'Password2'), isFalse);
      expect(AppValidators.passwordsMatch('Password1', ''), isFalse);
      expect(AppValidators.passwordsMatch('Password1', 'Password1'), isTrue);
    });

    test('validatePasswordComplexity aggregates all rules', () {
      final invalid = AppValidators.validatePasswordComplexity(
        password: 'pass',
        confirmPassword: 'pass',
      );
      expect(invalid.hasMinLength, isFalse);
      expect(invalid.hasUpper, isFalse);
      expect(invalid.hasLower, isTrue);
      expect(invalid.hasNumber, isFalse);
      expect(invalid.passwordsMatch, isTrue);
      expect(invalid.isValid, isFalse);

      final valid = AppValidators.validatePasswordComplexity(
        password: 'SecurePass123',
        confirmPassword: 'SecurePass123',
      );
      expect(valid.hasMinLength, isTrue);
      expect(valid.hasUpper, isTrue);
      expect(valid.hasLower, isTrue);
      expect(valid.hasNumber, isTrue);
      expect(valid.passwordsMatch, isTrue);
      expect(valid.isValid, isTrue);
    });
  });
}
