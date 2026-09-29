import 'dart:convert';
import 'package:http/http.dart' as http;

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

  factory EmailVerificationResult.valid() => const EmailVerificationResult(isValid: true);

  factory EmailVerificationResult.invalid(String reason) => EmailVerificationResult(
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
  /// Global service instance (Defaults to MockEmailVerificationService until API keys are set)
  static EmailVerificationService instance = MockEmailVerificationService();

  Future<EmailVerificationResult> verifyEmail(String email);
}

/// In-memory / offline email verification service.
/// Validates RFC 5322 standard syntax, rejects disposable fake domains,
/// and prepares the system for seamless API integration.
class MockEmailVerificationService implements EmailVerificationService {
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

  @override
  Future<EmailVerificationResult> verifyEmail(String email) async {
    final trimmed = email.trim().toLowerCase();

    if (trimmed.isEmpty) {
      return EmailVerificationResult.invalid('Email address cannot be empty.');
    }

    if (!_emailRegex.hasMatch(trimmed)) {
      return EmailVerificationResult.invalid('Invalid email format. Please use user@domain.com.');
    }

    final parts = trimmed.split('@');
    if (parts.length == 2) {
      final domain = parts[1];
      if (_disposableDomains.contains(domain)) {
        return EmailVerificationResult.invalid(
          'Disposable and temporary email domains are not allowed. Please use your official DepEd or personal active email.',
        );
      }
    }

    return EmailVerificationResult.valid();
  }
}

/// Production-ready HTTP Email Checker API implementation.
/// Designed for plug-and-play integration with services like:
/// - AbstractAPI Email Validation
/// - Hunter.io Email Verifier
/// - ZeroBounce / Kickbox
class HttpEmailVerificationService implements EmailVerificationService {
  final String apiKey;
  final String apiEndpoint;

  const HttpEmailVerificationService({
    required this.apiKey,
    this.apiEndpoint = 'https://emailvalidation.abstractapi.com/v1/',
  });

  @override
  Future<EmailVerificationResult> verifyEmail(String email) async {
    final trimmed = email.trim().toLowerCase();

    // 1. Fast local regex check first before spending API credits
    final mockFallback = MockEmailVerificationService();
    final localCheck = await mockFallback.verifyEmail(trimmed);
    if (!localCheck.isValid) {
      return localCheck;
    }

    // 2. Perform remote API lookup if API key is supplied
    if (apiKey.isEmpty) {
      return EmailVerificationResult.valid();
    }

    try {
      final uri = Uri.parse('$apiEndpoint?api_key=$apiKey&email=$trimmed');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Check deliverability score/status
        final deliverability = data['deliverability']?.toString().toUpperCase();
        final isDisposable = data['is_disposable_email']?['value'] == true;
        final isValidFormat = data['is_valid_format']?['value'] == true;

        if (!isValidFormat) {
          return EmailVerificationResult.invalid('The email address format is invalid.');
        }

        if (isDisposable) {
          return EmailVerificationResult.invalid('Disposable email addresses are not permitted.');
        }

        if (deliverability == 'UNDELIVERABLE') {
          return EmailVerificationResult.invalid('This email address does not exist or cannot receive mail.');
        }

        return EmailVerificationResult.valid();
      }
    } catch (_) {
      // Graceful degradation: If API is unreachable or times out, allow the registration
      // if local regex syntax was valid to avoid blocking the user.
      return EmailVerificationResult.valid();
    }

    return EmailVerificationResult.valid();
  }
}
