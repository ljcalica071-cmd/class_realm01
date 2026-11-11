import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/shared/widgets/buttons/app_buttons.dart';
import 'package:class_realm/shared/widgets/modals/app_modals.dart';

void main() {
  group('AppButton & Dialog Button Sizing & Responsiveness', () {
    testWidgets('AppButton scales down text with FittedBox without truncating with ellipsis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                child: AppButton(
                  label: 'Understood',
                  onPressed: null,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify Text widget contains the full word 'Understood'
      final textFinder = find.text('Understood');
      expect(textFinder, findsOneWidget);

      // Verify that FittedBox exists in the tree to scale text down instead of clipping
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('AppPrimaryButton honors minWidth and renders full text for long labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppPrimaryButton(
                label: 'Return to Student Portal',
                minWidth: 140,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Return to Student Portal'), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('AppModals.showErrorDialog renders Understood button visibly and handles tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppModals.showErrorDialog(
                    context: context,
                    title: 'Authentication Failed',
                    message: 'Invalid email or password. 3 attempts remaining before lockout.',
                  );
                },
                child: const Text('Trigger Error'),
              ),
            ),
          ),
        ),
      );

      // Tap to trigger error dialog
      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      // Verify Dialog contents
      expect(find.text('Authentication Failed'), findsOneWidget);
      expect(find.textContaining('3 attempts remaining'), findsOneWidget);

      // Verify Understood button is present with full text
      expect(find.text('Understood'), findsOneWidget);
      expect(find.textContaining('Underst...'), findsNothing);

      // Tap Understood and confirm dialog dismisses
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      expect(find.text('Authentication Failed'), findsNothing);
    });
  });
}
