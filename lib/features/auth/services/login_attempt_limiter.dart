class LoginAttemptLimiter {
  LoginAttemptLimiter({
    this.maxAttempts = 5,
    this.lockoutDuration = const Duration(minutes: 15),
  });

  final int maxAttempts;
  final Duration lockoutDuration;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  Duration? remainingAt(DateTime now) {
    final lockedUntil = _lockedUntil;
    if (lockedUntil == null) return null;
    if (!now.isBefore(lockedUntil)) {
      reset();
      return null;
    }
    return lockedUntil.difference(now);
  }

  Duration? recordFailure(DateTime now) {
    final remaining = remainingAt(now);
    if (remaining != null) return remaining;

    _failedAttempts++;
    if (_failedAttempts < maxAttempts) return null;

    _lockedUntil = now.add(lockoutDuration);
    return lockoutDuration;
  }

  Duration startLockout(DateTime now) {
    _lockedUntil = now.add(lockoutDuration);
    return lockoutDuration;
  }

  void reset() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }
}
