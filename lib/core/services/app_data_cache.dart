import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

/// Global Smart Stale-While-Revalidate (SWR) Application Data Cache.
///
/// Features:
/// 1. Instant Frame-1 rendering from in-memory and persistent LocalStorage JSON.
/// 2. TTL Cooldown: zero network calls when switching tabs if data is still fresh (< 5 mins).
/// 3. In-Flight Request Deduplication: prevents multiple simultaneous requests for the same key.
/// 4. Payload Diffing: suppresses redundant UI re-renders if fetched data matches cached data.
/// 5. Mutation & Realtime Invalidation: clean `invalidatePrefix()` for instant freshness on user actions.
/// 6. Cross-platform Web & Native parity.
class AppDataCache {
  static final AppDataCache instance = AppDataCache._internal();
  AppDataCache._internal();

  final Map<String, dynamic> _memoryCache = <String, dynamic>{};
  final Map<String, DateTime> _timestamps = <String, DateTime>{};
  final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};
  final Map<String, String> _payloadSignatures = <String, String>{};

  /// Checks whether a cache key exists and is still within its freshness window (TTL).
  bool isFresh(String key, {Duration ttl = const Duration(minutes: 5)}) {
    if (!_memoryCache.containsKey(key)) return false;
    final ts = _timestamps[key];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < ttl;
  }

  /// Direct synchronous retrieval of in-memory cached object typed [T]
  T? get<T>(String key) {
    if (_memoryCache.containsKey(key)) {
      final item = _memoryCache[key];
      if (item is T) return item;
    }
    return null;
  }

  /// Sets an in-memory object directly
  void set<T>(String key, T value) {
    _memoryCache[key] = value;
    _timestamps[key] = DateTime.now();
  }

  /// Retrieves cached item typed [T] synchronously from in-memory cache or LocalStorage.
  T? getCached<T>(String key, T Function(dynamic json) fromJson) {
    if (_memoryCache.containsKey(key)) {
      try {
        final cached = _memoryCache[key];
        if (cached is T) return cached;
        return fromJson(cached);
      } catch (e) {
        debugPrint('AppDataCache memory deserialization error for $key: $e');
      }
    }

    // Fallback to persisted LocalStorage JSON
    try {
      final persistedJson = LocalStorageService.getJson(key);
      if (persistedJson != null) {
        _memoryCache[key] = persistedJson;
        _timestamps[key] ??= DateTime.now();
        return fromJson(persistedJson);
      }
    } catch (e) {
      debugPrint('AppDataCache disk deserialization error for $key: $e');
    }

    return null;
  }

  /// Sets or updates the cache both in memory and persistently in LocalStorage.
  Future<void> setCache(String key, dynamic jsonEncodableData) async {
    _memoryCache[key] = jsonEncodableData;
    _timestamps[key] = DateTime.now();
    try {
      _payloadSignatures[key] = jsonEncode(jsonEncodableData);
    } catch (_) {}

    try {
      await LocalStorageService.saveJson(key, jsonEncodableData);
    } catch (e) {
      debugPrint('AppDataCache setCache persistence notice: $e');
    }
  }

  /// Smart Stale-While-Revalidate fetch helper with TTL and In-Flight deduplication:
  /// 1. Immediately triggers [onUpdate] if cached data is present (0ms UI latency).
  /// 2. If data is still within [ttl] and [forceRefresh] is false, skips network request entirely.
  /// 3. If stale or expired, deduplicates in-flight calls and fetches fresh data in background.
  /// 4. Compares payload signature: invokes [onUpdate] only if fresh data differs from stale data.
  Future<T> fetchWithSvr<T>({
    String? cacheKey,
    String? key,
    required Future<T> Function() fetcher,
    void Function(T freshData)? onUpdate,
    T Function(dynamic json)? fromJson,
    dynamic Function(T data)? toJson,
    Duration ttl = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    final effectiveKey = cacheKey ?? key ?? '';

    // 1. Deliver Stale Data immediately if available (0ms UI latency)
    T? staleData;
    if (fromJson != null) {
      staleData = getCached<T>(effectiveKey, fromJson);
      if (staleData != null) {
        try {
          onUpdate?.call(staleData);
        } catch (e) {
          debugPrint('AppDataCache onUpdate stale delivery error: $e');
        }
      }
    } else if (_memoryCache.containsKey(effectiveKey) && _memoryCache[effectiveKey] is T) {
      staleData = _memoryCache[effectiveKey] as T;
      if (staleData != null) {
        try {
          onUpdate?.call(staleData);
        } catch (e) {
          debugPrint('AppDataCache onUpdate stale memory delivery error: $e');
        }
      }
    }

    // 2. Cooldown check: if fresh within TTL and not forceRefresh, return immediately
    if (!forceRefresh && isFresh(effectiveKey, ttl: ttl)) {
      if (staleData != null) return staleData;
      if (_memoryCache.containsKey(effectiveKey) && _memoryCache[effectiveKey] is T) {
        return _memoryCache[effectiveKey] as T;
      }
    }

    // 3. Deduplication: reuse in-flight future if already fetching this key
    if (_inFlight.containsKey(effectiveKey)) {
      try {
        final existing = await _inFlight[effectiveKey];
        if (existing is T) return existing;
      } catch (_) {}
    }

    // 4. Fetch Fresh Data in background
    final future = fetcher();
    _inFlight[effectiveKey] = future;

    try {
      final freshData = await future;
      _timestamps[effectiveKey] = DateTime.now();
      _memoryCache[effectiveKey] = freshData;

      // Encode for persistence & diffing
      dynamic encodable;
      if (toJson != null) {
        encodable = toJson(freshData);
      } else if (freshData is List || freshData is Map || freshData is num || freshData is String || freshData is bool) {
        encodable = freshData;
      }

      if (encodable != null) {
        String? newSig;
        try {
          newSig = jsonEncode(encodable);
        } catch (_) {}

        final oldSig = _payloadSignatures[effectiveKey];
        unawaited(setCache(effectiveKey, encodable));

        // Only invoke onUpdate if the data actually changed or if stale was absent
        if (staleData == null || oldSig == null || newSig == null || oldSig != newSig) {
          if (newSig != null) _payloadSignatures[effectiveKey] = newSig;
          try {
            onUpdate?.call(freshData);
          } catch (e) {
            debugPrint('AppDataCache fresh data delivery error: $e');
          }
        }
      } else {
        onUpdate?.call(freshData);
      }

      return freshData;
    } finally {
      _inFlight.remove(effectiveKey);
    }
  }

  /// Invalidates a specific cache key.
  void invalidate(String key) {
    _memoryCache.remove(key);
    _timestamps.remove(key);
    _payloadSignatures.remove(key);
    unawaited(LocalStorageService.remove(key));
  }

  /// Invalidates all keys starting with [prefix] (e.g. 'teacher_students_').
  void invalidatePrefix(String prefix) {
    final keysToRemove = _memoryCache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keysToRemove) {
      _memoryCache.remove(k);
      _timestamps.remove(k);
      _payloadSignatures.remove(k);
      unawaited(LocalStorageService.remove(k));
    }
  }

  /// Clears user-specific cache upon logout.
  void clearUserCache(String userId) {
    final keysToRemove = _memoryCache.keys.where((k) => k.contains(userId)).toList();
    for (final k in keysToRemove) {
      _memoryCache.remove(k);
      _timestamps.remove(k);
      _payloadSignatures.remove(k);
      unawaited(LocalStorageService.remove(k));
    }
  }

  /// Clears the entire in-memory cache and signatures.
  void clearAll() {
    _memoryCache.clear();
    _timestamps.clear();
    _inFlight.clear();
    _payloadSignatures.clear();
  }
}
