import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'sf2_save_outcome.dart';

Future<Sf2SaveOutcome> saveSf2CsvPlatform({
  required String fileName,
  required String csvContent,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(csvContent));
  try {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export DepEd SF2 Attendance Summary (CSV)',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );

    if (outputPath == null) {
      return const Sf2SaveOutcome(saved: false, cancelled: true);
    }

    if (outputPath.isNotEmpty &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final targetPath = outputPath.toLowerCase().endsWith('.csv')
          ? outputPath
          : '$outputPath.csv';
      final file = File(targetPath);
      await file.writeAsBytes(bytes, flush: true);
      return Sf2SaveOutcome(saved: true, locationLabel: targetPath);
    }

    return Sf2SaveOutcome(
      saved: true,
      locationLabel: outputPath.isNotEmpty ? outputPath : fileName,
    );
  } on MissingPluginException {
    await Clipboard.setData(ClipboardData(text: csvContent));
    return const Sf2SaveOutcome(
      saved: true,
      copiedToClipboard: true,
      locationLabel: 'System Clipboard',
    );
  } on UnimplementedError {
    await Clipboard.setData(ClipboardData(text: csvContent));
    return const Sf2SaveOutcome(
      saved: true,
      copiedToClipboard: true,
      locationLabel: 'System Clipboard',
    );
  }
}
