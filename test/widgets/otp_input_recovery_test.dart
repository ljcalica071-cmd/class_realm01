import 'dart:async';

import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/admin/sub_features/user_management/widgets/admin_add_teacher_dialog.dart';
import 'package:class_realm/shared/widgets/modals/password_otp_dialog.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  group('OTP Input Recovery After Failed Verification', () {
    testWidgets(
      'PasswordOtpDialog keeps TextInputConnection alive after wrong OTP and accepts immediate re-typing & box taps',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final submittedCodes = <String>[];
        bool? dialogResult;
        Completer<FirstLoginOtpVerification>? pendingVerify;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showDialog<bool>(
                      context: context,
                      builder: (_) => PasswordOtpDialog(
                        email: 'teacher@test.edu',
                        onVerify: (code) {
                          submittedCodes.add(code);
                          pendingVerify =
                              Completer<FirstLoginOtpVerification>();
                          return pendingVerify!.future;
                        },
                      ),
                    );
                  },
                  child: const Text('Open OTP'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open OTP'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 1. Type wrong 6-digit OTP directly through platform TextInputConnection
        tester.testTextInput.enterText('111111');
        await tester.pump();

        expect(submittedCodes, ['111111']);

        // While verification is in-flight, TextField stays enabled & attached (inputFormatter blocks stray edits)
        final inFlightTextField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(inFlightTextField.enabled, isTrue);
        expect(inFlightTextField.readOnly, isFalse);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // Stray typing while verifying is ignored
        tester.testTextInput.enterText('999999');
        await tester.pump();
        expect(inFlightTextField.controller!.text, '111111');

        // Complete verification with failure
        pendingVerify!.complete(
          const FirstLoginOtpVerification(
            verified: false,
            attemptsRemaining: 4,
            reason: 'invalid_code',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Error is shown inline, field is cleared with valid collapsed selection at 0, readOnly is false
        expect(
          find.text('Incorrect or expired code. 4 attempts remaining.'),
          findsOneWidget,
        );
        final recoveredTextField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(recoveredTextField.enabled, isTrue);
        expect(recoveredTextField.readOnly, isFalse);
        expect(recoveredTextField.controller!.text, isEmpty);
        expect(
          recoveredTextField.controller!.selection,
          const TextSelection.collapsed(offset: 0),
        );
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 2. Even when FocusNode ALREADY hasFocus == true, tapping Box 1 must invoke
        // EditableTextState.requestKeyboard() -> TextInput.show (not no-op!)
        expect(recoveredTextField.focusNode!.hasFocus, isTrue);
        final logStart = tester.testTextInput.log.length;
        final firstDigitBox = find
            .descendant(
              of: find.byType(TextFieldTapRegion).first,
              matching: find.byType(GestureDetector),
            )
            .first;
        await tester.tap(firstDigitBox);
        await tester.pump();

        final recentCalls = tester.testTextInput.log
            .sublist(logStart)
            .map((c) => c.method)
            .toList();
        expect(recentCalls, contains('TextInput.show'));

        // 3. Immediately type the right 6-digit OTP via hardware/platform keyboard
        // WITHOUT re-opening or navigating back!
        tester.testTextInput.enterText('654321');
        await tester.pump();

        expect(submittedCodes, ['111111', '654321']);
        pendingVerify!.complete(
          const FirstLoginOtpVerification(verified: true),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(dialogResult, isTrue);
      },
    );

    testWidgets(
      'AdminAddTeacherDialog Step 2 recovers immediately after wrong OTP without clicking Back',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final verifiedCodes = <String>[];
        Completer<Map<String, dynamic>>? pendingVerify;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminAddTeacherDialog(
                onSendVerification: ({
                  required email,
                  required firstName,
                  middleName,
                  required lastName,
                  required gender,
                  required birthday,
                  required isResend,
                }) async {
                  return {
                    'expiresAt': DateTime.now()
                        .add(const Duration(minutes: 5))
                        .toIso8601String(),
                    'remainingCooldownSeconds': 60,
                    'remainingOtpSeconds': 300,
                    'failedAttempts': 0,
                  };
                },
                onVerifyOtp: ({required email, required code}) {
                  verifiedCodes.add(code);
                  pendingVerify = Completer<Map<String, dynamic>>();
                  return pendingVerify!.future;
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Fill Step 1 teacher details
        final textFormFields = find.byType(TextFormField);
        await tester.enterText(textFormFields.at(0), 'Karen');
        await tester.enterText(textFormFields.at(1), 'H');
        await tester.enterText(textFormFields.at(2), 'Gonzaga');

        // Select Gender = Female
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Female').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Select Birthdate on both FormFieldState<DateTime> and onDateSelected callback
        final birthDate = DateTime(1995, 5, 15);
        tester
            .state<FormFieldState<DateTime>>(find.byType(AppDatePickerField))
            .didChange(birthDate);
        final datePicker = tester.widget<AppDatePickerField>(
          find.byType(AppDatePickerField),
        );
        datePicker.onDateSelected!(birthDate);
        await tester.pump();

        // Enter Email (last TextFormField on Step 1)
        await tester.enterText(
          find.byType(TextFormField).last,
          'iammyname600@gmail.com',
        );
        await tester.pump();

        // Submit Step 1 -> transition to Step 2 (Verify Email OTP)
        await tester.ensureVisible(find.text('Send OTP Code'));
        await tester.pump();
        await tester.tap(find.text('Send OTP Code'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Verify Email OTP'), findsOneWidget);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 1. Type wrong OTP (504940) via platform keyboard WITHOUT tapping boxes
        tester.testTextInput.enterText('504940');
        await tester.pump();

        expect(verifiedCodes, ['504940']);

        // During verification, TextField remains enabled & TextInputConnection stays alive
        final otpFieldDuringVerify = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(otpFieldDuringVerify.enabled, isTrue);
        expect(otpFieldDuringVerify.readOnly, isFalse);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // Fail verification with AdminTeacherException (simulating wrong OTP)
        pendingVerify!.completeError(
          AdminTeacherException(
            'Incorrect verification code. 2 attempts remaining.',
            failedAttempts: 3,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text('Incorrect verification code. 2 attempts remaining.'),
          findsOneWidget,
        );

        final otpFieldAfterError = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(otpFieldAfterError.enabled, isTrue);
        expect(otpFieldAfterError.readOnly, isFalse);
        expect(otpFieldAfterError.controller!.text, isEmpty);
        expect(
          otpFieldAfterError.controller!.selection,
          const TextSelection.collapsed(offset: 0),
        );
        expect(otpFieldAfterError.focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 2. Tapping Box 0 while already focused MUST still invoke TextInput.show!
        final logStart = tester.testTextInput.log.length;
        final box0 = find
            .descendant(
              of: find.byType(TextFieldTapRegion).first,
              matching: find.byType(GestureDetector),
            )
            .first;
        await tester.tap(box0);
        await tester.pump();
        expect(
          tester.testTextInput.log.sublist(logStart).map((c) => c.method),
          contains('TextInput.show'),
        );

        // 3. Immediately type the valid 6-digit OTP (264002) WITHOUT clicking Back!
        tester.testTextInput.enterText('264002');
        await tester.pump();

        expect(verifiedCodes, ['504940', '264002']);

        pendingVerify!.complete({'email': 'iammyname600@gmail.com'});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Teacher Account Created Successfully!'),
          findsOneWidget,
        );
      },
    );
  });
}

