import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  test(
    'stores and loads gradebook sheets independently by offering and term',
    () async {
      final termOne = {
        'hps': {
          'ww': {'1': 10, '2': 15},
          'pt': {'1': 20},
          'ex': {'st1': 30, 'st2': 30, 'te': 50},
        },
        'scores': {
          'student-1': {
            'ww': {'1': 10, '2': 12},
            'pt': {'1': 18},
            'ex': {'st1': 28, 'st2': 27, 'te': 45},
          },
        },
      };
      final termTwo = {
        'hps': {
          'ww': {'1': 20},
        },
        'scores': {
          'student-1': {
            'ww': {'1': null},
          },
        },
      };

      await LocalStorageService.saveGradebookSheet('offering-a', 1, termOne);
      await LocalStorageService.saveGradebookSheet('offering-a', 2, termTwo);
      await LocalStorageService.saveGradebookSheet('offering-b', 1, {
        'scores': {},
      });

      expect(LocalStorageService.getGradebookSheet('offering-a', 1), termOne);
      expect(LocalStorageService.getGradebookSheet('offering-a', 2), termTwo);
      expect(LocalStorageService.getGradebookSheet('offering-b', 1), {
        'scores': {},
      });
      expect(LocalStorageService.getGradebookSheet('offering-a', 3), isNull);

      await LocalStorageService.clearGradebookSheet('offering-a', 1);
      expect(LocalStorageService.getGradebookSheet('offering-a', 1), isNull);
    },
  );
}
