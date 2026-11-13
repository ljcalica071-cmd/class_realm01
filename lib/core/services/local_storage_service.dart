import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/models/user_model.dart';

class LocalStorageService {
  static const String _authPrefix = 'auth.';
  static const String _settingsPrefix = 'settings.';
  static const String _rememberMeKey = '${_authPrefix}remember_me';
  static const String _savedEmailKey = '${_authPrefix}saved_email';
  static const String _savedPasswordKey = '${_authPrefix}saved_password';
  static const String _cachedUserKey = '${_authPrefix}cached_user';
  static const String _cachedUserSigKey = '${_authPrefix}cached_user_sig';
  static const String _darkModeKey = '${_settingsPrefix}is_dark_mode';
  static const String _deviceIdKey = 'classrealm_device_id';

  // Key Constants
  static const String keyRememberMe = _rememberMeKey;
  static const String keySavedEmail = _savedEmailKey;
  static const String keySavedPassword = _savedPasswordKey;
  static const String keyCachedUser = _cachedUserKey;
  static const String keyCachedUserSig = _cachedUserSigKey;
  static const String keyIsDarkMode = _darkModeKey;
  static const String keyDeviceId = _deviceIdKey;
  static const String keyAssessmentCreationCooldown =
      'cooldown.assessment_creation_ms';
  static const String keyAiAssessmentCooldown = 'cooldown.ai_assessment_gen_ms';

