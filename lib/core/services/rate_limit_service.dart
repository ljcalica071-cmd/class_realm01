import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

/// Status model returned by RateLimitService
class RateLimitStatus {
  final bool isLocked;
  final int remainingSeconds;
  final int lockoutTier;
  final int failedAttempts;
  final int attemptsRemaining;
  final int resendCount;
  final String? message;
  final DateTime? lockedUntil;

  const RateLimitStatus({
    required this.isLocked,
    this.remainingSeconds = 0,
    this.lockoutTier = 0,
    this.failedAttempts = 0,
    this.attemptsRemaining = 5,
    this.resendCount = 0,
    this.message,
    this.lockedUntil,
  });

  String get formattedCountdown {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  factory RateLimitStatus.unlocked({
    int failedAttempts = 0,
    int maxAttempts = 5,
    int resendCount = 0,
  }) {
    return RateLimitStatus(
      isLocked: false,
      remainingSeconds: 0,
      lockoutTier: 0,
      failedAttempts: failedAttempts,
      attemptsRemaining: (maxAttempts - failedAttempts).clamp(0, maxAttempts),
      resendCount: resendCount,
    );
  }

  factory RateLimitStatus.locked({
    required int remainingSeconds,
    required int tier,
    required int failedAttempts,
    DateTime? lockedUntil,
  }) {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return RateLimitStatus(
      isLocked: true,
      remainingSeconds: remainingSeconds,
      lockoutTier: tier,
      failedAttempts: failedAttempts,
      attemptsRemaining: 0,
      lockedUntil: lockedUntil,
      message: 'Too many attempts. Locked out for $minutes:$seconds.',
    );
  }
}

/// Enterprise 4-Tier Progressive Rate Limiter & Cooldown Engine
/// Tier 1: 5 minutes (05:00)
/// Tier 2: 10 minutes (10:00)
/// Tier 3: 30 minutes (30:00)
/// Tier 4+: 1 hour (60:00) + audit_logs security entry
class RateLimitService {
  static final RateLimitService instance = RateLimitService._internal();
  RateLimitService._internal();

  SupabaseClient get _supabaseClient => Supabase.instance.client;

  // 4-Tier Lockout Durations
  static const Duration tier1Duration = Duration(minutes: 5);
  static const Duration tier2Duration = Duration(minutes: 10);
  static const Duration tier3Duration = Duration(minutes: 30);
  static const Duration tier4Duration = Duration(hours: 1);

  // Sliding window duration for counting failed attempts
  static const Duration slidingWindowDuration = Duration(minutes: 5);

  // Maximum time between lockouts before tier decays back to Tier 1
  static const Duration tierDecayDuration = Duration(hours: 1);

  Duration getDurationForTier(int tier) {
    switch (tier) {
      case 1:
        return tier1Duration;
      case 2:
        return tier2Duration;
      case 3:
        return tier3Duration;
      case 4:
      default:
        return tier4Duration;
    }
  }

  /// Builds a deterministic, device-isolated scope key: feature:device_id:target
  String buildScopeKey({
    required String feature,
    required String deviceId,
    required String targetIdentifier,
  }) {
    final cleanFeature = feature.trim().toLowerCase();
    final cleanDevice = deviceId.trim();
    final cleanTarget = targetIdentifier.trim().toLowerCase();

    if (cleanTarget.isEmpty || cleanTarget == 'device_only') {
      return '$cleanFeature:$cleanDevice';
    }
    return '$cleanFeature:$cleanDevice:$cleanTarget';
  }

