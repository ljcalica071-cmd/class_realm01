import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/auth/screens/login_screen.dart';
import 'package:class_realm/features/auth/screens/first_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserModel lastFirstMi Name Formatting Tests', () {
    test('formats student name as LastName, FirstName M.I. when individual fields are present', () {
      const student = UserModel(
        id: 's-1',
        username: '120000000103',
        fullName: 'Carlos Dela Cruz',
        firstName: 'Carlos',
        middleName: 'Dela',
        lastName: 'Cruz',
        email: '',
        role: UserRole.student,
      );

      expect(student.lastFirstMi, 'Cruz, Carlos D.');
    });

    test('formats student name correctly when middleName has a period or single letter', () {
      const student = UserModel(
        id: 's-2',
        username: '120000000104',
        fullName: 'Bea M. Castro',
        firstName: 'Bea',
        middleName: 'M.',
        lastName: 'Castro',
        email: '',
        role: UserRole.student,
      );

      expect(student.lastFirstMi, 'Castro, Bea M.');
    });

    test('formats student name without middle initial when middleName is empty', () {
      const student = UserModel(
        id: 's-3',
        username: '120000000105',
        fullName: 'Juan Cruz',
        firstName: 'Juan',
        lastName: 'Cruz',
        email: '',
        role: UserRole.student,
      );

      expect(student.lastFirstMi, 'Cruz, Juan');
    });

    test('parses fullName fallback into LastName, FirstName M.I. when individual fields are null', () {
      const student = UserModel(
        id: 's-4',
        username: '120000000106',
        fullName: 'Carlos D. Cruz',
        email: '',
        role: UserRole.student,
      );

      expect(student.lastFirstMi, 'Cruz, Carlos D.');
    });
  });

  group('LoginScreen Autofill & Password Save Configuration Tests', () {
    testWidgets('LoginScreen contains AutofillGroup configured with commit action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump();

      // Find AutofillGroup
      final autofillGroupFinder = find.byType(AutofillGroup);
      expect(autofillGroupFinder, findsOneWidget);

      final autofillGroup = tester.widget<AutofillGroup>(autofillGroupFinder);
      expect(
        autofillGroup.onDisposeAction,
        AutofillContextAction.commit,
        reason: 'AutofillGroup must commit on dispose so platform prompts to save credentials',
      );

      // Verify Email TextField has username and email autofill hints
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      final emailField = tester.widget<TextField>(textFields.at(0));
      expect(
        emailField.autofillHints,
        containsAll([AutofillHints.username, AutofillHints.email]),
      );

      // Verify Password TextField has password autofill hint and secure text input type
      final passwordField = tester.widget<TextField>(textFields.at(1));
      expect(
        passwordField.autofillHints,
        contains(AutofillHints.password),
      );
      expect(
        passwordField.keyboardType,
        TextInputType.text,
        reason: 'Password field must use standard text/password type, not visiblePassword',
      );
      expect(passwordField.obscureText, isTrue);
    });
  });

  group('FirstLoginScreen Autofill & Password Registration Tests', () {
    testWidgets('FirstLoginScreen contains AutofillGroup and newPassword autofillHints', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: FirstLoginScreen(),
        ),
      );
      await tester.pump();

      // Find AutofillGroup
      final autofillGroupFinder = find.byType(AutofillGroup);
      expect(autofillGroupFinder, findsOneWidget);

      final autofillGroup = tester.widget<AutofillGroup>(autofillGroupFinder);
      expect(autofillGroup.onDisposeAction, AutofillContextAction.commit);

      // Find TextFields for password
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Check that at least one TextField has AutofillHints.newPassword
      bool hasNewPasswordHint = false;
      for (final element in textFields.evaluate()) {
        final widget = element.widget as TextField;
        if (widget.autofillHints?.contains(AutofillHints.newPassword) == true) {
          hasNewPasswordHint = true;
          break;
        }
      }

      expect(
        hasNewPasswordHint,
        isTrue,
        reason: 'FirstLoginScreen must offer AutofillHints.newPassword for password creation',
      );
    });
  });
}
