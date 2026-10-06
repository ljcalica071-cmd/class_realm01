import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/auth/services/login_attempt_limiter.dart';

void main() {
  group('LoginAttemptLimiter', () {
    final start = DateTime(2026, 10, 4, 12);

    test('locks for 15 minutes on the fifth failed attempt', () {
      final limiter = LoginAttemptLimiter();

      for (var attempt = 1; attempt < 5; attempt++) {
        expect(limiter.recordFailure(start), isNull);
      }

      expect(limiter.recordFailure(start), const Duration(minutes: 15));
      expect(
        limiter.remainingAt(start.add(const Duration(minutes: 14))),
        const Duration(minutes: 1),
      );
    });

    test('clears the lock after 15 minutes', () {
      final limiter = LoginAttemptLimiter();
      for (var attempt = 0; attempt < 5; attempt++) {
        limiter.recordFailure(start);
      }

      expect(
        limiter.remainingAt(start.add(const Duration(minutes: 15))),
        isNull,
      );
      expect(
        limiter.recordFailure(start.add(const Duration(minutes: 15))),
        isNull,
      );
    });

    test('successful authentication can reset failed attempts', () {
      final limiter = LoginAttemptLimiter();
      for (var attempt = 0; attempt < 4; attempt++) {
        limiter.recordFailure(start);
      }

      limiter.reset();

      for (var attempt = 0; attempt < 4; attempt++) {
        expect(limiter.recordFailure(start), isNull);
      }
      expect(limiter.recordFailure(start), const Duration(minutes: 15));
    });
  });
}
