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

  group('Email Validator', () {
    test('accepts valid email addresses', () {
      expect(AppValidators.validateEmail('karen.gonzaga@gmail.com'), isNull);
      expect(AppValidators.validateEmail('teacher@school.edu.ph'), isNull);
      expect(AppValidators.validateEmail('user.name+tag@sub.domain.org'), isNull);
    });

    group('Middle initial validator', () {
      test('allows blank and normalizes valid initials', () {
        expect(AppValidators.validateMiddleInitial(null), isNull);
        expect(AppValidators.validateMiddleInitial(''), isNull);
        expect(AppValidators.validateMiddleInitial('H.'), isNull);
        expect(AppValidators.normalizeMiddleInitial(' h. '), 'H.');
        expect(AppValidators.normalizeMiddleInitial('ñ.'), 'Ñ.');
      });

      test('rejects whitespace-only and non-canonical initials', () {
        const error =
            'Invalid format. Use 1 letter and 1 period only (e.g: H.)';
        for (final value in ['   ', 'H', 'HH.', 'H..', 'H. H', '1.', '.']) {
          expect(AppValidators.validateMiddleInitial(value), error);
        }
        expect(
          () => AppValidators.normalizeMiddleInitial('   '),
          throwsFormatException,
        );
      });
    });

    test('rejects empty or whitespace emails', () {
      expect(AppValidators.validateEmail(null), isNotNull);
      expect(AppValidators.validateEmail(''), isNotNull);
      expect(AppValidators.validateEmail('   '), isNotNull);
    });

    test('rejects emails with spaces or bad format', () {
      expect(AppValidators.validateEmail('user @gmail.com'), isNotNull);
      expect(AppValidators.validateEmail('usergmail.com'), isNotNull);
      expect(AppValidators.validateEmail('user@'), isNotNull);
      expect(AppValidators.validateEmail('@gmail.com'), isNotNull);
    });

    test('rejects truncated domain extension typos like nazhiyuri@gmail.co', () {
      final res = AppValidators.validateEmail('nazhiyuri@gmail.co');
      expect(res, isNotNull);
      expect(res, contains('gmail.com'));
    });

    test('rejects common typo domains like nazhiyuri@gamil.com and nazhiyuri@gmsil.com', () {
      final res1 = AppValidators.validateEmail('nazhiyuri@gamil.com');
      expect(res1, isNotNull);
      expect(res1, contains('gmail.com'));

      final res2 = AppValidators.validateEmail('nazhiyuri@gmsil.com');
      expect(res2, isNotNull);
      expect(res2, contains('gmail.com'));
    });

    test('rejects typos like nazhi@gmails.con and gmails.com', () {
      final res1 = AppValidators.validateEmail('nazhi@gmails.con');
      expect(res1, isNotNull);

      final res2 = AppValidators.validateEmail('nazhi@gmails.com');
      expect(res2, isNotNull);
      expect(res2, contains('gmail.com'));

      final res3 = AppValidators.validateEmail('teacher@school.con');
      expect(res3, isNotNull);
      expect(res3, contains('.com'));
    });

    test('rejects emails exceeding 60 characters total', () {
      final longEmail = 'a' * 51 + '@gmail.com'; // 61 characters
      final res = AppValidators.validateEmail(longEmail);
      expect(res, isNotNull);
      expect(res, contains('cannot exceed 60 characters'));
    });
  });

  group('Domain Deliverability Validator', () {
    test('rejects single-character non-delivering domain like a.com', () async {
      final res = await AppValidators.checkDomainDeliverability('test@a.com');
      expect(res.isDeliverable, isFalse);
      expect(res.error, isNotNull);
      expect(res.error, contains('cannot receive emails'));
    });

    test('rejects invalid email formats', () async {
      final res = await AppValidators.checkDomainDeliverability('invalid-email');
      expect(res.isDeliverable, isFalse);
      expect(res.error, contains('valid email address'));
    });
  });
}
