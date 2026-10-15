import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/shared/widgets/inputs/password_requirements_checklist.dart';
import 'package:class_realm/core/utils/validators.dart';

void main() {
  group('PasswordRequirementsChecklist Widget Tests', () {
    testWidgets('renders all 4 requirement rows correctly with inactive indicators', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordRequirementsChecklist(
              hasMinLength: false,
              hasUpper: false,
              hasLower: false,
              hasNumber: false,
            ),
          ),
        ),
      );

      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('At least one uppercase letter'), findsOneWidget);
      expect(find.text('At least one lowercase letter'), findsOneWidget);
      expect(find.text('At least one number'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('displays checkmarks when rules are satisfied', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordRequirementsChecklist(
              hasMinLength: true,
              hasUpper: true,
              hasLower: true,
              hasNumber: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);
    });

    testWidgets('factory fromResult correctly parses validation state', (tester) async {
      final result = AppValidators.validatePasswordComplexity(
        password: 'Pass1',
        confirmPassword: 'Pass1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordRequirementsChecklist.fromResult(
              result,
              includeMatch: true,
            ),
          ),
        ),
      );

      expect(find.text('Passwords match'), findsOneWidget);
      // Min length (5 < 8) should be unchecked
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
      // Upper, Lower, Number, Match should be checked (4 total)
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
    });
  });
}
