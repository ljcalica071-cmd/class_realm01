import 'package:flutter/services.dart';

class StrictInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. If empty, allow it
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 2. Reject pure whitespaces or starting with whitespace (auto-trim leading)
    if (newValue.text.trim().isEmpty) {
      return oldValue; // Reject if it's all spaces
    }
    if (newValue.text.startsWith(' ')) {
      return TextEditingValue(
        text: newValue.text.trimLeft(),
        selection: TextSelection.collapsed(offset: newValue.text.trimLeft().length),
      );
    }

    // 3. Reject consecutive spaces
    if (newValue.text.contains('  ')) {
      return oldValue;
    }

    // 4. Reject special characters (Only allow letters, numbers, and single spaces)
    // You can adjust the regex depending on what special characters are allowed. 
    // Usually names can have hyphens, periods, or commas. Let's allow basic punctuation for profile fields: , . -
    final RegExp validPattern = RegExp(r'^[a-zA-Z0-9\s,\.\-\@\:]*$');
    if (!validPattern.hasMatch(newValue.text)) {
      return oldValue;
    }

    return newValue;
  }
}
