import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';

void main() {
  testWidgets('AppTimePickerField formats time string properly', (
    tester,
  ) async {
    const t1 = TimeOfDay(hour: 7, minute: 5);
    expect(AppTimePickerField.format(t1), '07:05 AM');

    const t2 = TimeOfDay(hour: 13, minute: 45);
    expect(AppTimePickerField.format(t2), '01:45 PM');

    const t3 = TimeOfDay(hour: 0, minute: 0);
    expect(AppTimePickerField.format(t3), '12:00 AM');
  });

  testWidgets(
    'showAppTimePickerDialog allows direct typing and validates range strictly',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      TimeOfDay? selectedTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedTime = await showAppTimePickerDialog(
                    context,
                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                    title: 'Select Start Time',
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      // 1. Open Dialog
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Start Time'), findsOneWidget);
      expect(find.text('Hour'), findsOneWidget);
      expect(find.text('Minute'), findsOneWidget);

      // 2. Locate Hour and Minute text fields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      final hourField = textFields.first;
      final minuteField = textFields.last;

      // 3. Test Invalid Hour (> 12)
      await tester.enterText(hourField, '15');
      await tester.pumpAndSettle();

      expect(find.text('Hour must be between 1 and 12.'), findsOneWidget);
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm Time'),
      );
      expect(confirmBtn.onPressed, isNull); // Disabled

      // 4. Test Valid Custom Hour & Minute (07:12 AM)
      await tester.enterText(hourField, '07');
      await tester.pumpAndSettle();
      expect(find.text('Hour must be between 1 and 12.'), findsNothing);

      await tester.enterText(minuteField, '12');
      await tester.pumpAndSettle();
      expect(find.text('Minute must be between 00 and 59.'), findsNothing);

      // 5. Confirm Time
      final confirmFinder = find.widgetWithText(ElevatedButton, 'Confirm Time');
      await tester.ensureVisible(confirmFinder);
      await tester.pumpAndSettle();
      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      // Verify dialog returned exact custom typed time 07:12 AM
      expect(selectedTime, isNotNull);
      expect(selectedTime!.hour, 7);
      expect(selectedTime!.minute, 12);
    },
  );

  testWidgets(
    'showAppTimePickerDialog enforces minTime and maxTime strictly',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showAppTimePickerDialog(
                    context,
                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                    minTime: const TimeOfDay(hour: 7, minute: 0),
                    maxTime: const TimeOfDay(hour: 19, minute: 0),
                    title: 'Select Operating Hours',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final hourField = textFields.first;
      final minuteField = textFields.last;

      // 1. Enter 01:00 AM (earlier than 07:00 AM)
      await tester.enterText(hourField, '01');
      await tester.enterText(minuteField, '00');
      await tester.pumpAndSettle();

      expect(
        find.text('Time cannot be earlier than 07:00 AM.'),
        findsOneWidget,
      );
      final confirmBtn1 = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm Time'),
      );
      expect(confirmBtn1.onPressed, isNull);

      // 2. Enter 08:00 PM (later than 07:00 PM)
      // Toggle to PM
      await tester.tap(find.text('PM'));
      await tester.enterText(hourField, '08');
      await tester.pumpAndSettle();

      expect(
        find.text('Time cannot be later than 07:00 PM.'),
        findsOneWidget,
      );
      final confirmBtn2 = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm Time'),
      );
      expect(confirmBtn2.onPressed, isNull);
    },
  );
}
