import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/config/env_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static SupabaseClient? _adminClient;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  SupabaseClient get adminClient {
    if (_adminClient != null) return _adminClient!;
    final serviceRoleKey = EnvConfig.supabaseServiceRoleKey;
    if (serviceRoleKey.isNotEmpty) {
      _adminClient = SupabaseClient(
        EnvConfig.supabaseUrl,
        serviceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      return _adminClient!;
    }
    return client;
  }
}
