import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/admin/shared/widgets/admin_fixed_dropdown.dart';

void main() {
  group('AdminFixedDropdown Tests', () {
    testWidgets('renders items and selects value without errors',
        (tester) async {
      String? selected = 'Male';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AdminFixedDropdown<String>(
                  value: selected,
                  items: const [
                    AdminDropdownItem(value: 'Male', label: 'Male'),
                    AdminDropdownItem(value: 'Female', label: 'Female'),
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

      expect(find.text('Male'), findsOneWidget);

      // Tap trigger to open MenuAnchor
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();

      // Should show 'Female' in the menu
      expect(find.text('Female'), findsOneWidget);

      // Select 'Female'
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();

      expect(selected, 'Female');
      expect(find.text('Female'), findsOneWidget);
    });

    testWidgets('menu position remains fixed when switching between items',
        (tester) async {
      String? selected = 'item_0';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: AdminFixedDropdown<String>(
                    value: selected,
                    items: const [
                      AdminDropdownItem(value: 'item_0', label: 'Option 1'),
                      AdminDropdownItem(value: 'item_1', label: 'Option 2'),
                      AdminDropdownItem(value: 'item_2', label: 'Option 3'),
                      AdminDropdownItem(value: 'item_3', label: 'Option 4'),
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

      // Open menu when item_0 is selected
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();

      final firstOptionLocation = tester.getTopLeft(find.text('Option 1').last);

      // Select Option 4 (last item)
      await tester.tap(find.text('Option 4'));
      await tester.pumpAndSettle();

      expect(selected, 'item_3');

      // Re-open menu now that Option 4 is selected
      await tester.tap(find.text('Option 4'));
      await tester.pumpAndSettle();

      // In the legacy DropdownButton, the menu would shift upwards so Option 4
      // aligns with the button. In AdminFixedDropdown, the first option's Y-coordinate
      // is ALWAYS fixed in the exact same place!
      final reopenedFirstOptionLocation =
          tester.getTopLeft(find.text('Option 1'));
      expect(reopenedFirstOptionLocation.dy, equals(firstOptionLocation.dy));
    });

    testWidgets('disabled items cannot be selected', (tester) async {
      String? selected = 'all';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AdminFixedDropdown<String>(
                  value: selected,
                  items: const [
                    AdminDropdownItem(value: 'all', label: 'All Users (10)'),
                    AdminDropdownItem(
                      value: 'empty',
                      label: 'No Users (0)',
                      enabled: false,
                    ),
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

      await tester.tap(find.text('All Users (10)'));
      await tester.pumpAndSettle();

      // Tap disabled item
      await tester.tap(find.text('No Users (0)'));
      await tester.pumpAndSettle();

      // Value should remain unchanged
      expect(selected, 'all');
    });

    testWidgets('AdminFixedDropdownFormField validates correctly',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      String? gender;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AdminFixedDropdownFormField<String>(
                hintText: 'Select Gender',
                initialValue: gender,
                items: const [
                  AdminDropdownItem(value: 'Male', label: 'Male'),
                  AdminDropdownItem(value: 'Female', label: 'Female'),
                ],
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Gender is required' : null,
                onChanged: (val) => gender = val,
              ),
            ),
          ),
        ),
      );

      // Initially shows hint
      expect(find.text('Select Gender'), findsOneWidget);

      // Trigger form validation -> should fail
      final isValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(isValid, isFalse);
      expect(find.text('Gender is required'), findsOneWidget);

      // Open menu and select Male
      await tester.tap(find.text('Select Gender'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();

      expect(gender, 'Male');

      // Validate again -> should pass
      final isNowValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(isNowValid, isTrue);
      expect(find.text('Gender is required'), findsNothing);
    });
  });
}
