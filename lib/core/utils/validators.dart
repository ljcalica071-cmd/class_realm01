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
      return 'Invalid email format. Please check the spelling.';
    }

    final parts = trimmed.split('@');
    if (parts.length == 2) {
      final username = parts[0];
      if (username.length <= 1) {
        return 'Invalid email format. Please check the spelling.';
      }

      final domainStr = parts[1];
      final domainParts = domainStr.split('.');
      
      if (domainParts.length < 2 || domainParts[0].length < 2) {
        return 'Invalid email domain. Domain name cannot be a single letter.';
      }

      final domainName = domainParts[0]; // e.g. "gamil"
      final tld = domainParts.sublist(1).join('.'); // e.g. "coms"

      // Disposable Domains
      const disposable = [
        'tempmail', 'throwaway', 'mailinator', '10minutemail',
        'guerrillamail', 'sharklasers', 'yopmail', 'trashmail'
      ];
      if (disposable.contains(domainName)) {
        return 'Disposable emails are not allowed.';
      }

      // Smart Typo Correction Dictionary
      const knownDomains = {
        'gmail': 'gmail', 'gmal': 'gmail', 'gamil': 'gmail', 'gmaill': 'gmail', 'gmai': 'gmail', 'gimail': 'gmail', 'gmil': 'gmail',
        'yahoo': 'yahoo', 'yaho': 'yahoo', 'yahooo': 'yahoo', 'yahho': 'yahoo',
        'hotmail': 'hotmail', 'hotmal': 'hotmail', 'hotmai': 'hotmail',
        'outlook': 'outlook', 'outlok': 'outlook'
      };

      const knownTlds = {
        'com': 'com', 'coms': 'com', 'con': 'com', 'coom': 'com', 'cmo': 'com',
        'ph': 'ph', 'com.ph': 'com.ph', 'edu.ph': 'edu.ph'
      };

      // Check if it's a known domain provider that has a typo
      final isKnownOrTypoDomain = knownDomains.containsKey(domainName);
      if (isKnownOrTypoDomain) {
        final correctDomainName = knownDomains[domainName]!;
        
        // If they used a weird TLD with a known domain, assume it's a typo of .com (or whatever default)
        final correctTld = knownTlds.containsKey(tld) ? knownTlds[tld]! : 'com';
        
        final correctedDomain = '$correctDomainName.$correctTld';
        
        if (domainStr != correctedDomain) {
          return 'Did you mean @$correctedDomain?';
        }
      }
      
      // If the domain is completely unknown, we allow it (could be deped.gov.ph or custom domain)
      // but we block obvious weird TLDs if they don't look standard.
      // (This is skipped for now to avoid false positives on legitimate school domains).
      
      const allowedDomains = [
        'lu.edu.ph', 'pup.edu.ph', 'ched.gov.ph', 'gmail.com', 'yahoo.com', 
        'outlook.com', 'hotmail.com', 'icloud.com', 'mail.com', 
        'rocketmail.com', 'msn.com', 'ymail.com', 'yahoo.com.ph'
      ];
      if (!allowedDomains.contains(domainStr)) {
        return 'Email domain @$domainStr is not allowed. Please use a recognized school or public email.';
      }
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
