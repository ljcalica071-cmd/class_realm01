import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/models/user_model.dart';

class LocalStorageService {
  static const String _authPrefix = 'auth.';
  static const String _settingsPrefix = 'settings.';
  static const String _rememberMeKey = '${_authPrefix}remember_me';
  static const String _savedEmailKey = '${_authPrefix}saved_email';
  static const String _cachedUserKey = '${_authPrefix}cached_user';
  static const String _darkModeKey = '${_settingsPrefix}is_dark_mode';

  // Key Constants
  static const String keyRememberMe = _rememberMeKey;
  static const String keySavedEmail = _savedEmailKey;
  static const String keyCachedUser = _cachedUserKey;
  static const String keyIsDarkMode = _darkModeKey;

  static SharedPreferences? _preferences;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static Future<SharedPreferences> get _prefs async {
    if (_preferences == null) {
      await init();
    }
    return _preferences!;
  }

  static Future<void> saveRememberMe(bool value, String email) async {
    final prefs = await _prefs;
    if (value) {
      await _ensureSaved(await prefs.setString(keySavedEmail, email));
      await _ensureSaved(await prefs.setBool(keyRememberMe, true));
    } else {
      await _ensureSaved(await prefs.remove(keySavedEmail));
      await _ensureSaved(await prefs.setBool(keyRememberMe, false));
    }
  }

  static Future<void> saveUser(UserModel user) async {
    final prefs = await _prefs;
    final userJson = jsonEncode(user.toJson());
    await _ensureSaved(await prefs.setString(keyCachedUser, userJson));
  }

