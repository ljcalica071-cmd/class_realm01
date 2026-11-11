import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/student_repository.dart';
import 'package:class_realm/shared/widgets/modals/app_modals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentDeletionEligibility Model Tests', () {
    test('initializes with default values properly', () {
      const eligibility = StudentDeletionEligibility(
        canDelete: true,
        isClassRemovalOnly: false,
      );

      expect(eligibility.canDelete, isTrue);
      expect(eligibility.isClassRemovalOnly, isFalse);
      expect(eligibility.hasClassRecords, isFalse);
      expect(eligibility.hasGlobalRecords, isFalse);
      expect(eligibility.hasOtherEnrollments, isFalse);
      expect(eligibility.blockReason, isEmpty);
    });

    test('initializes with blocked state properly', () {
      const reason = 'Cannot delete student because attendance records exist.';
      const eligibility = StudentDeletionEligibility(
        canDelete: false,
        isClassRemovalOnly: false,
        hasClassRecords: true,
        blockReason: reason,
      );

      expect(eligibility.canDelete, isFalse);
      expect(eligibility.isClassRemovalOnly, isFalse);
      expect(eligibility.hasClassRecords, isTrue);
      expect(eligibility.blockReason, reason);
    });

    test('initializes with class removal only state properly', () {
      const eligibility = StudentDeletionEligibility(
        canDelete: true,
        isClassRemovalOnly: true,
        hasOtherEnrollments: true,
        hasGlobalRecords: false,
      );

      expect(eligibility.canDelete, isTrue);
      expect(eligibility.isClassRemovalOnly, isTrue);
      expect(eligibility.hasOtherEnrollments, isTrue);
      expect(eligibility.hasClassRecords, isFalse);
    });
  });

  group('Grade Evaluator Logic for Student Deletion', () {
    bool hasRealGrade(Map<String, dynamic> row) {
      final isFinalized = row['is_finalized'] == true;
      final initGrade = (row['initial_grade'] as num?)?.toDouble() ?? 0.0;
      final transGrade = (row['transmuted_grade'] as num?)?.toDouble() ?? 0.0;
      final remarks = row['remarks']?.toString();
      return isFinalized ||
          initGrade > 0 ||
          transGrade > 0 ||
          (remarks != null && remarks != 'Incomplete');
    }

    test('correctly identifies placeholder/empty gradebook row as non-real grade', () {
      final placeholderRow = {
        'initial_grade': 0.0,
        'transmuted_grade': 0.0,
        'remarks': 'Incomplete',
        'is_finalized': false,
      };

      expect(hasRealGrade(placeholderRow), isFalse);
    });

    test('correctly identifies finalized grade as real grade', () {
      final finalizedRow = {
        'initial_grade': 0.0,
        'transmuted_grade': 0.0,
        'remarks': 'Incomplete',
        'is_finalized': true,
      };

      expect(hasRealGrade(finalizedRow), isTrue);
    });

    test('correctly identifies non-zero initial grade as real grade', () {
      final row = {
        'initial_grade': 85.5,
        'transmuted_grade': 0.0,
        'remarks': 'Incomplete',
        'is_finalized': false,
      };

      expect(hasRealGrade(row), isTrue);
    });

    test('correctly identifies non-zero transmuted grade as real grade', () {
      final row = {
        'initial_grade': 0.0,
        'transmuted_grade': 88.0,
        'remarks': 'Incomplete',
        'is_finalized': false,
      };

      expect(hasRealGrade(row), isTrue);
    });

    test('correctly identifies Passed remarks as real grade', () {
      final row = {
        'initial_grade': 0.0,
        'transmuted_grade': 0.0,
        'remarks': 'Passed',
        'is_finalized': false,
      };

      expect(hasRealGrade(row), isTrue);
    });
  });

  group('UI Modals Integration for Student Deletion', () {
    testWidgets('AppModals.showErrorDialog renders with Understood button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AppModals.showErrorDialog(
                    context: context,
                    title: 'Cannot Delete Student',
                    message: 'This student has attendance records.',
                  );
                },
                child: const Text('Open Error'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Error'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot Delete Student'), findsOneWidget);
      expect(find.text('This student has attendance records.'), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);

      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot Delete Student'), findsNothing);
    });

    testWidgets('AppModals.showTypeToConfirmDeleteDialog auto-confirms upon exact phrase', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await AppModals.showTypeToConfirmDeleteDialog(
                    context: context,
                    title: 'Permanently Delete Student',
                    message: 'Type "I confirm" to proceed.',
                    requiredText: 'I confirm',
                  );
                },
                child: const Text('Open Delete Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Delete Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Permanently Delete Student'), findsOneWidget);

      // Enter mismatched phrase first
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'something else');
      await tester.pump();
      expect(result, isNull);

      // Now enter exact confirmation phrase
      await tester.enterText(textField, 'I confirm');
      await tester.pumpAndSettle();

      // Modal automatically dismisses and returns true
      expect(result, isTrue);
      expect(find.text('Permanently Delete Student'), findsNothing);
    });
  });
}
