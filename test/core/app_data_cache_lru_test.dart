import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    AppDataCache.instance.clearAll();
    AppDataCache.instance.maxEntries = AppDataCache.defaultMaxEntries;
  });

  tearDown(() {
    AppDataCache.instance.clearAll();
  });

  group('AppDataCache LRU Eviction & Attendance Protection Tests', () {
    test('Evicts least-recently used item when maxEntries is exceeded', () {
      AppDataCache.instance.maxEntries = 3;

      AppDataCache.instance.set('key_1', 'value_1');
      AppDataCache.instance.set('key_2', 'value_2');
      AppDataCache.instance.set('key_3', 'value_3');

      // Touch key_1, then key_2, then key_3
      expect(AppDataCache.instance.get('key_1'), equals('value_1'));
      expect(AppDataCache.instance.get('key_2'), equals('value_2'));
      expect(AppDataCache.instance.get('key_3'), equals('value_3'));

      // Adding key_4 should evict key_1 (oldest touched among the 3)
      AppDataCache.instance.set('key_4', 'value_4');

      expect(AppDataCache.instance.get('key_1'), isNull);
      expect(AppDataCache.instance.get('key_2'), equals('value_2'));
      expect(AppDataCache.instance.get('key_3'), equals('value_3'));
      expect(AppDataCache.instance.get('key_4'), equals('value_4'));
    });

    test('Accessing (touching) a key promotes it and prevents eviction', () {
      AppDataCache.instance.maxEntries = 3;

      AppDataCache.instance.set('alpha', 100);
      AppDataCache.instance.set('beta', 200);
      AppDataCache.instance.set('gamma', 300);

      // Now touch 'alpha' via get
      expect(AppDataCache.instance.get('alpha'), equals(100));

      // Now the LRU order is beta (oldest), gamma, alpha (newest)
      // Adding 'delta' should evict 'beta', NOT 'alpha'
      AppDataCache.instance.set('delta', 400);

      expect(AppDataCache.instance.get('alpha'), equals(100));
      expect(AppDataCache.instance.get('beta'), isNull);
      expect(AppDataCache.instance.get('gamma'), equals(300));
      expect(AppDataCache.instance.get('delta'), equals(400));
    });

    test('Attendance and offline keys are strictly protected and NEVER evicted by LRU', () {
      AppDataCache.instance.maxEntries = 3;

      // Add protected attendance and offline keys first (oldest)
      AppDataCache.instance.set('attendance_roster_sub123', {'students': 40});
      AppDataCache.instance.set('offline_attendance_queue', [{'id': 1}]);
      AppDataCache.instance.set('regular_item_1', 'abc');

      // Now add regular_item_2, exceeding maxEntries (3)
      // Even though 'attendance_roster_sub123' and 'offline_attendance_queue' are the oldest,
      // they are protected! Thus 'regular_item_1' should be evicted.
      AppDataCache.instance.set('regular_item_2', 'def');

      expect(AppDataCache.instance.get('attendance_roster_sub123'), isNotNull);
      expect(AppDataCache.instance.get('offline_attendance_queue'), isNotNull);
      expect(AppDataCache.instance.get('regular_item_2'), equals('def'));
      expect(AppDataCache.instance.get('regular_item_1'), isNull);
    });

    test('Explicit pin and unpin protects custom keys', () {
      AppDataCache.instance.maxEntries = 2;

      AppDataCache.instance.pin('my_custom_critical_key');
      AppDataCache.instance.set('my_custom_critical_key', 'protected');
      AppDataCache.instance.set('temp_key_1', 'temporary 1');

      // Add third item
      AppDataCache.instance.set('temp_key_2', 'temporary 2');

      // 'my_custom_critical_key' must still exist, while 'temp_key_1' is evicted
      expect(AppDataCache.instance.get('my_custom_critical_key'), equals('protected'));
      expect(AppDataCache.instance.get('temp_key_1'), isNull);
      expect(AppDataCache.instance.get('temp_key_2'), equals('temporary 2'));

      // Unpin and add another
      AppDataCache.instance.unpin('my_custom_critical_key');
      AppDataCache.instance.set('temp_key_3', 'temporary 3');

      // Now 'my_custom_critical_key' was oldest and unpinned, so it is evicted
      expect(AppDataCache.instance.get('my_custom_critical_key'), isNull);
      expect(AppDataCache.instance.get('temp_key_2'), equals('temporary 2'));
      expect(AppDataCache.instance.get('temp_key_3'), equals('temporary 3'));
    });
  });
}
