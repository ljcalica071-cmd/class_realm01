import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/widgets/app_lifecycle_loading_screen.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  testWidgets(
    'AppLifecycleLoadingScreen renders and invokes onComplete upon finish',
    (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppLifecycleLoadingScreen(
            initializationTask: (onProgress) async {
              onProgress(0.25, 'Loading test config...');
              await Future<void>.delayed(const Duration(milliseconds: 50));
              onProgress(0.75, 'Connecting test services...');
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return null as UserModel?;
            },
            onComplete: (context, UserModel? user) {
              completed = true;
            },
          ),
        ),
      );

      // Initial state: loading screen widget is present and shows progress percentage
      expect(find.byType(AppLifecycleLoadingScreen), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget);

      // Step through the animation loop (avoiding pumpAndSettle due to infinite ambient repeat)
      for (int i = 0; i < 45 && !completed; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(completed, isTrue);
    },
  );
}
