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
}

