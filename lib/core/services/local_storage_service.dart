import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _settingsBoxName = 'settingsBox';
  static const String _authBoxName = 'authBox';

  static late Box _settingsBox;
  static late Box _authBox;

  // Key Constants
  static const String keyRememberMe = 'remember_me';
  static const String keySavedEmail = 'saved_email';
  static const String keyIsDarkMode = 'is_dark_mode';

  static Future<void> init() async {
    // Initialize Hive for Flutter
    await Hive.initFlutter();

    // Open boxes
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _authBox = await Hive.openBox(_authBoxName);
  }

  // --- Auth Cache (Remember Me) ---
  
  static Future<void> saveRememberMe(bool value, String email) async {
    await _authBox.put(keyRememberMe, value);
    if (value) {
      await _authBox.put(keySavedEmail, email);
    } else {
      await _authBox.delete(keySavedEmail);
    }
  }

  static bool get isRememberMe => _authBox.get(keyRememberMe, defaultValue: false);
  static String? get savedEmail => _authBox.get(keySavedEmail);

  static Future<void> clearAuth() async {
    await _authBox.clear();
  }

  // --- Settings Cache (Theme) ---

  static Future<void> saveThemeMode(bool isDark) async {
    await _settingsBox.put(keyIsDarkMode, isDark);
  }

  static bool get isDarkMode => _settingsBox.get(keyIsDarkMode, defaultValue: false);

  // --- Generic Cache ---
  static Future<void> saveString(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  static String? getString(String key) {
    return _settingsBox.get(key);
  }
}
