import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DomainDeliverabilityResult {
  final bool isDeliverable;
  final String? error;

  const DomainDeliverabilityResult({required this.isDeliverable, this.error});
}

class AppValidators {
  static const String invalidMiddleInitialMessage =
      'Invalid format. Use 1 letter and 1 period only (e.g: H.)';
  static const String invalidBulkMiddleInitialMessage =
      'Invalid middle initial format (eg: H.)';
  static const String invalidExcelMiddleInitialMessage =
      'Use 1 letter and 1 period only (e.g., H.)';
  static final RegExp _middleInitialPattern = RegExp(r'^[a-zA-ZñÑ]\.$');

  /// Reusable input formatters for name fields (max 30 chars, no consecutive spaces/periods, capitalize first letter)
  static List<TextInputFormatter> get nameFormatters => [
    LengthLimitingTextInputFormatter(30),
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]")),
    _CleanInputFormatter(),
  ];

  /// Reusable input formatters for email fields (max 60 chars total, no spaces)
  static List<TextInputFormatter> get emailFormatters => [
    LengthLimitingTextInputFormatter(60),
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
  ];

  /// Reusable input formatters for password fields (max 50 chars, no leading space, no consecutive spaces, allows identical characters)
  static List<TextInputFormatter> get passwordFormatters => [
    LengthLimitingTextInputFormatter(50),
    _PasswordInputFormatter(),
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

  static String? validateMiddleInitial(String? value) {
    if (value == null || value.isEmpty) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || !_middleInitialPattern.hasMatch(trimmed)) {
      return invalidMiddleInitialMessage;
    }
    return null;
  }

  static String? normalizeMiddleInitial(String? value) {
    final validationError = validateMiddleInitial(value);
    if (validationError != null) {
      throw FormatException(validationError);
    }
    if (value == null || value.isEmpty) return null;
    return value.trim().toUpperCase();
  }

  static bool isMiddleInitialConstraintViolation(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('middle_initial_format_check') ||
        message.contains('middle initial format');
  }

  static String formatMiddleInitial(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    if (_middleInitialPattern.hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }
    return '${trimmed[0].toUpperCase()}.';
  }

  /// Email validator (Strict & Reusable across the system)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final trimmed = value.trim().toLowerCase();

    // Prevent spaces anywhere in email
    if (trimmed.contains(' ')) {
      return 'Email address cannot contain spaces.';
    }

    // Total email length constraint (Max 60 characters including name and domain)
    if (trimmed.length > 60) {
      return 'Email address cannot exceed 60 characters.';
    }

    // Must have exactly one '@' symbol
    final parts = trimmed.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email address with an @ symbol.';
    }

    final localPart = parts[0];
    final domainPart = parts[1];

    if (localPart.isEmpty) {
      return 'Email username is missing before @.';
    }

    if (domainPart.isEmpty) {
      return 'Email domain is missing after @.';
    }

    // Local part constraints: alphanumeric and standard allowed symbols, no double dots
    if (localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..')) {
      return 'Invalid email username format.';
    }

    // Domain part must contain at least one dot separating domain and TLD
    final domainParts = domainPart.split('.');
    if (domainParts.length < 2 || domainParts.any((part) => part.isEmpty)) {
      return 'Please enter a valid domain (e.g. gmail.com).';
    }

    final tld = domainParts.last;
    // TLD must only be letters and at least 2 characters (e.g. .com, .org, .edu, .ph)
    if (!RegExp(r'^[a-z]{2,24}$').hasMatch(tld)) {
      return 'Please enter a valid domain extension (e.g. .com, .edu.ph).';
    }

    // Common TLD typos
    const tldTypos = {
      'con': 'com',
      'cpm': 'com',
      'comm': 'com',
      'cm': 'com',
      'xom': 'com',
      'vom': 'com',
      'netw': 'net',
      'og': 'org',
      'ogr': 'org',
    };
    if (tldTypos.containsKey(tld)) {
      return 'Invalid domain extension .$tld. Did you mean .${tldTypos[tld]}?';
    }

    // Disallow truncated TLD typo (e.g., .co when user intended .com, unless country-code like co.uk / co.za)
    if (tld == 'co' &&
        domainParts.length == 2 &&
        (domainParts[0] == 'classrealm' ||
            domainParts[0] == 'gmail' ||
            domainParts[0] == 'yahoo' ||
            domainParts[0] == 'hotmail' ||
            domainParts[0] == 'outlook')) {
      return 'Did you mean @${domainParts[0]}.com? Please check domain extension.';
    }

    // Common email domain typos check
    const typoDomains = {
      'classreal.com': 'classrealm.com',
      'clasrealm.com': 'classrealm.com',
      'classrelm.com': 'classrealm.com',
      'classrealm.con': 'classrealm.com',
      'classrealm.co': 'classrealm.com',
      'clasreal.com': 'classrealm.com',
      'classreallm.com': 'classrealm.com',
      'classrealam.com': 'classrealm.com',
      'class-realm.com': 'classrealm.com',
      'gmsil.com': 'gmail.com',
      'gamil.com': 'gmail.com',
      'gmial.com': 'gmail.com',
      'gmai.com': 'gmail.com',
      'gmaill.com': 'gmail.com',
      'gmails.com': 'gmail.com',
      'gmails.con': 'gmail.com',
      'gmail.con': 'gmail.com',
      'gmeil.com': 'gmail.com',
      'gemail.com': 'gmail.com',
      'gmaul.com': 'gmail.com',
      'gmaol.com': 'gmail.com',
      'gmaik.com': 'gmail.com',
      'gmaip.com': 'gmail.com',
      'gnail.com': 'gmail.com',
      'gmal.com': 'gmail.com',
      'gamil.co': 'gmail.com',
      'gmail.co': 'gmail.com',
      'yaho.com': 'yahoo.com',
      'yahooo.com': 'yahoo.com',
      'yahoo.con': 'yahoo.com',
      'yhaoo.com': 'yahoo.com',
      'hotmial.com': 'hotmail.com',
      'hotmaill.com': 'hotmail.com',
      'outlok.com': 'outlook.com',
      'outloo.com': 'outlook.com',
    };

    if (typoDomains.containsKey(domainPart)) {
      final suggestion = typoDomains[domainPart];
      return 'Invalid domain. Did you mean @$suggestion?';
    }

    // Dynamic fuzzy typo check against major providers (Levenshtein distance <= 2)
    const majorProviders = [
      'classrealm.com',
      'gmail.com',
      'yahoo.com',
      'outlook.com',
      'hotmail.com',
      'icloud.com',
    ];

    if (!majorProviders.contains(domainPart)) {
      for (final provider in majorProviders) {
        if (_levenshtein(domainPart, provider) <= 2) {
          return 'Invalid domain. Did you mean @$provider?';
        }
      }
    }

    // Full standard RFC 5322 regex match
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
    );
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  /// Calculates Levenshtein distance between two strings
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  /// Real-time domain deliverability check using DNS-over-HTTPS (DoH).
  /// Verifies that the domain exists and has active MX records before dispatching verification codes.
  static Future<DomainDeliverabilityResult> checkDomainDeliverability(
    String email,
  ) async {
    final clean = email.trim().toLowerCase();
    final parts = clean.split('@');
    if (parts.length != 2) {
      return const DomainDeliverabilityResult(
        isDeliverable: false,
        error: 'Please enter a valid email address.',
      );
    }

    final domain = parts[1];

    // Basic domain sanity
    if (domain.length < 3 || !domain.contains('.')) {
      return DomainDeliverabilityResult(
        isDeliverable: false,
        error: "The email domain '$domain' is invalid.",
      );
    }

    // Fast check for known single-letter or non-resolving domains like a.com
    final domainParts = domain.split('.');
    if (domainParts[0].length <= 1 && domainParts.last == 'com') {
      return DomainDeliverabilityResult(
        isDeliverable: false,
        error:
            "The email domain '$domain' cannot receive emails (Address not found). Check for typos and try again.",
      );
    }

    // Known parked / squatter keywords to reject
    const parkedKeywords = [
      'catchall',
      'park',
      'sedo',
      'bodis',
      'above.com',
      'subdomain',
      'dan.com',
      'parking',
      'sinkhole',
      'blackhole',
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
    ];

    try {
      // 1. Query Google Public DNS over HTTPS for MX records
      final uri = Uri.parse(
        'https://dns.google/resolve?name=${Uri.encodeComponent(domain)}&type=MX',
      );
      final res = await http
          .get(uri)
          .timeout(const Duration(milliseconds: 3500));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final status = data['Status'] as int?;

        // Status 3 = NXDOMAIN (Non-Existent Domain)
        if (status == 3) {
          return DomainDeliverabilityResult(
            isDeliverable: false,
            error:
                "The email domain '$domain' does not exist (Address not found). Check for typos and try again.",
          );
        }

        final answers = data['Answer'] as List<dynamic>?;
        final mxRecords = answers?.where((a) => a['type'] == 15).toList() ?? [];

        if (mxRecords.isNotEmpty) {
          // Check for RFC 7505 Null MX and reject parked / squatter domains
          final validMx = mxRecords.where((r) {
            final dataStr = (r['data']?.toString().toLowerCase().trim() ?? '');
            if (dataStr.isEmpty || dataStr == '.' || dataStr == '0 .') {
              return false;
            }
            for (final kw in parkedKeywords) {
              if (dataStr.contains(kw)) return false;
            }
            return true;
          }).toList();

          if (validMx.isNotEmpty) {
            return const DomainDeliverabilityResult(isDeliverable: true);
          } else {
            return DomainDeliverabilityResult(
              isDeliverable: false,
              error:
                  "The email domain '$domain' cannot receive emails (Address not found). Check for typos and try again.",
            );
          }
        }

        // If Status == 0 but no MX records exist, check A record to verify if domain even exists
        final aUri = Uri.parse(
          'https://dns.google/resolve?name=${Uri.encodeComponent(domain)}&type=A',
        );
        final aRes = await http
            .get(aUri)
            .timeout(const Duration(milliseconds: 3000));
        if (aRes.statusCode == 200) {
          final aData = jsonDecode(aRes.body);
          if (aData['Status'] == 3) {
            return DomainDeliverabilityResult(
              isDeliverable: false,
              error:
                  "The email domain '$domain' does not exist (Address not found). Check for typos and try again.",
            );
          }
          final aAnswers = aData['Answer'] as List<dynamic>?;
          if (aAnswers == null || aAnswers.isEmpty) {
            return DomainDeliverabilityResult(
              isDeliverable: false,
              error:
                  "The email domain '$domain' has no mail servers configured to receive emails.",
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Deliverability] Google DoH notice: $e');
      // 2. Fallback to Cloudflare DNS over HTTPS
      try {
        final cfUri = Uri.parse(
          'https://cloudflare-dns.com/dns-query?name=${Uri.encodeComponent(domain)}&type=MX',
        );
        final cfRes = await http
            .get(cfUri, headers: {'Accept': 'application/dns-json'})
            .timeout(const Duration(milliseconds: 3000));
        if (cfRes.statusCode == 200) {
          final cfData = jsonDecode(cfRes.body);
          if (cfData['Status'] == 3) {
            return DomainDeliverabilityResult(
              isDeliverable: false,
              error:
                  "The email domain '$domain' does not exist (Address not found). Check for typos and try again.",
            );
          }
          final cfAnswers = cfData['Answer'] as List<dynamic>?;
          final cfMx = cfAnswers?.where((a) => a['type'] == 15).toList() ?? [];
          if (cfMx.isNotEmpty) {
            final validMx = cfMx.where((r) {
              final dataStr =
                  (r['data']?.toString().toLowerCase().trim() ?? '');
              if (dataStr.isEmpty || dataStr == '.' || dataStr == '0 .') {
                return false;
              }
              for (final kw in parkedKeywords) {
                if (dataStr.contains(kw)) return false;
              }
              return true;
            }).toList();
            if (validMx.isEmpty) {
              return DomainDeliverabilityResult(
                isDeliverable: false,
                error:
                    "The email domain '$domain' cannot receive emails (Address not found). Check for typos and try again.",
              );
            }
          }
        }
      } catch (cfErr) {
        debugPrint('[Deliverability] Cloudflare DoH notice: $cfErr');
      }
    }

    return const DomainDeliverabilityResult(isDeliverable: true);
  }

  /// Password complexity validator methods
  static bool hasMinLength(String? value, {int minLength = 8}) {
    if (value == null) return false;
    return value.length >= minLength;
  }

  static bool hasUppercase(String? value) {
    if (value == null) return false;
    return RegExp(r'[A-Z]').hasMatch(value);
  }

  static bool hasLowercase(String? value) {
    if (value == null) return false;
    return RegExp(r'[a-z]').hasMatch(value);
  }

  static bool hasNumber(String? value) {
    if (value == null) return false;
    return RegExp(r'[0-9]').hasMatch(value);
  }

  static bool passwordsMatch(String? password, String? confirmPassword) {
    if (password == null || confirmPassword == null) return false;
    if (password.isEmpty || confirmPassword.isEmpty) return false;
    return password == confirmPassword;
  }

  static PasswordValidationResult validatePasswordComplexity({
    required String? password,
    required String? confirmPassword,
  }) {
    final pwd = password ?? '';
    return PasswordValidationResult(
      hasMinLength: hasMinLength(pwd),
      hasUpper: hasUppercase(pwd),
      hasLower: hasLowercase(pwd),
      hasNumber: hasNumber(pwd),
      passwordsMatch: passwordsMatch(pwd, confirmPassword),
    );
  }
}

class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasUpper;
  final bool hasLower;
  final bool hasNumber;
  final bool passwordsMatch;

  const PasswordValidationResult({
    required this.hasMinLength,
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    required this.passwordsMatch,
  });

  bool get isValid =>
      hasMinLength && hasUpper && hasLower && hasNumber && passwordsMatch;
}

class _CleanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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

    return TextEditingValue(text: text, selection: newValue.selection);
  }
}

class _PasswordInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Prevent leading space
    if (text.startsWith(' ')) {
      return oldValue;
    }

    // Prevent consecutive spaces without deleting text
    if (text.contains('  ')) {
      return oldValue;
    }

    return newValue;
  }
}

extension BirthdayValidator on AppValidators {
  static String? validateBirthday(DateTime? date, String role) {
    if (date == null) return 'Birthdate is required.';

    final today = DateTime.now();
    int age = today.year - date.year;
    if (today.month < date.month ||
        (today.month == date.month && today.day < date.day)) {
      age--;
    }

    // Role-specific age logic
    if (role == 'teacher' || role == 'parent') {
      if (date.year <= 1950) {
        return 'Birthdates from 1950 and below are not supported.';
      }
      if (age < 18) return 'Must be at least 18 years old.';
    } else if (role == 'student') {
      if (age > 50) return 'Student cannot be older than 50 years old.';
      if (age < 10) return 'Must be at least 10 years old.';
    }

    return null;
  }

  static DateTime getMinDate([String role = '']) {
    final now = DateTime.now();
    if (role == 'student') {
      return DateTime(now.year - 50, now.month, now.day);
    }
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
