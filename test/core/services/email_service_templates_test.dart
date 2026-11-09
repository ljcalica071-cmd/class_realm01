import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/services/email_service.dart';

void main() {
  group('EmailService Semantic Templates', () {
    test('First Login template has correct subject, heading, body, and 5-min expiry', () {
      final html = EmailService.buildFirstLoginOtpHtml('Juan Dela Cruz', '123456');
      
      expect(html, contains('Activate Your Account'));
      expect(html, contains('To complete your first login and activate your account'));
      expect(html, contains('123456'));
      expect(html, contains('This code will expire in 5 minutes.'));
      expect(html, isNot(contains('reset the password')));
    });

    test('Forgot Password template has correct subject, heading, body, and 5-min expiry', () {
      final html = EmailService.buildForgotPasswordOtpHtml('Maria Santos', '654321');
      
      expect(html, contains('Reset Your Password'));
      expect(html, contains('We received a request to reset the password'));
      expect(html, contains('654321'));
      expect(html, contains('This code will expire in 5 minutes.'));
      // Must NOT contain first login phrases!
      expect(html, isNot(contains('first login')));
      expect(html, isNot(contains('activate your account')));
    });

    test('Change Password template has correct subject, heading, body, and 5-min expiry', () {
      final html = EmailService.buildChangePasswordOtpHtml('Pedro Penduko', '789012');
      
      expect(html, contains('Verify Password Change'));
      expect(html, contains('You requested to change your account password'));
      expect(html, contains('789012'));
      expect(html, contains('This code will expire in 5 minutes.'));
      expect(html, contains('If you did not authorize this password change'));
      // Must NOT contain first login or forgot password phrases!
      expect(html, isNot(contains('first login')));
      expect(html, isNot(contains('reset the password')));
    });

    test('All methods successfully simulate sending to @example.com', () async {
      final r1 = await EmailService.instance.sendFirstLoginOtpEmail(
        recipientEmail: 'test@example.com',
        recipientName: 'Juan',
        otpCode: '111222',
      );
      final r2 = await EmailService.instance.sendForgotPasswordOtpEmail(
        recipientEmail: 'test@example.com',
        recipientName: 'Maria',
        otpCode: '333444',
      );
      final r3 = await EmailService.instance.sendChangePasswordOtpEmail(
        recipientEmail: 'test@example.com',
        recipientName: 'Pedro',
        otpCode: '555666',
      );

      expect(r1, isTrue);
      expect(r2, isTrue);
      expect(r3, isTrue);
    });
  });
}
