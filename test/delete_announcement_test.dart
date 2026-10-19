import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/config/env_config.dart';

void main() {
  test('delete announcement', () async {
    await EnvConfig.init();
    final client = SupabaseClient(EnvConfig.supabaseUrl, EnvConfig.supabaseAnonKey);
    await client.from('notifications').delete().eq('title', 'ccccccccccccccccccccccccc');
    print('Deleted announcement');
  });
}
