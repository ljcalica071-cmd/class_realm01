/// Tracks a fixed-duration cooldown window with optional local persistence.
class CooldownTracker {
  final Duration duration;
  final DateTime Function() _clock;
  final int? Function()? readPersistedMs;
  final void Function(int? epochMs)? writePersistedMs;

  DateTime? _lastTriggeredAt;

  CooldownTracker({
    required this.duration,
    DateTime Function()? clock,
    this.readPersistedMs,
    this.writePersistedMs,
  }) : _clock = clock ?? DateTime.now;

  /// Records the start of a new cooldown window from now.
  void trigger() {
    final now = _clock();
    _lastTriggeredAt = now;
    writePersistedMs?.call(now.millisecondsSinceEpoch);
  }

  /// Clears any active cooldown window.
  void reset() {
    _lastTriggeredAt = null;
    writePersistedMs?.call(null);
  }

  /// Remaining whole seconds in the active cooldown, rounded up (`0` if expired).
  int get remainingSeconds {
    DateTime? last = _lastTriggeredAt;
    if (last == null && readPersistedMs != null) {
      final persistedMs = readPersistedMs!();
      if (persistedMs != null) {
        last = DateTime.fromMillisecondsSinceEpoch(persistedMs);
        _lastTriggeredAt = last;
      }
    }
    if (last == null) return 0;

    final elapsedMs = _clock().difference(last).inMilliseconds;
    if (elapsedMs < 0) return duration.inSeconds;

    final remainingMs = duration.inMilliseconds - elapsedMs;
    if (remainingMs <= 0) {
      _lastTriggeredAt = null;
      writePersistedMs?.call(null);
      return 0;
    }
    return ((remainingMs + 999) ~/ 1000).clamp(1, duration.inSeconds);
  }

  bool get isActive => remainingSeconds > 0;
}
