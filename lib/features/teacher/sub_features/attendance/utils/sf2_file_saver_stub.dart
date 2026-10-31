import 'package:flutter/services.dart';
import 'sf2_save_outcome.dart';

Future<Sf2SaveOutcome> saveSf2CsvPlatform({
  required String fileName,
  required String csvContent,
}) async {
  await Clipboard.setData(ClipboardData(text: csvContent));
  return const Sf2SaveOutcome(
    saved: true,
    copiedToClipboard: true,
    locationLabel: 'System Clipboard',
  );
}
