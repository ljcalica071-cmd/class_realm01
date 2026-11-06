import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart';

void main() {
  Widget buildCell({
    required ValueChanged<String> onChanged,
    String value = '',
    bool isHpsCell = false,
    double? columnHps = 30,
    bool isEnabled = true,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: GradebookGridCell(
            value: value,
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
    await tester.pump(const Duration(milliseconds: 250));
    expect(latest, '100');

    await tester.enterText(find.byType(TextField), '101');
    await tester.pump(const Duration(milliseconds: 250));
    expect(latest, '100');

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump(const Duration(milliseconds: 250));
    expect(latest, '100');
  });

  testWidgets('does not accept edits when disabled', (tester) async {
    await tester.pumpWidget(buildCell(onChanged: (_) {}, isEnabled: false));

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('renders square cell container with 13px bold text and borderless InputDecoration under AppTheme', (tester) async {
    await tester.pumpWidget(
      buildCell(onChanged: (_) {}, theme: AppTheme.lightTheme),
    );

    final containerFinder = find.byType(Container).first;
    final container = tester.widget<Container>(containerFinder);
    final boxDecoration = container.decoration as BoxDecoration?;
    expect(boxDecoration?.borderRadius, BorderRadius.circular(2));

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.style?.fontSize, 13);
    expect(textField.style?.fontWeight, FontWeight.w600);
    expect(textField.textAlignVertical, TextAlignVertical.center);
    expect(textField.decoration?.filled, isFalse);
    expect(textField.decoration?.border, InputBorder.none);
    expect(textField.decoration?.enabledBorder, InputBorder.none);
    expect(textField.decoration?.focusedBorder, InputBorder.none);
    expect(textField.decoration?.disabledBorder, InputBorder.none);
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

  testWidgets('HPS and score cells retain focus and preserve text with ValueNotifier parent rebuilds and unfocus', (
    tester,
  ) async {
    final hpsNotifier = ValueNotifier<String>('50');
    final scoreNotifier = ValueNotifier<String>('');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: hpsNotifier,
                builder: (context, hpsValue, _) {
                  return GradebookGridCell(
                    key: const ValueKey('hps-offering-1-ww-0'),
                    value: hpsValue,
                    onChanged: (val) => hpsNotifier.value = val,
                    isHpsCell: true,
                    columnHps: null,
                    isEnabled: true,
                    width: 48,
                    backgroundColor: Colors.white,
                    borderColor: Colors.grey,
                    textColor: Colors.black,
                  );
                },
              ),
              ValueListenableBuilder<String>(
                valueListenable: scoreNotifier,
                builder: (context, scoreValue, _) {
                  return GradebookGridCell(
                    key: const ValueKey('score-offering-1-stu-ww-0'),
                    value: scoreValue,
                    onChanged: (val) => scoreNotifier.value = val,
                    isHpsCell: false,
                    columnHps: 55,
                    isEnabled: true,
                    width: 48,
                    backgroundColor: Colors.white,
                    borderColor: Colors.grey,
                    textColor: Colors.black,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    final hpsField = find.byType(TextField).first;
    final scoreField = find.byType(TextField).last;

    await tester.tap(hpsField);
    await tester.pump();
    expect(tester.widget<TextField>(hpsField).focusNode?.hasFocus, isTrue);

    // Type first digit '5', wait for debounce + ValueNotifier rebuild
    await tester.enterText(hpsField, '5');
    await tester.pump(const Duration(milliseconds: 250));

    // Must still have focus after debounce update!
    expect(hpsNotifier.value, '5');
    expect(tester.widget<TextField>(hpsField).focusNode?.hasFocus, isTrue);

    // Type second digit to make '55' and immediately tap scoreField (unfocusing hpsField before 220ms)
    await tester.enterText(hpsField, '55');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(scoreField);
    await tester.pump();

    // HPS value must be flushed to '55' and remain '55' in the controller (not reverted to '5')!
    expect(hpsNotifier.value, '55');
    expect(tester.widget<TextField>(hpsField).controller?.text, '55');

    // Type '4' in score cell and unfocus
    await tester.enterText(scoreField, '4');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(scoreNotifier.value, '4');
    expect(tester.widget<TextField>(scoreField).controller?.text, '4');
  });
}
