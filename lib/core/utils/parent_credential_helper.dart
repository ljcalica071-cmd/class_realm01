class ParentCredentialHelper {
  static const String domain = 'classrealm.com';

  /// Trims, converts to lowercase, replaces 'ñ'/'Ñ' with 'n', and removes all
  /// spaces and non-alphanumeric characters. Returns "parent" if empty.
  static String sanitizeLastName(String rawLastName) {
    final normalized = rawLastName
        .trim()
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.isEmpty ? 'parent' : normalized;
  }

  /// Generates the synthetic email for a parent account.
  /// If [collisionIndex] <= 1, returns '[sanitizedLastName]@classrealm.com'.
  /// If [collisionIndex] > 1, returns '[sanitizedLastName][collisionIndex]@classrealm.com'.
  static String generateEmail(String rawLastName, {int collisionIndex = 1}) {
    final base = sanitizeLastName(rawLastName);
    if (collisionIndex <= 1) {
      return '$base@$domain';
    }
    return '$base$collisionIndex@$domain';
  }

  /// Generates the default temporary password: '[sanitizedLastName][YYYYMMDD]'.
  static String generateTempPassword(String rawLastName, DateTime birthday) {
    final base = sanitizeLastName(rawLastName);
    final yyyy = birthday.year.toString().padLeft(4, '0');
    final mm = birthday.month.toString().padLeft(2, '0');
    final dd = birthday.day.toString().padLeft(2, '0');
    return '$base$yyyy$mm$dd';
  }

  /// Checks if an email ends with '@classrealm.com'.
  static bool isParentDomain(String email) {
    return email.trim().toLowerCase().endsWith('@$domain');
  }
}
