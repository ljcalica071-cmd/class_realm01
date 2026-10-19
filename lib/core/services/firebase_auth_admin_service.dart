import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:class_realm/core/config/env_config.dart';

class FirebaseAuthAdminService {
  static String? _cachedAccessToken;
  static DateTime? _tokenExpiry;

  /// Deletes a user permanently from Firebase Authentication by UID
  static Future<bool> deleteUser({
    required String uid,
    String? email,
    String? tempPassword,
  }) async {
    try {
      // 1. Primary: Try Google Identity Platform batchDelete via Service Account OAuth2
      final token = await _getAccessToken();
      if (token != null && token.isNotEmpty) {
        final projectId = EnvConfig.firebaseProjectId;
        final res = await http.post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:batchDelete'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'localIds': [uid],
          }),
        );
        if (res.statusCode == 200) {
          debugPrint('FirebaseAuthAdminService: Successfully deleted user $uid via Service Account.');
          return true;
        } else {
          debugPrint('FirebaseAuthAdminService: batchDelete returned ${res.statusCode}: ${res.body}');
        }
      }

      // 2. Fallback: If user is in first login / pending status with temporary password
      if (email != null && tempPassword != null && tempPassword.isNotEmpty) {
        final apiKey = EnvConfig.firebaseWebApiKey;
        final signRes = await http.post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': tempPassword,
            'returnSecureToken': true,
          }),
        );

        if (signRes.statusCode == 200) {
          final data = jsonDecode(signRes.body);
          final idToken = data['idToken']?.toString();
          if (idToken != null) {
            final delRes = await http.post(
              Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'idToken': idToken}),
            );
            if (delRes.statusCode == 200) {
              debugPrint('FirebaseAuthAdminService: Successfully deleted user $uid via fallback temp password.');
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('FirebaseAuthAdminService deleteUser error: $e');
    }
    return false;
  }

  /// Sets user disabled status in Firebase Auth (for Archive / Unarchive)
  static Future<bool> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    try {
      final token = await _getAccessToken();
      if (token != null && token.isNotEmpty) {
        final projectId = EnvConfig.firebaseProjectId;
        final res = await http.post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:update'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'localId': uid,
            'disableUser': disabled,
          }),
        );
        return res.statusCode == 200;
      }
    } catch (e) {
      debugPrint('FirebaseAuthAdminService setUserDisabled error: $e');
    }
    return false;
  }

  /// Obtains Google OAuth 2.0 Access Token from Service Account credentials
  static Future<String?> _getAccessToken() async {
    final now = DateTime.now();
    if (_cachedAccessToken != null && _tokenExpiry != null && now.isBefore(_tokenExpiry!)) {
      return _cachedAccessToken;
    }

    final clientEmail = EnvConfig.firebaseServiceAccountEmail;
    final privateKeyPem = EnvConfig.firebaseServiceAccountPrivateKey;

    if (clientEmail.isEmpty || privateKeyPem.isEmpty) {
      return null;
    }

    try {
      final jwt = _createServiceAccountJwt(clientEmail, privateKeyPem);
      final res = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': jwt,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['access_token']?.toString();
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        _cachedAccessToken = token;
        _tokenExpiry = now.add(Duration(seconds: expiresIn - 120));
        return token;
      } else {
        debugPrint('OAuth2 token exchange returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('Error generating Google OAuth2 token: $e');
    }
    return null;
  }

  /// Creates signed JWT for Google OAuth2 using pure Dart RSA PKCS#1 v1.5
  static String _createServiceAccountJwt(String clientEmail, String privateKeyPem) {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expSec = nowSec + 3600;

    final header = {'alg': 'RS256', 'typ': 'JWT'};
    final claims = {
      'iss': clientEmail,
      'scope': 'https://www.googleapis.com/auth/identitytoolkit https://www.googleapis.com/auth/cloud-platform',
      'aud': 'https://oauth2.googleapis.com/token',
      'exp': expSec,
      'iat': nowSec,
    };

    final headerB64 = _base64UrlNoPad(utf8.encode(jsonEncode(header)));
    final claimsB64 = _base64UrlNoPad(utf8.encode(jsonEncode(claims)));
    final unsignedToken = '$headerB64.$claimsB64';

    final signature = _signRs256(utf8.encode(unsignedToken), privateKeyPem);
    final sigB64 = _base64UrlNoPad(signature);

    return '$unsignedToken.$sigB64';
  }

  static String _base64UrlNoPad(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Signs input bytes using pure Dart RSA PKCS#1 v1.5 with SHA-256
  static Uint8List _signRs256(List<int> message, String privateKeyPem) {
    final rsaKey = _parsePkcs8OrPkcs1PrivateKey(privateKeyPem);
    final n = rsaKey['modulus']!;
    final d = rsaKey['privateExponent']!;

    // 1. Compute SHA-256 hash of message
    final hash = _sha256(Uint8List.fromList(message));

    // 2. PKCS#1 v1.5 DigestInfo for SHA-256
    const digestInfoPrefix = [
      0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20
    ];
    final digestInfo = <int>[...digestInfoPrefix, ...hash];

    // 3. Construct PKCS#1 v1.5 padded block (256 bytes for 2048-bit key)
    final keyBytes = (n.bitLength + 7) ~/ 8;
    final padLen = keyBytes - 3 - digestInfo.length;
    if (padLen < 8) throw Exception('RSA key too short for PKCS#1 v1.5 padding');

    final em = Uint8List(keyBytes);
    em[0] = 0x00;
    em[1] = 0x01;
    for (int i = 0; i < padLen; i++) {
      em[2 + i] = 0xFF;
    }
    em[2 + padLen] = 0x00;
    em.setRange(keyBytes - digestInfo.length, keyBytes, digestInfo);

    // 4. Compute RSA modular exponentiation: s = m^d mod n
    final m = _bytesToBigInt(em);
    final s = m.modPow(d, n);

    return _bigIntToBytes(s, keyBytes);
  }

  /// Pure Dart SHA-256 implementation (FIPS 180-4 standard)
  static Uint8List _sha256(Uint8List data) {
    final k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    int h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    int h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

    final bitLen = data.length * 8;
    final padLen = (data.length + 9) % 64 == 0 ? 0 : 64 - ((data.length + 9) % 64);
    final totalLen = data.length + 1 + padLen + 8;
    final padded = Uint8List(totalLen);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;

    for (int i = 0; i < 8; i++) {
      padded[totalLen - 1 - i] = (bitLen >> (i * 8)) & 0xFF;
    }

    final w = List<int>.filled(64, 0);

    for (int chunk = 0; chunk < totalLen; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        final pos = chunk + i * 4;
        w[i] = (padded[pos] << 24) | (padded[pos + 1] << 16) | (padded[pos + 2] << 8) | padded[pos + 3];
      }
      for (int i = 16; i < 64; i++) {
        final s0 = _rotr32(w[i - 15], 7) ^ _rotr32(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 = _rotr32(w[i - 2], 17) ^ _rotr32(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

      for (int i = 0; i < 64; i++) {
        final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = Uint8List(32);
    final values = [h0, h1, h2, h3, h4, h5, h6, h7];
    for (int i = 0; i < 8; i++) {
      out[i * 4] = (values[i] >> 24) & 0xFF;
      out[i * 4 + 1] = (values[i] >> 16) & 0xFF;
      out[i * 4 + 2] = (values[i] >> 8) & 0xFF;
      out[i * 4 + 3] = values[i] & 0xFF;
    }
    return out;
  }

  static int _rotr32(int val, int count) {
    return ((val >>> count) | (val << (32 - count))) & 0xFFFFFFFF;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt number, int length) {
    final result = Uint8List(length);
    BigInt cur = number;
    for (int i = length - 1; i >= 0; i--) {
      result[i] = (cur & BigInt.from(0xFF)).toInt();
      cur = cur >> 8;
    }
    return result;
  }

  /// Parses PKCS#8 or PKCS#1 RSA private key PEM into modulus and privateExponent
  static Map<String, BigInt> _parsePkcs8OrPkcs1PrivateKey(String pem) {
    final clean = pem
        .replaceAll(RegExp(r'-----BEGIN [A-Z ]+-----'), '')
        .replaceAll(RegExp(r'-----END [A-Z ]+-----'), '')
        .replaceAll(RegExp(r'\s+'), '');
    final der = base64Decode(clean);

    // Simple ASN.1 DER parser for RSA Private Key
    int offset = 0;

    int readLength() {
      int b = der[offset++];
      if (b < 0x80) return b;
      int numBytes = b & 0x7F;
      int len = 0;
      for (int i = 0; i < numBytes; i++) {
        len = (len << 8) | der[offset++];
      }
      return len;
    }

    // Read outer SEQUENCE
    if (der[offset++] != 0x30) throw Exception('Invalid ASN.1');
    readLength();

    // Check version
    if (der[offset++] != 0x02) throw Exception('Invalid ASN.1 Version');
    int vLen = readLength();
    offset += vLen;

    // Check if PKCS#8 (has algorithm identifier sequence)
    if (der[offset] == 0x30) {
      offset++;
      int algLen = readLength();
      offset += algLen;

      // Octet string containing PKCS#1 RSAPrivateKey
      if (der[offset++] != 0x04) throw Exception('Expected OCTET STRING in PKCS#8');
      readLength();

      // Inside PKCS#1: SEQUENCE
      if (der[offset++] != 0x30) throw Exception('Expected SEQUENCE inside OCTET STRING');
      readLength();

      // Version inside PKCS#1
      if (der[offset++] != 0x02) throw Exception('Expected version inside PKCS#1');
      offset += readLength();
    }

    // Modulus (n)
    if (der[offset++] != 0x02) throw Exception('Expected INTEGER for modulus');
    int modLen = readLength();
    final modBytes = der.sublist(offset, offset + modLen);
    offset += modLen;
    final modulus = _bytesToBigInt(modBytes);

    // Public exponent (e)
    if (der[offset++] != 0x02) throw Exception('Expected INTEGER for public exponent');
    int pubLen = readLength();
    offset += pubLen;

    // Private exponent (d)
    if (der[offset++] != 0x02) throw Exception('Expected INTEGER for private exponent');
    int privLen = readLength();
    final privBytes = der.sublist(offset, offset + privLen);
    final privateExponent = _bytesToBigInt(privBytes);

    return {
      'modulus': modulus,
      'privateExponent': privateExponent,
    };
  }
}
