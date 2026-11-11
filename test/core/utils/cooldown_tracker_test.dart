import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/utils/cooldown_tracker.dart';

void main() {
  group('CooldownTracker', () {
    test('tracks 60s countdown accurately and resets upon expiry', () {
      var now = DateTime(2026, 11, 11, 10, 0, 0);
      int? persisted;

      final tracker = CooldownTracker(
        duration: const Duration(minutes: 1),
        clock: () => now,
        readPersistedMs: () => persisted,
        writePersistedMs: (ms) => persisted = ms,
      );

      expect(tracker.isActive, isFalse);
      expect(tracker.remainingSeconds, 0);

      tracker.trigger();
      expect(persisted, now.millisecondsSinceEpoch);
      expect(tracker.isActive, isTrue);
      expect(tracker.remainingSeconds, 60);

      now = now.add(const Duration(seconds: 15));
      expect(tracker.remainingSeconds, 45);

      now = now.add(const Duration(seconds: 44, milliseconds: 500));
      expect(tracker.remainingSeconds, 1);

      now = now.add(const Duration(milliseconds: 500));
      expect(tracker.remainingSeconds, 0);
      expect(tracker.isActive, isFalse);
      expect(persisted, isNull);
    });

    test('restores active cooldown from persisted timestamp', () {
      final now = DateTime(2026, 11, 11, 10, 0, 0);
      int? persisted =
          now.subtract(const Duration(seconds: 20)).millisecondsSinceEpoch;

      final tracker = CooldownTracker(
        duration: const Duration(minutes: 1),
        clock: () => now,
        readPersistedMs: () => persisted,
        writePersistedMs: (ms) => persisted = ms,
      );

      expect(tracker.isActive, isTrue);
      expect(tracker.remainingSeconds, 40);

      tracker.reset();
      expect(tracker.isActive, isFalse);
      expect(persisted, isNull);
    });
  });
}
