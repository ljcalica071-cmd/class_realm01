import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saves file bytes to native disk (Desktop & Mobile).
/// Uses FilePicker where available, or falls back to system Downloads folder.
Future<String?> saveBytesToNativeDisk({
  required Uint8List bytes,
  required String fileName,
  required String extension,
}) async {
  String? selectedPath;
  try {
    selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Learning Material',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
  } catch (_) {
    selectedPath = null;
  }

  if (selectedPath != null && selectedPath.trim().isNotEmpty) {
    final targetPath = selectedPath.toLowerCase().endsWith('.$extension')
        ? selectedPath
        : '$selectedPath.$extension';
    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  final userProfile =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (userProfile != null && userProfile.isNotEmpty) {
    final sep = Platform.pathSeparator;
    final downloadsDir = Directory('$userProfile${sep}Downloads');
    if (downloadsDir.existsSync()) {
      final target = File('${downloadsDir.path}$sep$fileName');
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    }
  }

  return null;
}
