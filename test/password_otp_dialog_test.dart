import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/shared/widgets/modals/password_otp_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clearing an incorrect OTP allows entering a new code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    var verificationCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PasswordOtpDialog(
                    email: 'student@example.com',
                    initialResendCooldown: 60,
                    initialInputCountdown: 300,
                    onVerify: (code) async {
                      verificationCount++;
                      if (code == '654321') {
                        return const FirstLoginOtpVerification(verified: true);
                      }
                      return const FirstLoginOtpVerification(
                        verified: false,
                        reason: 'Invalid verification code.',
                        attemptsRemaining: 4,
                      );
                    },
                  ),
                ),
                child: const Text('Open OTP'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open OTP'));
    await tester.pump();

    final otpInput = find.byType(TextField);
    await tester.enterText(otpInput, '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(verificationCount, 1);
    expect(find.text('Clear code'), findsOneWidget);
    expect(find.textContaining('Incorrect or expired code.'), findsOneWidget);

    await tester.tap(find.text('Clear code'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(otpInput).controller!.text, isEmpty);

    await tester.enterText(otpInput, '654321');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(verificationCount, 2);
    expect(find.text('Open OTP'), findsOneWidget);
  });

  testWidgets('expired OTP input stays disabled until a new code is sent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    var verificationCount = 0;
    var resendCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PasswordOtpDialog(
                    email: 'student@example.com',
                    initialResendCooldown: 0,
                    initialInputCountdown: 1,
                    onResend: () async {
                      resendCount++;
                      return {
                        'resendCount': resendCount,
                        'resendAfter': 60,
                        'expiresIn': 300,
                      };
                    },
                    onVerify: (code) async {
                      verificationCount++;
                      return const FirstLoginOtpVerification(verified: true);
                    },
                  ),
                ),
                child: const Text('Open OTP'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open OTP'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    final otpInput = find.byType(TextField);
    expect(tester.widget<TextField>(otpInput).enabled, isFalse);
    expect(
      find.textContaining('The verification code has expired'),
      findsOneWidget,
    );

    await tester.tap(find.text('Resend'));
    await tester.pump();
    await tester.pump();

    expect(resendCount, 1);
    expect(tester.widget<TextField>(otpInput).enabled, isTrue);
    expect(tester.widget<TextField>(otpInput).controller!.text, isEmpty);
    expect(find.text('New verification code sent!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('New verification code sent!'), findsNothing);

    await tester.enterText(otpInput, '654321');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(seconds: 3));

    expect(verificationCount, 1);
    expect(find.text('Open OTP'), findsOneWidget);
  });
}
