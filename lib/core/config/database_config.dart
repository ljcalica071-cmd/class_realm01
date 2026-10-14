/// ClassRealm — Backend & Database Configuration
/// Aligned with Master_Plan.md & Database_plan.md
///
/// Handles the hybrid setup:
/// 1. Firebase Auth (Authentication, Password Hashing, Session Management)
/// 2. Supabase PostgreSQL (Relational tables: users, teacher_profiles, student_profiles, subject_catalog)
/// 3. Email Verification API (syntax check, MX record lookup, deliverability validation)
library;

enum BackendMode {
  mock,
  hybridLive,
}

class DatabaseConfig {
  /// Current runtime mode: Default is `mock` for local prototype / panel demo.
  /// Switch to `hybridLive` when Firebase and Supabase credentials are configured.
  static BackendMode currentMode = BackendMode.mock;

  // --- SUPABASE POSTGRESQL CREDENTIALS (Database_plan.md) ---
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );

  // --- FIREBASE CREDENTIALS (Master_Plan.md Section 1.1) ---
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'classrealm-deped',
  );

  /// Helper to check if live database credentials are provided
  static bool get isLiveBackendConfigured =>
      supabaseUrl != 'https://your-project.supabase.co' &&
      supabaseAnonKey != 'your-anon-key-here';
}
