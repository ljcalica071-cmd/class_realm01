import 'dart:typed_data';

/// Stub for native disk saving on web and unsupported platforms.
Future<String?> saveBytesToNativeDisk({
  required Uint8List bytes,
  required String fileName,
  required String extension,
}) async {
  return null;
}
