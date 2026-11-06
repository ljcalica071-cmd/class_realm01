import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';
import 'package:class_realm/shared/services/in_app_notification_service.dart';
import 'package:class_realm/shared/widgets/in_app_notification_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    InAppNotificationService.dismiss();
  });

  group('ExpandableNotificationCard Tests', () {
    testWidgets('renders 1st Warning (3 Absences) with Amber badge and Lucide icon', (tester) async {
      final notif = AppNotificationModel(
        id: 'n-3',
        title: '1st Attendance Warning: Dela Cruz, Juan A. (3 Absences)',
        message: 'Student has reached 3 unexcused absences. Please initiate an early check-in.',
        timestamp: DateTime.now(),
        type: 'attendance',
        targetAudience: 'teachers',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandableNotificationCard(notification: notif),
          ),
        ),
      );

      expect(find.text('1st Warning'), findsOneWidget);
      expect(find.text('Dela Cruz, Juan A. (3 Absences)'), findsOneWidget);
    });

    testWidgets('renders 2nd Warning (6 Absences) with Orange badge', (tester) async {
      final notif = AppNotificationModel(
        id: 'n-6',
        title: 'Calica, Ljay H. (6 Absences)',
        message: 'Student has reached 6 recorded absences this term. Conference required.',
        timestamp: DateTime.now(),
        type: 'attendance',
        targetAudience: 'teachers',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandableNotificationCard(notification: notif),
          ),
        ),
      );

      expect(find.text('2nd Warning'), findsOneWidget);
      expect(find.text('Calica, Ljay H. (6 Absences)'), findsOneWidget);
    });

    testWidgets('renders Final Warning (10 Absences) with Red badge', (tester) async {
      final notif = AppNotificationModel(
        id: 'n-10',
        title: 'Mendoza, Karl V. (10 Absences)',
        message: 'Critical SARDO drop-out risk: Student has accumulated 10 absences.',
        timestamp: DateTime.now(),
        type: 'attendance',
        targetAudience: 'teachers',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandableNotificationCard(notification: notif),
          ),
        ),
      );

      expect(find.text('Final Warning'), findsOneWidget);
      expect(find.text('Mendoza, Karl V. (10 Absences)'), findsOneWidget);
    });

    testWidgets('expands and collapses on See more / See less toggle', (tester) async {
      final longMsg = 'This is a long message that extends significantly beyond normal line length '
          'to ensure that the expandable notification card properly clamps to two lines and displays '
          'the See more button cleanly.';
      final notif = AppNotificationModel(
        id: 'n-long',
        title: 'Attendance Advisory',
        message: longMsg,
        timestamp: DateTime.now(),
        type: 'attendance',
        targetAudience: 'teachers',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandableNotificationCard(notification: notif),
          ),
        ),
      );

      expect(find.text('See more'), findsOneWidget);
      await tester.tap(find.text('See more'));
      await tester.pumpAndSettle();

      expect(find.text('See less'), findsOneWidget);
      await tester.tap(find.text('See less'));
      await tester.pumpAndSettle();

      expect(find.text('See more'), findsOneWidget);
    });
  });

  group('InAppNotificationService & Banner Tests', () {
    testWidgets('shows heads-up banner when push notifications are enabled', (tester) async {
      await LocalStorageService.setPushNotificationsEnabled(true);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => InAppNotificationBannerOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );

      InAppNotificationService.showBanner(
        title: '1st Warning: Calica, Ljay H.',
        message: 'Student reached 3 absences.',
        severity: InAppNotificationSeverity.warningLevel1,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('1st Warning: Calica, Ljay H.'), findsOneWidget);
      expect(find.text('Student reached 3 absences.'), findsOneWidget);
      expect(find.text('1st Warning'), findsOneWidget);

      InAppNotificationService.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('ignores banner when push notifications are disabled in settings', (tester) async {
      await LocalStorageService.setPushNotificationsEnabled(false);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => InAppNotificationBannerOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );

      InAppNotificationService.showBanner(
        title: 'Hidden Warning',
        message: 'This should not appear.',
        severity: InAppNotificationSeverity.warningCritical,
      );
      await tester.pumpAndSettle();

      expect(find.text('Hidden Warning'), findsNothing);
    });
  });
}

