import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

/// Global Stale-While-Revalidate (SWR) Application Data Cache.
///
/// Provides instant Frame-1 rendering from in-memory and persistent local storage,
/// while triggering silent background network synchronization and delivering fresh updates.
class AppDataCache {
  static final AppDataCache instance = AppDataCache._internal();
  AppDataCache._internal();

  final Map<String, dynamic> _memoryCache = <String, dynamic>{};

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
    try {
      await LocalStorageService.saveJson(key, jsonEncodableData);
    } catch (e) {
      debugPrint('AppDataCache setCache persistence notice: $e');
    }
  }

  /// Stale-While-Revalidate fetch helper:
  /// 1. Immediately triggers [onUpdate] if cached data is present (0ms UI latency).
  /// 2. Asynchronously fetches fresh data using [fetcher].
  /// 3. Saves fresh data to cache and invokes [onUpdate] if the payload changed.
  Future<T> fetchWithSvr<T>({
    required String cacheKey,
    required Future<T> Function() fetcher,
    required void Function(T freshData) onUpdate,
    T Function(dynamic json)? fromJson,
  }) async {
    // 1. Deliver Stale Data immediately if available
    if (fromJson != null) {
      final staleData = getCached<T>(cacheKey, fromJson);
      if (staleData != null) {
        try {
          onUpdate(staleData);
        } catch (e) {
          debugPrint('AppDataCache onUpdate stale delivery error: $e');
        }
      }
    }

    // 2. Fetch Fresh Data in background
    final freshData = await fetcher();

    // 3. Cache & deliver fresh data
    try {
      if (freshData is List || freshData is Map || freshData is num || freshData is String || freshData is bool) {
        unawaited(setCache(cacheKey, freshData));
      }
      onUpdate(freshData);
    } catch (e) {
      debugPrint('AppDataCache fresh data delivery error: $e');
    }

    return freshData;
  }

  /// Invalidates a specific cache key.
  void invalidate(String key) {
    _memoryCache.remove(key);
  }

  /// Clears user-specific cache upon logout.
  void clearUserCache(String userId) {
    final keysToRemove = _memoryCache.keys.where((k) => k.contains(userId)).toList();
    for (final k in keysToRemove) {
      _memoryCache.remove(k);
    }
  }

  /// Clears the entire in-memory cache.
  void clearAll() {
    _memoryCache.clear();
  }
}
