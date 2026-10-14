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
}
