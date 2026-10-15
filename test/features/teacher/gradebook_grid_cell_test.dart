import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart';

void main() {
  Widget buildCell({
    required ValueChanged<String> onChanged,
    bool isHpsCell = false,
    double? columnHps = 30,
    bool isEnabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: GradebookGridCell(
            value: '',
            onChanged: onChanged,
            isHpsCell: isHpsCell,
            columnHps: columnHps,
            isEnabled: isEnabled,
            width: 48,
            backgroundColor: Colors.white,
            borderColor: Colors.grey,
            textColor: Colors.black,
          ),
        ),
      ),
    );
  }

  testWidgets('accepts zero scores and rejects scores above HPS', (
    tester,
  ) async {
    var latest = 'unchanged';
    await tester.pumpWidget(buildCell(onChanged: (value) => latest = value));

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(latest, '0');

    await tester.enterText(find.byType(TextField), '31');
    await tester.pump();
    expect(latest, '0');

    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    expect(latest, '0');
  });

  testWidgets('accepts HPS values from 1 through 100 only', (tester) async {
    var latest = 'unchanged';
    await tester.pumpWidget(
      buildCell(
        onChanged: (value) => latest = value,
        isHpsCell: true,
        columnHps: null,
      ),
    );

    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    expect(latest, '100');

    await tester.enterText(find.byType(TextField), '101');
    await tester.pump();
    expect(latest, '100');

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(latest, '100');
  });

  testWidgets('does not accept edits when disabled', (tester) async {
    await tester.pumpWidget(buildCell(onChanged: (_) {}, isEnabled: false));

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('renders square cell container with 13px bold text', (tester) async {
    await tester.pumpWidget(buildCell(onChanged: (_) {}));

    final containerFinder = find.byType(Container).first;
    final container = tester.widget<Container>(containerFinder);
    final boxDecoration = container.decoration as BoxDecoration?;
    expect(boxDecoration?.borderRadius, BorderRadius.circular(2));

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.style?.fontSize, 13);
    expect(textField.style?.fontWeight, FontWeight.w600);
    expect(textField.textAlignVertical, TextAlignVertical.center);
  });

  testWidgets('tapping anywhere in square cell requests focus', (tester) async {
    await tester.pumpWidget(buildCell(onChanged: (_) {}));

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, isFalse);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();

    final focusedField = tester.widget<TextField>(find.byType(TextField));
    expect(focusedField.focusNode?.hasFocus, isTrue);
  });
}