  static UserModel? getCachedUser() {
    final userStr = _preferences?.getString(keyCachedUser);
    if (userStr == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userStr));
    } catch (e) {
      return null;
    }
  }

  static bool get isRememberMe => _preferences?.getBool(keyRememberMe) ?? false;

  static String? get savedEmail => _preferences?.getString(keySavedEmail);

  static Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(keyCachedUser);
    await _ensureSaved(await prefs.remove(keyRememberMe));
    await _ensureSaved(await prefs.remove(keySavedEmail));
  }

  static Future<void> saveThemeMode(bool isDark) async {
    final prefs = await _prefs;
    await _ensureSaved(await prefs.setBool(keyIsDarkMode, isDark));
  }

  static bool get isDarkMode => _preferences?.getBool(keyIsDarkMode) ?? false;

  static Future<void> saveUserThemeMode(
    String uid,
    bool isDark, {
    String? email,
  }) async {
    final prefs = await _prefs;
    if (uid.isNotEmpty) {
      await _ensureSaved(
        await prefs.setBool('${_settingsPrefix}dark_mode_$uid', isDark),
      );
    }
    if (email != null && email.isNotEmpty) {
      final sanitizedEmail = email.toLowerCase().replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      await _ensureSaved(
        await prefs.setBool(
          '${_settingsPrefix}dark_mode_email_$sanitizedEmail',
          isDark,
        ),
      );
    }
    await _ensureSaved(await prefs.setBool(keyIsDarkMode, isDark));
  }

  static bool isUserDarkMode(String uid, {String? email}) {
    if (uid.isNotEmpty) {
      final byUid = _preferences?.getBool('${_settingsPrefix}dark_mode_$uid');
      if (byUid != null) return byUid;
    }
    if (email != null && email.isNotEmpty) {
      final sanitizedEmail = email.toLowerCase().replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final byEmail = _preferences?.getBool(
        '${_settingsPrefix}dark_mode_email_$sanitizedEmail',
      );
      if (byEmail != null) return byEmail;
    }
    if (uid.contains('admin') ||
        (email != null && email.toLowerCase().contains('admin'))) {
      final byAdmin = _preferences?.getBool(
        '${_settingsPrefix}dark_mode_admin_1',
      );
      if (byAdmin != null) return byAdmin;
    }
    return _preferences?.getBool(keyIsDarkMode) ?? false;
  }

  static Future<void> saveString(String key, String value) async {
    final prefs = await _prefs;
    await _ensureSaved(await prefs.setString('$_settingsPrefix$key', value));
  }

  static String? getString(String key) {
    return _preferences?.getString('$_settingsPrefix$key');
  }

  // =========================================================================
  // Local Cache & Offline Persistence
  // =========================================================================
  static const String _cachePrefix = 'cache.';

  /// Generic JSON caching
  static Future<void> saveJson(String key, dynamic data) async {
    try {
      final prefs = await _prefs;
      final jsonStr = jsonEncode(data);
      await prefs.setString('$_cachePrefix$key', jsonStr);
    } catch (e) {
      // Local cache write failure should not crash app
    }
  }

  /// Generic JSON retrieval
  static dynamic getJson(String key) {
    final jsonStr = _preferences?.getString('$_cachePrefix$key');
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      return null;
    }
  }

  /// Teacher Subjects cache
  static Future<void> saveTeacherSubjects(
    String teacherId,
    List<Map<String, dynamic>> subjects,
  ) async {
    await saveJson('teacher_subjects_$teacherId', subjects);
  }

  static List<Map<String, dynamic>> getTeacherSubjects(String teacherId) {
    final raw = getJson('teacher_subjects_$teacherId');
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static Future<void> saveGradebookSheet(
    String offeringId,
    int termNumber,
    Map<String, dynamic> payload,
  ) async {
    _validateGradebookKey(offeringId, termNumber);
    await saveJson('gradebook_${offeringId}_term_$termNumber', payload);
  }

  static Map<String, dynamic>? getGradebookSheet(
    String offeringId,
    int termNumber,
  ) {
    _validateGradebookKey(offeringId, termNumber);
    final raw = getJson('gradebook_${offeringId}_term_$termNumber');
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static Future<void> clearGradebookSheet(
    String offeringId,
    int termNumber,
  ) async {
    _validateGradebookKey(offeringId, termNumber);
    final prefs = await _prefs;
    await prefs.remove('${_cachePrefix}gradebook_${offeringId}_term_$termNumber');
  }

  static void _validateGradebookKey(String offeringId, int termNumber) {
    if (offeringId.trim().isEmpty) {
      throw ArgumentError.value(offeringId, 'offeringId', 'Must not be empty.');
    }
    if (termNumber < 1 || termNumber > 3) {
      throw ArgumentError.value(
        termNumber,
        'termNumber',
        'Must be 1, 2, or 3.',
      );
    }
  }

  /// Attendance Roster cache
  static Future<void> saveAttendanceRoster(
    String subjectOfferingId,
    List<Map<String, dynamic>> roster,
  ) async {
    await saveJson('attendance_roster_$subjectOfferingId', roster);
  }

  static List<Map<String, dynamic>> getAttendanceRoster(
    String subjectOfferingId,
  ) {
    final raw = getJson('attendance_roster_$subjectOfferingId');
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  /// Attendance Records cache
  static Future<void> saveAttendanceRecords(
    String subjectOfferingId,
    String date,
    List<Map<String, dynamic>> records,
  ) async {
    await saveJson('attendance_records_${subjectOfferingId}_$date', records);
  }

  static List<Map<String, dynamic>> getAttendanceRecords(
    String subjectOfferingId,
    String date,
  ) {
    final raw = getJson('attendance_records_${subjectOfferingId}_$date');
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  /// Offline attendance sync queue
  static Future<void> enqueueOfflineAttendance({
    required String subjectOfferingId,
    required String date,
    required List<Map<String, dynamic>> records,
  }) async {
    final queue = getOfflineAttendanceQueue();
    queue.removeWhere(
      (item) =>
          item['subject_offering_id'] == subjectOfferingId &&
          item['date'] == date,
    );
    queue.add({
      'id': '${subjectOfferingId}_$date',
      'subject_offering_id': subjectOfferingId,
      'date': date,
      'records': records,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await saveJson('offline_attendance_queue', queue);
  }

  static List<Map<String, dynamic>> getOfflineAttendanceQueue() {
    final raw = getJson('offline_attendance_queue');
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static Future<void> removeOfflineAttendance(String id) async {
    final queue = getOfflineAttendanceQueue();
    queue.removeWhere((item) => item['id'] == id);
    await saveJson('offline_attendance_queue', queue);
  }

  static Future<void> _ensureSaved(bool saved) async {
    if (!saved) {
      throw StateError('Failed to persist local preference.');
    }
  }
}
