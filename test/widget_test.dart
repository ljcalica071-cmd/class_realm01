import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/main.dart';
import 'package:class_realm/features/teacher/screens/teacher_dashboard_screen.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/teacher_reports_tab.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  testWidgets('ClassRealm smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClassRealmApp());
    expect(find.byType(ClassRealmApp), findsOneWidget);
  });

  testWidgets('teacher portal does not expose mock item analysis', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: TeacherDashboardScreen(
          teacher: const UserModel(
            id: 'test-teacher',
            username: 'teacher',
            fullName: 'Test Teacher',
            email: 'teacher@example.com',
            role: UserRole.teacher,
          ),
          initialSelectedIndex: 8,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Item Analysis'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TeacherReportsTab())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Item Analysis Summary'), findsNothing);
  });
}
