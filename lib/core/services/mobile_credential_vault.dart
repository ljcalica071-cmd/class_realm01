import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedLoginCredential {
  final String email;
  final String password;
  final String displayName;
  final String role;
  final DateTime updatedAt;

  const SavedLoginCredential({
    required this.email,
    required this.password,
    required this.displayName,
    required this.role,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'displayName': displayName,
    'role': role,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SavedLoginCredential.fromJson(Map<String, dynamic> json) {
    return SavedLoginCredential(
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Mobile-only (Android & iOS) encrypted credential vault backed by
/// Android Keystore / iOS Keychain via `flutter_secure_storage`.
/// Strictly a no-op on Web and Desktop so browser password managers stay untouched.
class MobileCredentialVault {
  MobileCredentialVault._();
  static final MobileCredentialVault instance = MobileCredentialVault._();

  static const String _storageKey = 'classrealm_mobile_saved_credentials_v1';
  static const int _maxSavedAccounts = 5;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Only active on Android and iOS mobile apps.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<List<SavedLoginCredential>> loadCredentials() async {
    if (!isSupported) return const [];
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = decoded
          .whereType<Map>()
          .map(
            (m) => SavedLoginCredential.fromJson(Map<String, dynamic>.from(m)),
          )
          .where((c) => c.email.trim().isNotEmpty && c.password.isNotEmpty)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    } catch (e) {
      debugPrint('MobileCredentialVault load notice: $e');
      return const [];
    }
  }

  Future<void> saveCredential(SavedLoginCredential credential) async {
    if (!isSupported) return;
    final normalizedEmail = credential.email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || credential.password.isEmpty) return;

    try {
      final existing = (await loadCredentials()).toList();
      existing.removeWhere(
        (c) => c.email.trim().toLowerCase() == normalizedEmail,
      );
      existing.insert(0, credential);
      final trimmed = existing.take(_maxSavedAccounts).toList();
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(trimmed.map((c) => c.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('MobileCredentialVault save notice: $e');
    }
  }

  Future<void> removeCredential(String email) async {
    if (!isSupported) return;
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final existing = (await loadCredentials()).toList();
      existing.removeWhere(
        (c) => c.email.trim().toLowerCase() == normalizedEmail,
      );
      if (existing.isEmpty) {
        await _storage.delete(key: _storageKey);
      } else {
        await _storage.write(
          key: _storageKey,
          value: jsonEncode(existing.map((c) => c.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('MobileCredentialVault remove notice: $e');
    }
  }

  SavedLoginCredential? findByEmail(
    List<SavedLoginCredential> list,
    String email,
  ) {
    final normalized = email.trim().toLowerCase();
    for (final item in list) {
      if (item.email.trim().toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
  }
}