  /// Check current lockout status for a feature & target
  Future<RateLimitStatus> checkStatus({
    required String feature,
    required String targetIdentifier,
    int maxAttempts = 5,
  }) async {
    final deviceId = await LocalStorageService.getDeviceId();
    final scopeKey = buildScopeKey(
      feature: feature,
      deviceId: deviceId,
      targetIdentifier: targetIdentifier,
    );

    final now = DateTime.now().toUtc();

    // 1. Fast local check first
    final localLockout = LocalStorageService.getOtpLockoutRemaining(scopeKey);
    if (localLockout != null && localLockout.inSeconds > 0) {
      return RateLimitStatus.locked(
        remainingSeconds: localLockout.inSeconds,
        tier: 1,
        failedAttempts: maxAttempts,
      );
    }

    // 2. Remote database lookup in auth_rate_limits
    try {
      final record = await _supabaseClient
          .from('auth_rate_limits')
          .select()
          .eq('scope_key', scopeKey)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (record != null) {
        final lockedUntilStr = record['locked_until']?.toString();
        if (lockedUntilStr != null && lockedUntilStr.isNotEmpty) {
          final lockedUntil = DateTime.tryParse(lockedUntilStr)?.toUtc();
          if (lockedUntil != null && now.isBefore(lockedUntil)) {
            final remainingSec = lockedUntil.difference(now).inSeconds;
            final tier = (record['lockout_tier'] as num?)?.toInt() ?? 1;
            final failed = (record['failed_attempts'] as num?)?.toInt() ?? maxAttempts;

            // Cache locally
            await LocalStorageService.setOtpLockout(scopeKey, Duration(seconds: remainingSec));

            return RateLimitStatus.locked(
              remainingSeconds: remainingSec,
              tier: tier,
              failedAttempts: failed,
              lockedUntil: lockedUntil,
            );
          }
        }

        // Check sliding window expiration
        final windowStartStr = record['window_started_at']?.toString();
        final windowStart = windowStartStr != null ? DateTime.tryParse(windowStartStr)?.toUtc() : null;
        int currentFailed = (record['failed_attempts'] as num?)?.toInt() ?? 0;
        int currentResend = (record['resend_count'] as num?)?.toInt() ?? 0;

        if (windowStart != null && now.difference(windowStart) > slidingWindowDuration) {
          currentFailed = 0;
        }

        return RateLimitStatus.unlocked(
          failedAttempts: currentFailed,
          maxAttempts: maxAttempts,
          resendCount: currentResend,
        );
      }
    } catch (e) {
      debugPrint('[RateLimitService] checkStatus query error: $e');
    }

    return RateLimitStatus.unlocked(
      failedAttempts: 0,
      maxAttempts: maxAttempts,
      resendCount: 0,
    );
  }

