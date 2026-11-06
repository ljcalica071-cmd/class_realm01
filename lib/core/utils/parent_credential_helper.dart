/// Centralized helper for generating and formatting parent login credentials.
///
/// Format:
/// - Login Email: `[firstname].[lastname].cr@classrealm.com`
///   (or `[firstname].[lastname]2.cr@classrealm.com` on collision)
/// - Default / Reset Password: `[lastname][YYYYMMDD]` (e.g. `cruz19700101`)
class ParentCredentialHelper {
  ParentCredentialHelper._();

  static const String domain = 'classrealm.com';

  /// Returns `true` if the given [email] belongs to the `@classrealm.com` parent domain.
  static bool isParentDomain(String email) {
    final normalized = email.trim().toLowerCase();
    return normalized.endsWith('@$domain');
  }

  /// Sanitizes a name part for use in credentials:
  /// - Lowercases all characters
  /// - Replaces ñ/Ñ with n
  /// - Strips spaces, hyphens, apostrophes, and non-alphanumeric characters
  static String sanitizeNamePart(
    String rawName, {
    String fallback = 'parent',
  }) {
    final normalized = rawName
        .trim()
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.isEmpty ? fallback : normalized;
  }

  /// Sanitizes a last name for use in credentials.
  static String sanitizeLastName(String rawLastName) {
    return sanitizeNamePart(rawLastName, fallback: 'parent');
  }

  /// Generates the parent login email:
  /// - Default: `[firstname].[lastname].cr@classrealm.com` (e.g. `granny.cruz.cr@classrealm.com`)
  /// - On collision (`collisionIndex > 1`): `[firstname].[lastname][collisionIndex].cr@classrealm.com`
  static String generateEmail(
    String rawLastName, {
    String? rawFirstName,
    int collisionIndex = 1,
  }) {
    final first = (rawFirstName != null && rawFirstName.trim().isNotEmpty)
        ? sanitizeNamePart(rawFirstName, fallback: '')
        : '';
    final last = sanitizeLastName(rawLastName);
    final base = first.isNotEmpty ? '$first.$last' : last;
    if (collisionIndex <= 1) {
      return '$base.cr@$domain';
    }
    return '$base$collisionIndex.cr@$domain';
  }

  /// Generates the default temporary password: `[lastname][YYYYMMDD]`
  static String generateTempPassword(String rawLastName, DateTime birthday) {
    final base = sanitizeLastName(rawLastName);
    final yyyy = birthday.year.toString().padLeft(4, '0');
    final mm = birthday.month.toString().padLeft(2, '0');
    final dd = birthday.day.toString().padLeft(2, '0');
    return '$base$yyyy$mm$dd';
  }
}
