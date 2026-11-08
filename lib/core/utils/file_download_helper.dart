import 'package:flutter/foundation.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';

import 'file_download_helper_stub.dart'
    if (dart.library.io) 'file_download_helper_io.dart';

/// Cross-platform helper to download and save files on Web, Mobile, and Desktop.
class FileDownloadHelper {
  /// Downloads file bytes:
  /// - On Web: triggers browser download with `<a download>`
  /// - On Mobile/Desktop: saves to disk via FilePicker or Downloads directory
  static Future<String?> downloadBytes({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    String mimeType = 'application/octet-stream',
  }) async {
    if (kIsWeb) {
      downloadFileBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
      return 'Downloaded $fileName';
    }

    final savedPath = await saveBytesToNativeDisk(
      bytes: bytes,
      fileName: fileName,
      extension: extension,
    );
    return savedPath != null ? 'Saved to $savedPath' : 'Downloaded $fileName';
  }
}