  /// Record a failed attempt (password or OTP).
  /// Enforces sliding window, triggers 4-tier progressive lockout when maxAttempts reached.
  Future<RateLimitStatus> recordFailure({
    required String feature,
    required String targetIdentifier,
    int maxAttempts = 5,
    String? userId,
  }) async {
    final deviceId = await LocalStorageService.getDeviceId();
    final scopeKey = buildScopeKey(
      feature: feature,
      deviceId: deviceId,
      targetIdentifier: targetIdentifier,
    );

    final now = DateTime.now().toUtc();

    // 1. Fetch current rate limit row
    Map<String, dynamic>? existing;
    try {
      existing = await _supabaseClient
          .from('auth_rate_limits')
          .select()
          .eq('scope_key', scopeKey)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[RateLimitService] recordFailure fetch notice: $e');
    }

    int currentTier = (existing?['lockout_tier'] as num?)?.toInt() ?? 0;
    int failedAttempts = (existing?['failed_attempts'] as num?)?.toInt() ?? 0;
    int resendCount = (existing?['resend_count'] as num?)?.toInt() ?? 0;
    DateTime windowStartedAt = existing?['window_started_at'] != null
        ? DateTime.tryParse(existing!['window_started_at'].toString())?.toUtc() ?? now
        : now;
    DateTime? tierEscalatedAt = existing?['tier_escalated_at'] != null
        ? DateTime.tryParse(existing!['tier_escalated_at'].toString())?.toUtc()
        : null;

    // Sliding window check: If > 5 minutes passed, reset attempts counter
    if (now.difference(windowStartedAt) > slidingWindowDuration) {
      failedAttempts = 1;
      windowStartedAt = now;
    } else {
      failedAttempts += 1;
    }

    // Check if lockout threshold reached
    if (failedAttempts >= maxAttempts) {
      // Tier escalation or decay:
      // If previous escalation was within 1 hour, escalate tier (1 -> 2 -> 3 -> 4).
      // Else, decay back to Tier 1.
      int nextTier;
      if (tierEscalatedAt != null && now.difference(tierEscalatedAt) <= tierDecayDuration) {
        nextTier = (currentTier + 1).clamp(1, 4);
      } else {
        nextTier = 1;
      }

      final lockoutDuration = getDurationForTier(nextTier);
      final lockedUntil = now.add(lockoutDuration);

      // Save to Supabase
      try {
        await _supabaseClient.from('auth_rate_limits').upsert({
          'scope_key': scopeKey,
          'feature': feature,
          'device_id': deviceId,
          'target_identifier': targetIdentifier.trim().toLowerCase(),
          'failed_attempts': failedAttempts,
          'resend_count': resendCount,
          'window_started_at': windowStartedAt.toIso8601String(),
          'lockout_tier': nextTier,
          'tier_escalated_at': now.toIso8601String(),
          'locked_until': lockedUntil.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('[RateLimitService] Supabase lockout upsert error: $e');
      }

      // Fast local storage cache
      await LocalStorageService.setOtpLockout(scopeKey, lockoutDuration);

      // If Tier 4+ reached, log a security warning in audit_logs if valid user_id known
      if (nextTier >= 4) {
        await _logSecurityWarningIfPossible(
          userId: userId,
          targetEmail: targetIdentifier,
          feature: feature,
          deviceId: deviceId,
        );
      }

      return RateLimitStatus.locked(
        remainingSeconds: lockoutDuration.inSeconds,
        tier: nextTier,
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
      );
    }

    // Still within attempts limit
    try {
      await _supabaseClient.from('auth_rate_limits').upsert({
        'scope_key': scopeKey,
        'feature': feature,
        'device_id': deviceId,
        'target_identifier': targetIdentifier.trim().toLowerCase(),
        'failed_attempts': failedAttempts,
        'resend_count': resendCount,
        'window_started_at': windowStartedAt.toIso8601String(),
        'lockout_tier': currentTier,
        'tier_escalated_at': tierEscalatedAt?.toIso8601String(),
        'locked_until': null,
        'updated_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[RateLimitService] Supabase attempt update error: $e');
    }

    return RateLimitStatus.unlocked(
      failedAttempts: failedAttempts,
      maxAttempts: maxAttempts,
      resendCount: resendCount,
    );
  }

  /// Record an OTP resend request.
  /// If resendCount >= maxResends (4), triggers 4-tier progressive lockout.
  Future<RateLimitStatus> recordResend({
    required String feature,
    required String targetIdentifier,
    int maxResends = 4,
    String? userId,
  }) async {
    final deviceId = await LocalStorageService.getDeviceId();
    final scopeKey = buildScopeKey(
      feature: feature,
      deviceId: deviceId,
      targetIdentifier: targetIdentifier,
    );

    final now = DateTime.now().toUtc();

    Map<String, dynamic>? existing;
    try {
      existing = await _supabaseClient
          .from('auth_rate_limits')
          .select()
          .eq('scope_key', scopeKey)
          .maybeSingle();
    } catch (_) {}

    int currentTier = (existing?['lockout_tier'] as num?)?.toInt() ?? 0;
    int resendCount = (existing?['resend_count'] as num?)?.toInt() ?? 0;
    int failedAttempts = (existing?['failed_attempts'] as num?)?.toInt() ?? 0;
    DateTime? tierEscalatedAt = existing?['tier_escalated_at'] != null
        ? DateTime.tryParse(existing!['tier_escalated_at'].toString())?.toUtc()
        : null;

    resendCount += 1;

    if (resendCount > maxResends) {
      int nextTier;
      if (tierEscalatedAt != null && now.difference(tierEscalatedAt) <= tierDecayDuration) {
        nextTier = (currentTier + 1).clamp(1, 4);
      } else {
        nextTier = 1;
      }

      final lockoutDuration = getDurationForTier(nextTier);
      final lockedUntil = now.add(lockoutDuration);

      try {
        await _supabaseClient.from('auth_rate_limits').upsert({
          'scope_key': scopeKey,
          'feature': feature,
          'device_id': deviceId,
          'target_identifier': targetIdentifier.trim().toLowerCase(),
          'failed_attempts': failedAttempts,
          'resend_count': resendCount,
          'lockout_tier': nextTier,
          'tier_escalated_at': now.toIso8601String(),
          'locked_until': lockedUntil.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } catch (_) {}

      await LocalStorageService.setOtpLockout(scopeKey, lockoutDuration);

      if (nextTier >= 4) {
        await _logSecurityWarningIfPossible(
          userId: userId,
          targetEmail: targetIdentifier,
          feature: feature,
          deviceId: deviceId,
        );
      }

      return RateLimitStatus.locked(
        remainingSeconds: lockoutDuration.inSeconds,
        tier: nextTier,
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
      );
    }

    try {
      await _supabaseClient.from('auth_rate_limits').upsert({
        'scope_key': scopeKey,
        'feature': feature,
        'device_id': deviceId,
        'target_identifier': targetIdentifier.trim().toLowerCase(),
        'failed_attempts': failedAttempts,
        'resend_count': resendCount,
        'lockout_tier': currentTier,
        'updated_at': now.toIso8601String(),
      });
    } catch (_) {}

    return RateLimitStatus.unlocked(
      failedAttempts: failedAttempts,
      resendCount: resendCount,
    );
  }

  /// Clears rate limits and unlocks upon successful authentication or verification
  Future<void> clearRateLimit({
    required String feature,
    required String targetIdentifier,
  }) async {
    final deviceId = await LocalStorageService.getDeviceId();
    final scopeKey = buildScopeKey(
      feature: feature,
      deviceId: deviceId,
      targetIdentifier: targetIdentifier,
    );

    // 1. Clear local cache
    await LocalStorageService.clearOtpLockout(scopeKey);

    // 2. Clear remote row or reset counters
    try {
      await _supabaseClient
          .from('auth_rate_limits')
          .delete()
          .eq('scope_key', scopeKey);
    } catch (e) {
      debugPrint('[RateLimitService] clearRateLimit notice: $e');
    }
  }

  /// Check admin operation cooldown (returns remaining seconds, 0 if not cooling down)
  Future<int> checkAdminCooldown({
    String? feature,
    String? actionKey,
    int? cooldownSeconds,
    String target = 'global',
  }) async {
    final feat = actionKey ?? feature ?? 'admin_action';
    final deviceId = await LocalStorageService.getDeviceId();
    final scopeKey = buildScopeKey(
      feature: feat,
      deviceId: deviceId,
      targetIdentifier: target,
    );

    final now = DateTime.now().toUtc();

    // Check fast local storage
    final localCooldown = LocalStorageService.getOtpLockoutRemaining('cd_$scopeKey');
    if (localCooldown != null && localCooldown.inSeconds > 0) {
      return localCooldown.inSeconds;
    }

    try {
      final record = await _supabaseClient
          .from('auth_rate_limits')
          .select('cooldown_until')
          .eq('scope_key', scopeKey)
          .maybeSingle();

      if (record != null) {
        final cdUntilStr = record['cooldown_until']?.toString();
        if (cdUntilStr != null && cdUntilStr.isNotEmpty) {
          final cdUntil = DateTime.tryParse(cdUntilStr)?.toUtc();
          if (cdUntil != null && now.isBefore(cdUntil)) {
            final diff = cdUntil.difference(now);
            await LocalStorageService.setOtpLockout('cd_$scopeKey', diff);
            return diff.inSeconds;
          }
        }
      }
    } catch (_) {}

    return 0;
  }

  /// Set admin operation cooldown
  Future<void> recordAdminCooldown({
    String? feature,
    String? actionKey,
    Duration? duration,
    int? cooldownSeconds,
    String target = 'global',
  }) async {
    final feat = actionKey ?? feature ?? 'admin_action';
    final dur = duration ?? Duration(seconds: cooldownSeconds ?? 30);
    final deviceId = await LocalStorageService.getDeviceId();
    final scopeKey = buildScopeKey(
      feature: feat,
      deviceId: deviceId,
      targetIdentifier: target,
    );

    final now = DateTime.now().toUtc();
    final cooldownUntil = now.add(dur);

    await LocalStorageService.setOtpLockout('cd_$scopeKey', dur);

    try {
      await _supabaseClient.from('auth_rate_limits').upsert({
        'scope_key': scopeKey,
        'feature': feat,
        'device_id': deviceId,
        'target_identifier': target.trim().toLowerCase(),
        'cooldown_until': cooldownUntil.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[RateLimitService] recordAdminCooldown notice: $e');
    }
  }

  /// Log security warning to public.audit_logs if a valid user_id is found
  Future<void> _logSecurityWarningIfPossible({
    String? userId,
    required String targetEmail,
    required String feature,
    required String deviceId,
  }) async {
    try {
      String? resolvedUserId = userId;
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        final cleanEmail = targetEmail.trim().toLowerCase();
        if (cleanEmail.isNotEmpty) {
          final userRecord = await _supabaseClient
              .from('users')
              .select('id')
              .eq('email', cleanEmail)
              .maybeSingle();
          resolvedUserId = userRecord?['id']?.toString();
        }
      }

      if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
        await _supabaseClient.from('audit_logs').insert({
          'user_id': resolvedUserId,
          'action_type': 'SECURITY_ALERT_TIER_4_LOCKOUT',
          'description': 'Security Alert: Progressive lockout escalated to Tier 4 (1-hour lockout) on device $deviceId for feature: $feature.',
          'logged_at': DateTime.now().toUtc().toIso8601String(),
        });
        debugPrint('[RateLimitService] Logged Tier 4 security alert in audit_logs for user $resolvedUserId');
      }
    } catch (e) {
      debugPrint('[RateLimitService] Audit log security alert notice: $e');
    }
  }
}
