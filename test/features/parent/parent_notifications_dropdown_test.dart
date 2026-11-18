import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/parent/sub_features/communications/widgets/parent_notifications_tab.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/app_fixed_dropdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'ParentNotificationsTab renders AppFixedDropdown for subject filter',
      (tester) async {
    final notifs = <AppNotificationModel>[
      AppNotificationModel(
        id: 'n1',
        title: 'Math Quiz',
        message: 'Quiz tomorrow in General Mathematics',
        recipientId: 'parent-1',
        timestamp: DateTime.now(),
        type: 'academic',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentNotificationsTab(notifications: notifs),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdownFinder = find.byType(AppFixedDropdown<String?>);
    expect(dropdownFinder, findsOneWidget);
    expect(find.text('All Subjects'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // Tap dropdown to open
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Verify it opened without error
    expect(find.text('All Subjects'), findsAtLeastNWidgets(1));
  });
}
