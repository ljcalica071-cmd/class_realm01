import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

class PhoneNfcService {
  PhoneNfcService._();
  static final PhoneNfcService instance = PhoneNfcService._();

  bool _isSessionActive = false;
  final Map<String, DateTime> _uidCooldownMap = {};
  static const Duration _cooldownDuration = Duration(milliseconds: 3000);

  /// Check if the current device has NFC hardware available
  Future<bool> isNfcAvailable() async {
    if (kIsWeb) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Start listening for an NFC tag/RFID card
  Future<void> startNfcCapture({
    required Function(String uid) onCardScanned,
    Function(String error)? onError,
  }) async {
    if (kIsWeb) {
      onError?.call('NFC is only supported on mobile devices.');
      return;
    }

    final available = await isNfcAvailable();
    if (!available) {
      onError?.call('NFC is not supported or is turned off on this phone.');
      return;
    }

    if (_isSessionActive) {
      await stopNfcCapture();
    }

    _isSessionActive = true;

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final rawData = _extractRawBytesFromTag(tag);
          if (rawData == null || rawData.isEmpty) {
            onError?.call('Could not read card UID.');
            return;
          }

          // Scenario 8: Detect randomized/rotating virtual UID from smartphones (Apple Pay / Google Wallet)
          if (rawData.length == 4 && rawData[0] == 0x08) {
            HapticFeedback.heavyImpact();
            onError?.call(
              'DYNAMIC_VIRTUAL_UID: Smartphone virtual wallet detected. Students must tap their physical school RFID card.',
            );
            return;
          }

          final uid = rawData
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join();

          // Scenario 14: Debounce card hovering against NFC coil (3000ms cooldown per UID)
          final now = DateTime.now();
          final lastScan = _uidCooldownMap[uid];
          if (lastScan != null &&
              now.difference(lastScan) < _cooldownDuration) {
            return;
          }
          _uidCooldownMap[uid] = now;

          HapticFeedback.mediumImpact();
          onCardScanned(uid);
        },
      );
    } catch (e) {
      _isSessionActive = false;
      onError?.call('NFC Session error: $e');
    }
  }

  /// Stop the active NFC session
  Future<void> stopNfcCapture() async {
    if (!_isSessionActive) return;
    _isSessionActive = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// Helper to extract raw byte identifier across Mifare, NfcA, NfcB, IsoDep, etc.
  List<int>? _extractRawBytesFromTag(NfcTag tag) {
    List<int>? identifier;

    final data = tag.data;
    if (data.containsKey('nfca')) {
      final nfca = data['nfca'] as Map<dynamic, dynamic>?;
      identifier = (nfca?['identifier'] as List<dynamic>?)?.cast<int>();
    } else if (data.containsKey('mifareclassic')) {
      final mifare = data['mifareclassic'] as Map<dynamic, dynamic>?;
      identifier = (mifare?['identifier'] as List<dynamic>?)?.cast<int>();
    } else if (data.containsKey('mifareultralight')) {
      final mifare = data['mifareultralight'] as Map<dynamic, dynamic>?;
      identifier = (mifare?['identifier'] as List<dynamic>?)?.cast<int>();
    } else if (data.containsKey('isodep')) {
      final isodep = data['isodep'] as Map<dynamic, dynamic>?;
      identifier = (isodep?['identifier'] as List<dynamic>?)?.cast<int>();
    } else if (data.containsKey('nfcb')) {
      final nfcb = data['nfcb'] as Map<dynamic, dynamic>?;
      identifier = (nfcb?['applicationData'] as List<dynamic>?)?.cast<int>();
    }

    return identifier;
  }
}
