import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/shared/widgets/modals/password_otp_dialog.dart';

void main() {
  group('PasswordOtpDialog Responsive & Overflow Tests', () {
    testWidgets('renders cleanly on narrow 360px mobile view with zero overflow', (
      tester,
    ) async {
      // Set surface size to typical narrow mobile screen (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordOtpDialog(
              email: 'mia.garcia.cr@gmail.com',
              title: 'Verify Password Change',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verify Password Change'), findsOneWidget);
      expect(find.textContaining('mia.garcia.cr@gmail.com'), findsOneWidget);
      expect(find.text('Verify Account'), findsOneWidget);
      expect(find.text("Didn't receive the code?"), findsOneWidget);
      // Zero overflow errors thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on extra-small 320px mobile view with zero overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordOtpDialog(
              email: 'test@example.com',
              title: 'Verify Password Change',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verify Password Change'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on 390px mobile view (iPhone/Galaxy)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordOtpDialog(
              email: 'student@example.com',
              title: 'Verify Password Change',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verify Password Change'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Close (X) button is clickable and dismisses PasswordOtpDialog', (
      tester,
    ) async {
      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showDialog<bool>(
                    context: context,
                    builder: (_) => const PasswordOtpDialog(
                      email: 'mia.garcia.cr@gmail.com',
                      title: 'Verify Password Change',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verify Password Change'), findsOneWidget);

      // Find top-right Close IconButton by tooltip 'Close'
      final closeButton = find.byTooltip('Close');
      expect(closeButton, findsOneWidget);

      // Tap close button and verify it pops the dialog
      await tester.tap(closeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Verify Password Change'), findsNothing);
      expect(dialogResult, isFalse);
    });
  });
}
