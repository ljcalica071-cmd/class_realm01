import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'sf2_save_outcome.dart';

Future<Sf2SaveOutcome> saveSf2CsvPlatform({
  required String fileName,
  required String csvContent,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(csvContent));
  try {
    await FilePicker.platform.saveFile(
      dialogTitle: 'Export DepEd SF2 Attendance Summary (CSV)',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );
    return Sf2SaveOutcome(saved: true, locationLabel: fileName);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: csvContent));
    return const Sf2SaveOutcome(
      saved: true,
      copiedToClipboard: true,
      locationLabel: 'System Clipboard',
    );
  }
}
