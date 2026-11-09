import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthRepository Change Password OTP Flow', () {
    test('Throws exception if parent account attempts to request OTP', () async {
      expect(
        () => AuthRepository.instance.sendChangePasswordOtp(
          email: 'maria.santos.cr@classrealm.com',
          recipientName: 'Maria Santos',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Successfully sends OTP, verifies correct code, and rejects wrong code', () async {
      const email = 'teacher@school.edu.ph';
      const name = 'Teacher Test';

      // 1. Send OTP
      final sendResult = await AuthRepository.instance.sendChangePasswordOtp(
        email: email,
        recipientName: name,
      );

      expect(sendResult['sent'], isTrue);
      expect(sendResult['expiresIn'], equals(300));
      expect(sendResult['resendAfter'], equals(60));

      // Get generated code
      final currentCode = AuthRepository.instance.changePasswordOtpCodeForTesting;
      expect(currentCode, isNotNull);
      expect(currentCode!.length, equals(6));

      // 2. Entering wrong code fails
      final wrongCode = currentCode == '111111' ? '222222' : '111111';
      final wrongVerify = await AuthRepository.instance.verifyChangePasswordOtp(wrongCode);
      expect(wrongVerify.verified, isFalse);
      expect(wrongVerify.attemptsRemaining, equals(4));

      // 3. Entering the EXACT correct code succeeds!
      final correctVerify = await AuthRepository.instance.verifyChangePasswordOtp(currentCode);
      expect(correctVerify.verified, isTrue);
      expect(AuthRepository.instance.changePasswordVerifiedForTesting, isTrue);
    });

    test('Expired OTP code returns expired reason', () async {
      AuthRepository.instance.setChangePasswordOtpForTesting(
        code: '123456',
        expiry: DateTime.now().subtract(const Duration(seconds: 1)), // Expired
        email: 'student@school.edu.ph',
      );

      final result = await AuthRepository.instance.verifyChangePasswordOtp('123456');
      expect(result.verified, isFalse);
      expect(result.reason, equals('expired'));
    });

    test('Lockout triggered after 5 failed attempts', () async {
      AuthRepository.instance.setChangePasswordOtpForTesting(
        code: '654321',
        expiry: DateTime.now().add(const Duration(minutes: 5)),
        email: 'student_lockout@school.edu.ph',
        attempts: 4, // 4 already failed
      );

      final result = await AuthRepository.instance.verifyChangePasswordOtp('000000');
      expect(result.verified, isFalse);
      expect(result.reason, equals('locked'));
    });

    test('updatePasswordAfterChangeOtp rejects unverified requests', () async {
      AuthRepository.instance.setChangePasswordOtpForTesting(
        verified: false,
        email: 'student@school.edu.ph',
      );

      final err = await AuthRepository.instance.updatePasswordAfterChangeOtp(
        email: 'student@school.edu.ph',
        currentPassword: 'OldPassword123',
        newPassword: 'NewPassword123',
      );

      expect(err, contains('Unauthorized'));
    });
  });
}
