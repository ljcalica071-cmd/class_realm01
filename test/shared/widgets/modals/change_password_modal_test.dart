import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/modals/change_password_modal.dart';

void main() {
  Future<void> openModal(WidgetTester tester, UserModel user) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ChangePasswordModal.show(context, user: user),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();
  }

  ElevatedButton findSubmitButton(WidgetTester tester, String label) {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byType(ElevatedButton),
    );
    expect(finder, findsOneWidget);
    return tester.widget<ElevatedButton>(finder);
  }

  testWidgets('ChangePasswordModal renders all input fields and requirements checklist', (tester) async {
    const testUser = UserModel(
      id: 'student-123',
      username: 'juandelacruz',
      fullName: 'Juan Dela Cruz',
      email: 'juan@school.edu.ph',
      role: UserRole.student,
    );

    await openModal(tester, testUser);

    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Current Password'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('At least 1 uppercase letter'), findsOneWidget);
    expect(find.text('At least 1 lowercase letter'), findsOneWidget);
    expect(find.text('At least 1 number (0-9)'), findsOneWidget);
    expect(find.text('Passwords match'), findsOneWidget);
  });

  for (final roleCase in const [
    (role: UserRole.admin, label: 'Continue to Verification'),
    (role: UserRole.teacher, label: 'Continue to Verification'),
    (role: UserRole.student, label: 'Continue to Verification'),
    (role: UserRole.parent, label: 'Update Password'),
  ]) {
    testWidgets(
      'disables "${roleCase.label}" for ${roleCase.role.name} until all password requirements are met',
      (tester) async {
        final testUser = UserModel(
          id: '${roleCase.role.name}-123',
          username: '${roleCase.role.name}user',
          fullName: 'Test User',
          email: '${roleCase.role.name}@school.edu.ph',
          role: roleCase.role,
        );

        await openModal(tester, testUser);

        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(3));

        // 1. Initially disabled when empty
        expect(findSubmitButton(tester, roleCase.label).onPressed, isNull);

        // 2. Disabled when < 8 characters even if other rules + match pass (e.g. "Ljay123")
        await tester.enterText(fields.at(0), 'OldPass123');
        await tester.enterText(fields.at(1), 'Ljay123');
        await tester.enterText(fields.at(2), 'Ljay123');
        await tester.pump();
        expect(findSubmitButton(tester, roleCase.label).onPressed, isNull);

        // 3. Disabled when new password does not match confirm password
        await tester.enterText(fields.at(1), 'Ljay1234');
        await tester.enterText(fields.at(2), 'Ljay1235');
        await tester.pump();
        expect(findSubmitButton(tester, roleCase.label).onPressed, isNull);

        // 4. Disabled when new password equals current password
        await tester.enterText(fields.at(1), 'OldPass123');
        await tester.enterText(fields.at(2), 'OldPass123');
        await tester.pump();
        expect(findSubmitButton(tester, roleCase.label).onPressed, isNull);

        // 5. Disabled when current password is empty even if all 5 new password rules are met
        await tester.enterText(fields.at(0), '');
        await tester.enterText(fields.at(1), 'Ljay1234');
        await tester.enterText(fields.at(2), 'Ljay1234');
        await tester.pump();
        expect(findSubmitButton(tester, roleCase.label).onPressed, isNull);

        // 6. Enabled once current password is provided, all 5 requirements are met, and new != current
        await tester.enterText(fields.at(0), 'OldPass123');
        await tester.pump();
        expect(findSubmitButton(tester, roleCase.label).onPressed, isNotNull);
      },
    );
  }
}
