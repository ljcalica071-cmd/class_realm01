import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Warning: Could not load .env file ($e). Using fallback values.");
    }
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get smtpEmail => dotenv.env['SMTP_EMAIL'] ?? '';
  static String get smtpPassword => dotenv.env['SMTP_PASSWORD'] ?? '';

  // Firebase Environment Variables
  static String get firebaseWebApiKey => dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  static String get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseAuthDomain => dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get firebaseMeasurementId => dotenv.env['FIREBASE_MEASUREMENT_ID'] ?? '';

  static String get firebaseAndroidApiKey => dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? firebaseWebApiKey;
  static String get firebaseAndroidAppId => dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? firebaseAppId;
  static String get firebaseIosApiKey => dotenv.env['FIREBASE_IOS_API_KEY'] ?? firebaseWebApiKey;
  static String get firebaseIosAppId => dotenv.env['FIREBASE_IOS_APP_ID'] ?? firebaseAppId;

  static String get firebaseServiceAccountEmail => dotenv.env['FIREBASE_SERVICE_ACCOUNT_EMAIL'] ?? '';
  static String get firebaseServiceAccountPrivateKey => dotenv.env['FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY'] ?? '';

  static String get geminiApiKey => _safeEnv('GEMINI_API_KEY');
  static String get geminiApiKey1 => _safeEnv('GEMINI_API_KEY_1');
  static String get geminiApiKey2 => _safeEnv('GEMINI_API_KEY_2');
  static String get geminiApiKey3 => _safeEnv('GEMINI_API_KEY_3');

  /// Ordered, deduplicated Gemini API keys across 3 separate Google accounts
  /// (`GEMINI_API_KEY_1` -> `GEMINI_API_KEY_2` -> `GEMINI_API_KEY_3` -> `GEMINI_API_KEY`).
  static List<String> get geminiApiKeys {
    try {
      return extractValidGeminiKeys(dotenv.env);
    } catch (_) {
      return const [];
    }
  }

  static String _safeEnv(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  static List<String> extractValidGeminiKeys(Map<String, String> envMap) {
    final candidates = <String>[
      envMap['GEMINI_API_KEY_1'] ?? '',
      envMap['GEMINI_API_KEY_2'] ?? '',
      envMap['GEMINI_API_KEY_3'] ?? '',
      envMap['GEMINI_API_KEY'] ?? '',
      ...(envMap['GEMINI_API_KEYS'] ?? '').split(','),
    ];

    final seen = <String>{};
    final valid = <String>[];
    for (final raw in candidates) {
      var cleaned = raw.trim();
      if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
          (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
        cleaned = cleaned.substring(1, cleaned.length - 1).trim();
      }
      if (!_isUsableApiKey(cleaned)) continue;
      if (seen.add(cleaned)) {
        valid.add(cleaned);
      }
    }
    return valid;
  }

  static bool _isUsableApiKey(String value) {
    if (value.isEmpty || value.length < 8) return false;
    final upper = value.toUpperCase();
    if (upper == 'NULL' ||
        upper.contains('YOUR_API_KEY') ||
        upper.contains('PASTE_') ||
        upper.contains('REPLACE_ME') ||
        (value.startsWith('<') && value.endsWith('>'))) {
      return false;
    }
    return true;
  }
}
