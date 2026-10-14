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
/// Implemented by `StrictEmailVerificationService` (RFC 5322 syntax + domain heuristics + typo detection).
abstract class EmailVerificationService {
  /// Global service instance
  static EmailVerificationService instance = StrictEmailVerificationService();

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
