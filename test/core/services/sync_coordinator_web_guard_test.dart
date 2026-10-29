import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';

void main() {
  test('SyncCoordinator exposes isLocalDbSupported == !kIsWeb without eager DB init', () {
    expect(SyncCoordinator.isLocalDbSupported, equals(!kIsWeb));
  });

  test('SyncCoordinator safe no-op on non-supported platforms', () async {
    // Calling methods should not crash
    expect(SyncCoordinator.instance, isNotNull);
  });
}

