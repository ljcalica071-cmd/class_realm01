import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/modals/change_password_modal.dart';

void main() {
  testWidgets('ChangePasswordModal renders all input fields and requirements checklist', (tester) async {
    const testUser = UserModel(
      id: 'student-123',
      username: 'juandelacruz',
      fullName: 'Juan Dela Cruz',
      email: 'juan@school.edu.ph',
      role: UserRole.student,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ChangePasswordModal.show(context, user: testUser),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

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
}
