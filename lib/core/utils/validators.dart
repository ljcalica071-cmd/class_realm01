import 'package:flutter/services.dart';

class AppValidators {
  /// Reusable input formatters for name fields (max 30 chars, no consecutive spaces/periods, capitalize first letter)
  static List<TextInputFormatter> get nameFormatters => [
        LengthLimitingTextInputFormatter(30),
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]")),
        _CleanInputFormatter(),
      ];

  /// Name validator
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    if (value.trim().length < 2) {
      return 'Minimum 2 characters required.';
    }
    return null;
  }

  /// Email validator (Strict & Reusable across the system)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final trimmed = value.trim().toLowerCase();
    
    // Strict regex: basic format check
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9-]{2,}\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Invalid email';
    }

    return null;
  }
}

class _CleanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;

    if (text.isEmpty) return newValue;

    // Prevent leading spaces or periods
    if (text.startsWith(' ') || text.startsWith('.')) {
      return oldValue;
    }

    // Prevent consecutive spaces
    if (text.contains('  ')) {
      return oldValue;
    }

    // Prevent consecutive periods
    if (text.contains('..')) {
      return oldValue;
    }

    // Auto-capitalize the very first letter
    if (text.isNotEmpty) {
      text = text[0].toUpperCase() + text.substring(1);
    }

    return TextEditingValue(
      text: text,
      selection: newValue.selection,
    );
  }
}

extension BirthdayValidator on AppValidators {
  static String? validateBirthday(DateTime? date, String role) {
    if (date == null) return 'Birthdate is required.';

    final today = DateTime.now();
    int age = today.year - date.year;
    if (today.month < date.month || (today.month == date.month && today.day < date.day)) {
      age--;
    }

    if (date.year <= 1950) {
      return 'Birthdates from 1950 and below are not supported.';
    }

    if (role == 'teacher' || role == 'parent') {
      if (age < 18) return 'Must be at least 18 years old.';
    } else if (role == 'student') {
      if (age < 10) return 'Must be at least 10 years old.';
    }

    return null;
  }

  static DateTime getMinDate() {
    return DateTime(1951, 1, 1);
  }

  static DateTime getMaxDate(String role) {
    final now = DateTime.now();
    if (role == 'teacher' || role == 'parent') {
      return DateTime(now.year - 18, now.month, now.day);
    } else if (role == 'student') {
      return DateTime(now.year - 10, now.month, now.day);
    }
    return now;
  }
}
