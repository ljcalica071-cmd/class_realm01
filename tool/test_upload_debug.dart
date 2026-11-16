import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://wfilyatkfgqtybujmahf.supabase.co';
const anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndmaWx5YXRrZmdxdHlidWptYWhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2NzQ0NjksImV4cCI6MjEwNjI1MDQ2OX0.YY6G7HJcXQX0PxrLC-IG__MT-ck8mSBzIX_8TvywkLM';

void main() async {
  try {
    print('Connecting to Supabase with ANON key...');
    final client = SupabaseClient(supabaseUrl, anonKey);

    final dummyPdfBytes = Uint8List.fromList([
      0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25,
      ...List.generate(100, (i) => i % 256),
    ]);

    final testPath = 'offerings/shared/test_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';

    print('Uploading to storage bucket learning_materials with ANON client...');
    final uploadRes = await client.storage.from('learning_materials').uploadBinary(
      testPath,
      dummyPdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true,
      ),
    );
    print('Storage upload SUCCESS: $uploadRes');

    final publicUrl = client.storage.from('learning_materials').getPublicUrl(testPath);
    print('Public URL: $publicUrl');

    print('Inserting into public.learning_materials with ANON client...');
    final insertRes = await client.from('learning_materials').insert({
      'folder_id': '79457fb6-1a7b-4aae-b5ba-ab47feeaa6d0',
      'file_name': 'test_debug.pdf',
      'storage_path_url': publicUrl,
      'mime_type': 'application/pdf',
      'file_size_bytes': dummyPdfBytes.length,
      'title': 'Test Debug PDF',
      'description': 'Automated test',
      'is_visible_to_students': true,
      'is_archived': false,
    }).select().single();

    print('Insert SUCCESS: $insertRes');

    // Clean up test row
    final id = insertRes['id'];
    await client.from('learning_materials').delete().eq('id', id);
    await client.storage.from('learning_materials').remove([testPath]);
    print('Cleanup complete.');

    exit(0);
  } catch (e, st) {
    print('TEST FAILED WITH ERROR: $e');
    print('STACK TRACE: $st');
    exit(1);
  }
}
