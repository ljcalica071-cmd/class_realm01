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
          'ww': {'0': 10},
        },
        'scores': {
          'student-1': {
            'ww': {'0': 0},
          },
        },
      };
      final termTwo = {
        'hps': {
          'ww': {'0': 20},
        },
        'scores': {
          'student-1': {
            'ww': {'0': null},
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
    },
  );
}
