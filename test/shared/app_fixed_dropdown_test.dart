import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/shared/widgets/app_fixed_dropdown.dart';

void main() {
  group('AppFixedDropdown Tests', () {
    testWidgets('renders items and selects value without errors',
        (tester) async {
      String? selected = 'Grade 11';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppFixedDropdown<String>(
                  value: selected,
                  items: const [
                    AppDropdownItem(value: 'Grade 11', label: 'Grade 11'),
                    AppDropdownItem(value: 'Grade 12', label: 'Grade 12'),
                  ],
                  onChanged: (val) {
                    setState(() => selected = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Grade 11'), findsOneWidget);

      // Open menu
      await tester.tap(find.text('Grade 11'));
      await tester.pumpAndSettle();

      expect(find.text('Grade 12'), findsOneWidget);

      // Select Grade 12
      await tester.tap(find.text('Grade 12'));
      await tester.pumpAndSettle();

      expect(selected, 'Grade 12');
      expect(find.text('Grade 12'), findsOneWidget);
    });

    testWidgets('menu position remains fixed regardless of selected item',
        (tester) async {
      int? selected = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: AppFixedDropdown<int>(
                    value: selected,
                    items: const [
                      AppDropdownItem(value: 1, label: '1 Term Only'),
                      AppDropdownItem(value: 2, label: '2 Terms'),
                      AppDropdownItem(
                        value: 3,
                        label: '3 Terms (Full Year / Trimester)',
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => selected = val);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Open menu when value is 1
      await tester.tap(find.text('1 Term Only'));
      await tester.pumpAndSettle();

      final firstOptionPos =
          tester.getTopLeft(find.text('1 Term Only').last);

      // Tap 3 Terms
      await tester.tap(find.text('3 Terms (Full Year / Trimester)'));
      await tester.pumpAndSettle();

      expect(selected, 3);

      // Reopen menu
      await tester.tap(find.text('3 Terms (Full Year / Trimester)'));
      await tester.pumpAndSettle();

      // First option Y position must remain exactly the same
      final reopenedFirstOptionPos =
          tester.getTopLeft(find.text('1 Term Only'));
      expect(reopenedFirstOptionPos.dy, equals(firstOptionPos.dy));
    });

    testWidgets('AppFixedDropdownFormField validates properly', (tester) async {
      final formKey = GlobalKey<FormState>();
      String? gender;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppFixedDropdownFormField<String>(
                hintText: 'Select Gender',
                initialValue: gender,
                items: const [
                  AppDropdownItem(value: 'Male', label: 'Male'),
                  AppDropdownItem(value: 'Female', label: 'Female'),
                ],
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Gender is required' : null,
                onChanged: (val) => gender = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select Gender'), findsOneWidget);

      final isValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(isValid, isFalse);
      expect(find.text('Gender is required'), findsOneWidget);

      await tester.tap(find.text('Select Gender'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();

      expect(gender, 'Female');

      final isNowValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(isNowValid, isTrue);
      expect(find.text('Gender is required'), findsNothing);
    });

    testWidgets(
        'compact AppFixedDropdown does not stretch menu across parent width',
        (tester) async {
      String? selected = 'Section 1';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: Wrap(
                children: [
                  AppFixedDropdown<String>(
                    value: selected,
                    items: const [
                      AppDropdownItem(value: 'Section 1', label: 'Section 1'),
                      AppDropdownItem(value: 'Section 2', label: 'Section 2'),
                    ],
                    onChanged: (val) => selected = val,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();

      // Find the menu item button
      final menuItem = find.byType(MenuItemButton).first;
      final size = tester.getSize(menuItem);

      // The menu must be compact and NOT stretch to the 1000px parent width
      expect(size.width, lessThan(400));

      // Selecting Section 2 works seamlessly
      await tester.tap(find.text('Section 2'));
      await tester.pumpAndSettle();

      expect(selected, 'Section 2');
    });
  });
}
