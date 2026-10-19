import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/models/admin_portal_models.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';

void main() {
  group('Admin Portal Core Algorithms & Validations', () {
    test('1. Human-readable duration formatting strictly adheres to specification', () {
      // 01hr 01min 1sec
      expect(
        AdminRepository.formatHumanReadableDuration(1 * 3600 + 1 * 60 + 1),
        equals('01hr 01min 1sec'),
      );

      // 2hrs 57mins 05secs
      expect(
        AdminRepository.formatHumanReadableDuration(2 * 3600 + 57 * 60 + 5),
        equals('2hrs 57mins 05secs'),
      );

      // 00hr 57mins 1sec
      expect(
        AdminRepository.formatHumanReadableDuration(0 * 3600 + 57 * 60 + 1),
        equals('00hr 57mins 1sec'),
      );

      // 00hr 00min 40secs
      expect(
        AdminRepository.formatHumanReadableDuration(40),
        equals('00hr 00min 40secs'),
      );
    });

    test('2. Concurrent multi-device session interval merging (Edge Case #17)', () {
      final base = DateTime(2026, 10, 19, 10, 0, 0);

      // Session A: 10:00 to 11:00 (3600s) on Laptop
      final sessionA = UserSessionLog(
        id: '1',
        userId: 'teacher_1',
        role: 'teacher',
        sessionDate: base,
        loginAt: base,
        lastActiveAt: base.add(const Duration(hours: 1)),
        logoutAt: base.add(const Duration(hours: 1)),
        isActive: false,
        durationSeconds: 3600,
      );

      // Session B: 10:30 to 11:30 (3600s) on Mobile (overlaps with A by 30 mins)
      final sessionB = UserSessionLog(
        id: '2',
        userId: 'teacher_1',
        role: 'teacher',
        sessionDate: base,
        loginAt: base.add(const Duration(minutes: 30)),
        lastActiveAt: base.add(const Duration(hours: 1, minutes: 30)),
        logoutAt: base.add(const Duration(hours: 1, minutes: 30)),
        isActive: false,
        durationSeconds: 3600,
      );

      // Merged duration should be 10:00 to 11:30 = 1.5 hours = 5400 seconds (NOT 7200s!)
      final mergedSeconds = AdminRepository.calculateMergedDurationSeconds([sessionA, sessionB]);
      expect(mergedSeconds, equals(5400));
    });

    test('3. Midnight and day-boundary interval splitting (Edge Case #19)', () {
      final startSunday = DateTime(2026, 10, 18, 23, 0, 0);
      final endMonday = DateTime(2026, 10, 19, 2, 0, 0);

      final slices = AdminRepository.splitIntervalAtMidnight(startSunday, endMonday);

      expect(slices.length, equals(2));
      // First slice: 23:00 to 00:00 Sunday (1 hour)
      expect(slices[0].duration.inHours, equals(1));
      // Second slice: 00:00 to 02:00 Monday (2 hours)
      expect(slices[1].duration.inHours, equals(2));
    });

    test('4. Consecutive School Year validation (Edge Case #12)', () {
      final validRegex = RegExp(r'^[0-9]{4}-[0-9]{4}$');

      bool isValidSchoolYear(String sy) {
        if (!validRegex.hasMatch(sy)) return false;
        final parts = sy.split('-');
        final start = int.tryParse(parts[0]);
        final end = int.tryParse(parts[1]);
        if (start == null || end == null) return false;
        return end == start + 1;
      }

      expect(isValidSchoolYear('2026-2027'), isTrue);
      expect(isValidSchoolYear('2027-2028'), isTrue);

      // Edge Case #12 errors that must be rejected:
      expect(isValidSchoolYear('2027-2027'), isFalse); // Same year
      expect(isValidSchoolYear('2026-2025'), isFalse); // Decreasing year
      expect(isValidSchoolYear('2026-2028'), isFalse); // Non-consecutive gap
      expect(isValidSchoolYear('2026-27'), isFalse);   // Bad format
      expect(isValidSchoolYear('ABCD-EFGH'), isFalse); // Non-numeric
    });

    test('5. Unbroken long string wrapping with zero-width breaks (Edge Case #8)', () {
      final longUnbroken = 'A' * 60;
      final wrapped = ExpandableNotificationCard.wrapUnbrokenString(longUnbroken, chunkLength: 20);

      // Should contain zero-width space characters (\u200B)
      expect(wrapped.contains('\u200B'), isTrue);

      // Normal space-separated text should not be altered unnecessarily
      const normalText = 'Hello world this is a normal sentence';
      expect(
        ExpandableNotificationCard.wrapUnbrokenString(normalText, chunkLength: 20),
        equals(normalText),
      );
    });
  });
}
