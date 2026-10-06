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

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get smtpEmail => dotenv.env['SMTP_EMAIL'] ?? '';
  static String get smtpPassword => dotenv.env['SMTP_PASSWORD'] ?? '';
}

