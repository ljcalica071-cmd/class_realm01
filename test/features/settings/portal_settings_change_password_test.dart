import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/shared/widgets/portal_settings_content.dart';

void main() {
  testWidgets('PortalSettingsContent Change Password tile triggers ChangePasswordModal', (tester) async {
    const testUser = UserModel(
      id: 'teacher-123',
      username: 'teacherjuan',
      fullName: 'Teacher Juan',
      email: 'teacher@school.edu.ph',
      role: UserRole.teacher,
    );

    AuthRepository.instance.currentUser = testUser;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PortalSettingsContent(portalLabel: 'Teacher'),
          ),
        ),
      ),
    );

    // Verify "Next Update" badge is gone
    expect(find.text('Next Update'), findsNothing);

    // Tap Change Password tile
    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();

    // Verify ChangePasswordModal opens
    expect(find.text('Current Password'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
  });
}
