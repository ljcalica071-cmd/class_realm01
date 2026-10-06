import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Result returned by an email verification check.
class EmailVerificationResult {
  final bool isValid;
  final bool isDeliverable;
  final String? reason;

  const EmailVerificationResult({
    required this.isValid,
    this.isDeliverable = true,
    this.reason,
  });

  factory EmailVerificationResult.valid() =>
      const EmailVerificationResult(isValid: true);

  factory EmailVerificationResult.invalid(String reason) =>
      EmailVerificationResult(
        isValid: false,
        isDeliverable: false,
        reason: reason,
      );
}

/// Abstract contract for email verification.
/// Can be implemented by:
/// 1. `MockEmailVerificationService` (offline syntax + domain heuristic)
/// 2. `ApiEmailVerificationService` (external API such as Hunter.io, ZeroBounce, or Abstract API)
/// 3. `SupabaseEmailVerificationService` (direct Supabase Auth OTP verification)
abstract class EmailVerificationService {
  /// Global service instance
  static EmailVerificationService instance = ApiEmailVerificationService();

  Future<EmailVerificationResult> verifyEmail(String email);
}

/// In-memory / offline email verification service.
/// Validates RFC 5322 standard syntax, rejects disposable fake domains,
/// and prepares the system for seamless API integration.
class StrictEmailVerificationService implements EmailVerificationService {
  static final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  static const List<String> _disposableDomains = [
    'tempmail.com',
    'throwaway.com',
    'mailinator.com',
    '10minutemail.com',
    'guerrillamail.com',
    'sharklasers.com',
    'yopmail.com',
    'trashmail.com',
  ];

  static const Map<String, String> _commonTypos = {
    'gmal.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gimail.com': 'gmail.com',
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'yahho.com': 'yahoo.com',
    'yaho.com.ph': 'yahoo.com.ph',
    'hotmal.com': 'hotmail.com',
    'hotmai.com': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'outlook.con': 'outlook.com',
  };

  @override
  Future<EmailVerificationResult> verifyEmail(String email) async {
    final trimmed = email.trim().toLowerCase();

    if (trimmed.isEmpty) {
      return EmailVerificationResult.invalid('Email address cannot be empty.');
    }

    if (!_emailRegex.hasMatch(trimmed)) {
      return EmailVerificationResult.invalid(
        'Invalid email format. Please use user@domain.com.',
      );
    }

    final parts = trimmed.split('@');
    if (parts.length == 2) {
      final username = parts[0];
      if (username.length <= 1) {
        return EmailVerificationResult.invalid(
          'Invalid email format. Please check the spelling.',
        );
      }

      final domain = parts[1];

      if (_disposableDomains.contains(domain)) {
        return EmailVerificationResult.invalid(
          'Disposable and temporary email domains are not allowed. Please use your active email.',
        );
      }

      if (_commonTypos.containsKey(domain)) {
        final corrected = _commonTypos[domain];
        return EmailVerificationResult.invalid(
          'Did you mean @$corrected? The domain @$domain appears to be misspelled.',
        );
      }

      // Basic domain check to ensure it has at least a valid looking TLD
      if (!domain.contains('.') || domain.split('.').last.length < 2) {
        return EmailVerificationResult.invalid('Invalid email domain.');
      }
    }

    return EmailVerificationResult.valid();
  }
}

/// Modular HTTP Email Checker API implementation.
/// Currently configured for Abstract API, but easily swappable via .env.
class ApiEmailVerificationService implements EmailVerificationService {
  @override
  Future<EmailVerificationResult> verifyEmail(String email) async {
    final trimmed = email.trim().toLowerCase();

    // 1. Fast local regex check first before spending API credits
    final mockFallback = StrictEmailVerificationService();
    final localCheck = await mockFallback.verifyEmail(trimmed);
    if (!localCheck.isValid) {
      return localCheck;
    }

    final String? apiKey = dotenv.env['EMAIL_VALIDATION_API_KEY'];
    final String? apiEndpoint = dotenv.env['EMAIL_VALIDATION_API_URL'];

    // If API is not configured, fallback to valid to allow registration
    if (apiKey == null ||
        apiKey.isEmpty ||
        apiEndpoint == null ||
        apiEndpoint.isEmpty) {
      return EmailVerificationResult.valid();
    }

    try {
      // Endpoint logic for Abstract API: https://emailvalidation.abstractapi.com/v1/?api_key=...&email=...
      final uri = Uri.parse('$apiEndpoint?api_key=$apiKey&email=$trimmed');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Abstract API returns 'deliverability' string ('DELIVERABLE', 'UNDELIVERABLE', 'UNKNOWN')
        final deliverability = data['deliverability']?.toString().toUpperCase();

        if (deliverability == 'UNDELIVERABLE') {
          return EmailVerificationResult.invalid(
            'Invalid or non-existent email address.',
          );
        }

        return EmailVerificationResult.valid();
      } else {
        // Graceful fallback: If API limit is reached or server error occurs,
        // we allow the registration to proceed so the system is not blocked.
        print('Email API Error: ${response.statusCode} - ${response.body}');
        return EmailVerificationResult.valid();
      }
    } catch (e) {
      // Graceful fallback on CORS or network timeout errors
      print('Email API Network Error: $e');
      return EmailVerificationResult.valid();
    }
  }
}
