import 'package:flutter/foundation.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/ilaw_docx_exporter.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/ilaw_lesson_plan_validator.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/ilaw_pdf_exporter.dart';

import 'ilaw_file_saver_stub.dart'
    if (dart.library.io) 'ilaw_file_saver_io.dart';

enum IlawExportFormat { docx, pdf }

typedef IlawFileSaveHandler = Future<String> Function({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required String extension,
});

class IlawFileDownloader {
  static Future<String> exportAndDownload({
    required IlawLessonPlan plan,
    required IlawExportFormat format,
    IlawFileSaveHandler? customSaveHandler,
  }) async {
    final baseName = IlawLessonPlanValidator.sanitizeExportFileName(
      plan.subject,
      plan.topic,
    );

    final isDocx = format == IlawExportFormat.docx;
    final extension = isDocx ? 'docx' : 'pdf';
    final fileName = '$baseName.$extension';
    final mimeType = isDocx
        ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        : 'application/pdf';
    final bytes = isDocx
        ? IlawDocxExporter.generateBytes(plan)
        : IlawPdfExporter.generateBytes(plan);

    if (customSaveHandler != null) {
      return customSaveHandler(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        extension: extension,
      );
    }

    if (kIsWeb) {
      downloadFileBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
      return 'Downloaded $fileName';
    }

    final savedPath = await saveBytesToNativeDisk(
      bytes: bytes,
      fileName: fileName,
      extension: extension,
    );
    return savedPath != null ? 'Saved to $savedPath' : 'Exported $fileName';
  }
}