  static SharedPreferences? _preferences;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    // Clear legacy global keyIsDarkMode so all users strictly default to light mode
    await _preferences?.remove(keyIsDarkMode);
    // Purge any legacy plaintext passwords stored by older app versions
    await _preferences?.remove(keySavedPassword);
    final keys = _preferences?.getKeys().toList() ?? const <String>[];
    for (final k in keys) {
      if (k.startsWith(_savedCredPrefix)) {
        await _preferences?.remove(k);
      }
    }
  }

  static Future<SharedPreferences> get _prefs async {
    if (_preferences == null) {
      await init();
    }
    return _preferences!;
  }

  /// Permanent Device ID: Generated once as UUID v4 and persisted in local storage.
  /// Never removed on logout or clearAuth.
  static Future<String> getDeviceId() async {
    final prefs = await _prefs;
    String? deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = _generateUuidV4();
      await _ensureSaved(await prefs.setString(_deviceIdKey, deviceId));
    }
    return deviceId;
  }

  static String getSyncDeviceId() {
    String? deviceId = _preferences?.getString(_deviceIdKey);
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = _generateUuidV4();
      _preferences?.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Future<void> saveRememberMe(
    bool value,
    String email, {
    String? password,
  }) async {
    final prefs = await _prefs;
    // Never persist plaintext passwords in SharedPreferences / localStorage.
    await prefs.remove(keySavedPassword);
    if (value) {
      await _ensureSaved(await prefs.setString(keySavedEmail, email));
      await _ensureSaved(await prefs.setBool(keyRememberMe, true));
    } else {
      await _ensureSaved(await prefs.remove(keySavedEmail));
      await _ensureSaved(await prefs.setBool(keyRememberMe, false));
    }
  }

  static Future<void> updateSavedPasswordIfRemembered(
    String newPassword, {
    String? forEmail,
  }) async {
    final prefs = await _prefs;
    await prefs.remove(keySavedPassword);
  }

  static const String _savedCredPrefix = 'auth.saved_cred.';

  /// Checks if credentials have already been saved on this device for the given email.
  static bool hasSavedCredentials(String email, [String? password]) {
    final sanitizedEmail = email.trim().toLowerCase();
    return _preferences?.getBool('$_savedCredPrefix$sanitizedEmail') ?? false;
  }

  /// Marks credentials as saved on this device (boolean flag only, never plaintext password).
  static Future<void> markCredentialsSaved(
    String email, [
    String? password,
  ]) async {
    final sanitizedEmail = email.trim().toLowerCase();
    final prefs = await _prefs;
    await _ensureSaved(
      await prefs.setBool('$_savedCredPrefix$sanitizedEmail', true),
    );
  }

  /// Computes a deterministic tamper-detection signature bound to the user's critical
  /// authorization fields (`id`, `email`, `role`, `status`, `isArchived`, `linkedStudentId`)
  /// and the device ID so manual DevTools `localStorage` role escalation is rejected.
  static String _computeUserIntegritySignature(
    UserModel user,
    String deviceId,
  ) {
    final canonical = [
      'v1',
      deviceId.trim(),
      user.id.trim(),
      user.email.trim().toLowerCase(),
      user.role.name,
      user.status.name,
      user.isArchived ? '1' : '0',
      (user.linkedStudentId ?? '').trim(),
      (user.studentId ?? '').trim(),
    ].join('|');

    // Dual-lane 64-bit FNV-1a mix with internal salt for deterministic cross-platform integrity verification
    const String salt = 'ClassRealm::RBAC::IntegrityGuard::2026';
    final bytes = utf8.encode('$salt|$canonical|$salt');
    int h1 = 0x811c9dc5;
    int h2 = 0xcbf29ce4;
    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      h1 ^= b;
      h1 = (h1 * 0x01000193) & 0x7fffffff;
      h2 ^= (b ^ (i & 0xff));
      h2 = (h2 * 0x1000193) & 0x7fffffff;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
  }

  static Future<void> saveUser(UserModel user) async {
    final prefs = await _prefs;
    final deviceId = await getDeviceId();
    final userJson = jsonEncode(user.toJson());
    final sig = _computeUserIntegritySignature(user, deviceId);
    await _ensureSaved(await prefs.setString(keyCachedUser, userJson));
    await _ensureSaved(await prefs.setString(keyCachedUserSig, sig));
  }

  static UserModel? getCachedUser() {
    final userStr = _preferences?.getString(keyCachedUser);
    if (userStr == null) return null;
    try {
      final decoded = jsonDecode(userStr);
      if (decoded is! Map<String, dynamic>) {
        _preferences?.remove(keyCachedUser);
        _preferences?.remove(keyCachedUserSig);
        return null;
      }
      final rawRole = decoded['role']?.toString();
      final validRole = UserRole.values.any((e) => e.name == rawRole);
      if (!validRole) {
        _preferences?.remove(keyCachedUser);
        _preferences?.remove(keyCachedUserSig);
        return null;
      }

      final user = UserModel.fromJson(decoded);
      final storedSig = _preferences?.getString(keyCachedUserSig);
      final deviceId = getSyncDeviceId();
      final expectedSig = _computeUserIntegritySignature(user, deviceId);

      // Reject any cached user whose signature is missing or does not match
      // (e.g., if a user edited `role` or `id` in browser DevTools localStorage).
      if (storedSig == null || storedSig != expectedSig) {
        _preferences?.remove(keyCachedUser);
        _preferences?.remove(keyCachedUserSig);
        return null;
      }
      return user;
    } catch (e) {
      _preferences?.remove(keyCachedUser);
      _preferences?.remove(keyCachedUserSig);
      return null;
    }
  }

  static bool get isRememberMe => _preferences?.getBool(keyRememberMe) ?? false;

  static String? get savedEmail => _preferences?.getString(keySavedEmail);

  static String? get savedPassword => _preferences?.getString(keySavedPassword);

  static Future<void> clearCachedUser() async {
    final prefs = await _prefs;
    await _ensureSaved(await prefs.remove(keyCachedUser));
    await _ensureSaved(await prefs.remove(keyCachedUserSig));
  }

  static Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(keyCachedUser);
    await prefs.remove(keyCachedUserSig);
    await prefs.remove('session.active_id');
    await prefs.remove('session.login_at');
    await prefs.remove('session.last_interaction');
    await prefs.remove('session.last_active_route');
    await prefs.remove('session.tab_teacher');
    await prefs.remove('session.tab_admin');
    await prefs.remove('session.tab_student');
    await prefs.remove('session.tab_parent');
    await prefs.remove(keyAssessmentCreationCooldown);
    await prefs.remove(keyAiAssessmentCooldown);
    await _ensureSaved(await prefs.remove(keyRememberMe));
    await _ensureSaved(await prefs.remove(keySavedEmail));
    await _ensureSaved(await prefs.remove(keySavedPassword));
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
    // Default is strictly Light Mode (false) for every individual user
    return false;
  }

  // OTP Rate Limiting & Cooldown Lockout (10 minutes)
  static Future<void> setOtpLockout(String email, Duration duration) async {
    final cleanEmail = email.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    final unlockAt = DateTime.now().add(duration).millisecondsSinceEpoch;
    final prefs = await _prefs;
    await _ensureSaved(
      await prefs.setInt('${_authPrefix}otp_lockout_$cleanEmail', unlockAt),
    );
  }

  static Duration? getOtpLockoutRemaining(String email) {
    final cleanEmail = email.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    final unlockAt = _preferences?.getInt(
      '${_authPrefix}otp_lockout_$cleanEmail',
    );
    if (unlockAt == null) return null;
    final remainingMs = unlockAt - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      _preferences?.remove('${_authPrefix}otp_lockout_$cleanEmail');
      return null;
    }
    return Duration(milliseconds: remainingMs);
  }

  static Future<void> clearOtpLockout(String email) async {
    final cleanEmail = email.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    final prefs = await _prefs;
    await _ensureSaved(
      await prefs.remove('${_authPrefix}otp_lockout_$cleanEmail'),
    );
  }

  // Progressive Rate Limiting Attempts & Window Persistence
  static Future<void> saveLocalRateLimitState({
    required String scopeKey,
    required int failedAttempts,
    required DateTime windowStartedAt,
    int lockoutTier = 0,
    DateTime? tierEscalatedAt,
  }) async {
    final cleanKey = scopeKey.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    final prefs = await _prefs;
    await _ensureSaved(
      await prefs.setInt('${_authPrefix}rl_fails_$cleanKey', failedAttempts),
    );
    await _ensureSaved(
      await prefs.setInt(
        '${_authPrefix}rl_window_$cleanKey',
        windowStartedAt.millisecondsSinceEpoch,
      ),
    );
    await _ensureSaved(
      await prefs.setInt('${_authPrefix}rl_tier_$cleanKey', lockoutTier),
    );
    if (tierEscalatedAt != null) {
      await _ensureSaved(
        await prefs.setInt(
          '${_authPrefix}rl_tier_time_$cleanKey',
          tierEscalatedAt.millisecondsSinceEpoch,
        ),
      );
    }
  }

  static Map<String, dynamic>? getLocalRateLimitState(String scopeKey) {
    final cleanKey = scopeKey.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    final fails = _preferences?.getInt('${_authPrefix}rl_fails_$cleanKey');
    final windowMs = _preferences?.getInt('${_authPrefix}rl_window_$cleanKey');
    if (fails == null || windowMs == null) return null;

    final tier = _preferences?.getInt('${_authPrefix}rl_tier_$cleanKey') ?? 0;
    final tierTimeMs = _preferences?.getInt(
      '${_authPrefix}rl_tier_time_$cleanKey',
    );

    return {
      'failed_attempts': fails,
      'window_started_at': DateTime.fromMillisecondsSinceEpoch(
        windowMs,
        isUtc: true,
      ),
      'lockout_tier': tier,
      'tier_escalated_at': tierTimeMs != null
          ? DateTime.fromMillisecondsSinceEpoch(tierTimeMs, isUtc: true)
          : null,
    };
  }

  static Future<void> clearLocalRateLimitState(String scopeKey) async {
    final cleanKey = scopeKey.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    final prefs = await _prefs;
    await _ensureSaved(await prefs.remove('${_authPrefix}rl_fails_$cleanKey'));
    await _ensureSaved(await prefs.remove('${_authPrefix}rl_window_$cleanKey'));
    await _ensureSaved(await prefs.remove('${_authPrefix}rl_tier_$cleanKey'));
    await _ensureSaved(
      await prefs.remove('${_authPrefix}rl_tier_time_$cleanKey'),
    );
    await clearOtpLockout(scopeKey);
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

  /// Removes cached JSON entry
  static Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove('$_cachePrefix$key');
  }

  /// Removes all cached JSON entries starting with [prefix]
  static Future<void> removePrefix(String prefix) async {
    final prefs = await _prefs;
    final fullPrefix = '$_cachePrefix$prefix';
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(fullPrefix))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
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
    await prefs.remove(
      '${_cachePrefix}gradebook_${offeringId}_term_$termNumber',
    );
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

  static Future<void> saveLastInteraction(DateTime dt) async {
    final prefs = await _prefs;
    await prefs.setString('session.last_interaction', dt.toIso8601String());
  }

  static DateTime? getLastInteraction() {
    final str = _preferences?.getString('session.last_interaction');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static Future<void> saveActiveSessionId(String sessionId) async {
    final prefs = await _prefs;
    await prefs.setString('session.active_id', sessionId);
  }

  static String? getActiveSessionId() {
    return _preferences?.getString('session.active_id');
  }

  static Future<void> saveSessionLoginAt(DateTime dt) async {
    final prefs = await _prefs;
    await prefs.setString('session.login_at', dt.toUtc().toIso8601String());
  }

  static DateTime? getSessionLoginAt() {
    final str = _preferences?.getString('session.login_at');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static Future<void> clearActiveSessionId() async {
    final prefs = await _prefs;
    await prefs.remove('session.active_id');
    await prefs.remove('session.login_at');
    await prefs.remove('session.last_interaction');
  }

  static Future<void> savePendingHeartbeat(
    String sessionId,
    DateTime dt,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      'session.pending_heartbeat_$sessionId',
      dt.toIso8601String(),
    );
  }

  static Future<void> saveLastActiveRoute(String route) async {
    final prefs = await _prefs;
    await prefs.setString('session.last_active_route', route);
  }

  static String? getLastActiveRoute() {
    return _preferences?.getString('session.last_active_route');
  }

  static Future<void> saveActiveDashboardTab(String role, int index) async {
    final prefs = await _prefs;
    await prefs.setInt('session.tab_$role', index);
  }

  static int getActiveDashboardTab(String role) {
    return _preferences?.getInt('session.tab_$role') ?? 0;
  }

  // Teacher Classwork Sub-Navigation State (Category Tab, Filters, Opened Activity/Assessment)
  static Future<void> saveTeacherClassworkNavState({
    int? categoryTabIndex,
    int? gradeLevel,
    String? subjectName,
    String? sectionName,
    String? activeAssessmentId,
    String? activeActivityId,
    bool clearActiveAssessment = false,
    bool clearActiveActivity = false,
  }) async {
    try {
      final current = getTeacherClassworkNavState();
      if (categoryTabIndex != null) {
        current['categoryTabIndex'] = categoryTabIndex;
      }
      if (gradeLevel != null) {
        current['gradeLevel'] = gradeLevel;
      }
      if (subjectName != null) {
        current['subjectName'] = subjectName;
      }
      if (sectionName != null) {
        current['sectionName'] = sectionName;
      }
      if (clearActiveAssessment) {
        current.remove('activeAssessmentId');
      } else if (activeAssessmentId != null) {
        current['activeAssessmentId'] = activeAssessmentId;
        current.remove('activeActivityId');
      }
      if (clearActiveActivity) {
        current.remove('activeActivityId');
      } else if (activeActivityId != null) {
        current['activeActivityId'] = activeActivityId;
        current.remove('activeAssessmentId');
      }
      await saveJson('teacher_classwork_nav_state', current);
    } catch (_) {}
  }

  static Map<String, dynamic> getTeacherClassworkNavState() {
    final raw = getJson('teacher_classwork_nav_state');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  static Future<void> saveSelectedParentChildId(
    String parentId,
    String studentId,
  ) async {
    if (parentId.trim().isEmpty || studentId.trim().isEmpty) return;
    final prefs = await _prefs;
    await prefs.setString(
      '${_settingsPrefix}parent_active_child_${parentId.trim()}',
      studentId.trim(),
    );
  }

  static String? getSelectedParentChildId(String parentId) {
    if (parentId.trim().isEmpty) return null;
    return _preferences?.getString(
      '${_settingsPrefix}parent_active_child_${parentId.trim()}',
    );
  }

  static Future<void> saveStudentGradePrivacy(
    String studentId, {
    required bool hideTermGrades,
    required bool hideFinalGrades,
  }) async {
    if (studentId.trim().isEmpty) return;
    await saveJson('student_grade_privacy_${studentId.trim()}', {
      'hideTermGrades': hideTermGrades,
      'hideFinalGrades': hideFinalGrades,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static Map<String, bool>? getStudentGradePrivacy(String studentId) {
    if (studentId.trim().isEmpty) return null;
    final raw = getJson('student_grade_privacy_${studentId.trim()}');
    if (raw is Map) {
      return {
        'hideTermGrades': raw['hideTermGrades'] == true,
        'hideFinalGrades': raw['hideFinalGrades'] == true,
      };
    }
    return null;
  }

  static Future<void> setPushNotificationsEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(
      '${_settingsPrefix}push_notifications_enabled',
      enabled,
    );
  }

  static bool arePushNotificationsEnabled() {
    return _preferences?.getBool(
          '${_settingsPrefix}push_notifications_enabled',
        ) ??
        true;
  }

  // =========================================================================
  // System Maintenance Mode Offline Cache & Cooldown Persistence
  // =========================================================================
  static const String _maintenanceModeKey =
      '${_settingsPrefix}is_maintenance_mode';
  static const String _maintenanceCooldownKey =
      '${_settingsPrefix}maintenance_cooldown_until_ms';
  static const String _maintenanceForcedLogoutKey =
      '${_settingsPrefix}maintenance_forced_logout';

  static Future<void> saveMaintenanceMode(bool isMaintenance) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(_maintenanceModeKey, isMaintenance);
    } catch (_) {}
  }

  static bool get isMaintenanceMode =>
      _preferences?.getBool(_maintenanceModeKey) ?? false;

  static Future<void> saveMaintenanceForcedLogout(bool value) async {
    try {
      final prefs = await _prefs;
      if (value) {
        await prefs.setBool(_maintenanceForcedLogoutKey, true);
      } else {
        await prefs.remove(_maintenanceForcedLogoutKey);
      }
    } catch (_) {}
  }

  static bool get isMaintenanceForcedLogout =>
      _preferences?.getBool(_maintenanceForcedLogoutKey) ?? false;

  static Future<void> saveMaintenanceCooldownSeconds(
    int remainingSeconds,
  ) async {
    try {
      final prefs = await _prefs;
      if (remainingSeconds <= 0) {
        await prefs.remove(_maintenanceCooldownKey);
      } else {
        final unlockAtMs = DateTime.now()
            .add(Duration(seconds: remainingSeconds))
            .millisecondsSinceEpoch;
        await prefs.setInt(_maintenanceCooldownKey, unlockAtMs);
      }
    } catch (_) {}
  }

  static int getMaintenanceCooldownRemainingSeconds() {
    final unlockAtMs = _preferences?.getInt(_maintenanceCooldownKey);
    if (unlockAtMs == null) return 0;
    final remainingMs = unlockAtMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      _preferences?.remove(_maintenanceCooldownKey);
      return 0;
    }
    return (remainingMs / 1000).ceil();
  }

  /// Reads a stored cooldown trigger timestamp (epoch ms) synchronously.
  static int? getCooldownTimestampMs(String key) {
    return _preferences?.getInt(key);
  }

  /// Persists or clears a cooldown trigger timestamp (epoch ms).
  static void saveCooldownTimestampMs(String key, int? epochMs) {
    final prefs = _preferences;
    if (prefs == null) return;
    if (epochMs == null) {
      prefs.remove(key);
    } else {
      prefs.setInt(key, epochMs);
    }
  }

  static Future<void> _ensureSaved(bool saved) async {
    if (!saved) {
      throw StateError('Failed to persist local preference.');
    }
  }
}
