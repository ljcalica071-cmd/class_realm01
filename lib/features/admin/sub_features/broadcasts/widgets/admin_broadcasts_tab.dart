import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/core/services/rate_limit_service.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

class AdminBroadcastsTab extends StatefulWidget {
  const AdminBroadcastsTab({super.key});

  @override
  State<AdminBroadcastsTab> createState() => _AdminBroadcastsTabState();
}

class _AdminBroadcastsTabState extends State<AdminBroadcastsTab> {
  // Maintenance State
  bool _isMaintenanceMode = false;
  bool _isTogglingMaintenance = false;
  int _cooldownRemainingSeconds = 0;
  Timer? _cooldownTimer;
  static const int _maintenanceCooldownSeconds = 600; // 10 minutes

  // Announcement Composer State
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedAudience = 'all'; // 'all', 'teachers', 'students_parents'
  bool _isSubmittingAnnouncement = false;
  String? _titleError;
  String? _messageError;

  // Active User Counts by Role (excluding archived users)
  Map<String, int> _userCounts = {
    'teachers': 0,
    'students': 0,
    'parents': 0,
    'total': 0,
  };

  // Broadcast History State
  List<AppNotificationModel> _broadcasts = [];
  bool _isLoadingBroadcasts = true;
  bool _isInitialLoading = true;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToRealtime();
    _messageController.addListener(() {
      if (_messageError != null) {
        setState(() => _messageError = null);
      } else {
        setState(() {});
      }
    });
    _titleController.addListener(() {
      if (_titleError != null) {
        setState(() => _titleError = null);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _titleController.dispose();
    _messageController.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    if (seconds <= 0) {
      if (mounted) {
        setState(() => _cooldownRemainingSeconds = 0);
      }
      return;
    }
    final endTime = DateTime.now().add(Duration(seconds: seconds));
    if (mounted) {
      setState(() => _cooldownRemainingSeconds = seconds);
    }
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = endTime.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _cooldownRemainingSeconds = 0);
      } else {
        setState(() => _cooldownRemainingSeconds = remaining);
      }
    });
  }

  String _formatCooldown(int totalSeconds) {
    final clamped = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = (clamped ~/ 60).toString().padLeft(2, '0');
    final seconds = (clamped % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _subscribeToRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin_broadcasts_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'system_settings',
          callback: (_) => _loadMaintenanceState(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _loadBroadcastHistory(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (_) => _loadUserCounts(),
        )
        .subscribe();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadMaintenanceState(),
      _loadBroadcastHistory(),
      _loadUserCounts(),
    ]);
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadUserCounts() async {
    final counts = await AdminRepository.instance.getActiveUserCountsByRole();
    if (mounted) {
      setState(() {
        _userCounts = counts;
        _adjustSelectedAudience();
      });
    }
  }

  void _adjustSelectedAudience() {
    final teachers = _userCounts['teachers'] ?? 0;
    final students = _userCounts['students'] ?? 0;
    final parents = _userCounts['parents'] ?? 0;
    final total = _userCounts['total'] ?? 0;

    if (_selectedAudience == 'teachers' && teachers == 0) {
      if (total > 0) _selectedAudience = 'all';
    } else if (_selectedAudience == 'students' && students == 0) {
      if (total > 0) _selectedAudience = 'all';
    } else if (_selectedAudience == 'parents' && parents == 0) {
      if (total > 0) _selectedAudience = 'all';
    }
  }

  int get _selectedAudienceCount {
    switch (_selectedAudience) {
      case 'teachers':
        return _userCounts['teachers'] ?? 0;
      case 'students':
        return _userCounts['students'] ?? 0;
      case 'parents':
        return _userCounts['parents'] ?? 0;
      case 'all':
      default:
        return _userCounts['total'] ?? 0;
    }
  }

  Future<void> _loadMaintenanceState() async {
    final settings = await AdminRepository.instance.getSystemSettings();
    final rateLimitCd = await RateLimitService.instance.checkAdminCooldown(
      actionKey: 'admin_maintenance_toggle',
      cooldownSeconds: _maintenanceCooldownSeconds,
    );
    final effectiveCooldown =
        settings.cooldownRemainingSeconds >= rateLimitCd
            ? settings.cooldownRemainingSeconds
            : rateLimitCd;

    if (mounted) {
      setState(() {
        _isMaintenanceMode = settings.isMaintenanceMode;
      });
      if (effectiveCooldown > 0) {
        _startCooldownTimer(effectiveCooldown);
      } else {
        _startCooldownTimer(0);
      }
    }
  }

  Future<void> _loadBroadcastHistory() async {
    final list = await AdminRepository.instance.getBroadcastAnnouncements(
      limit: 50,
    );
    if (mounted) {
      setState(() {
        _broadcasts = list;
        _isLoadingBroadcasts = false;
      });
    }
  }

  // =========================================================================
  // 1. SYSTEM MAINTENANCE MODE WITH MANDATORY CONFIRMATION WARNING MODAL
  // =========================================================================

  Future<void> _handleMaintenanceToggle(bool targetState) async {
    // Strict 10-minute (600s) tamper-proof cooldown check (server + rate limit service)
    final settingsCheck = await AdminRepository.instance.getSystemSettings();
    final rateCooldown = await RateLimitService.instance.checkAdminCooldown(
      actionKey: 'admin_maintenance_toggle',
      cooldownSeconds: _maintenanceCooldownSeconds,
    );
    final activeCooldown = [
      _cooldownRemainingSeconds,
      settingsCheck.cooldownRemainingSeconds,
      rateCooldown,
    ].reduce((a, b) => a > b ? a : b);

    if (activeCooldown > 0) {
      _startCooldownTimer(activeCooldown);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.catRed,
            content: Text(
              'Maintenance toggle is on cooldown. Please wait ${_formatCooldown(activeCooldown)} before changing maintenance mode again.',
            ),
          ),
        );
      }
      return;
    }

    if (targetState == true) {
      // Enabling Maintenance Mode -> SHOW STRICT WARNING MODAL
      final confirmed = await _showEnableMaintenanceWarningModal();
      if (confirmed != true) return;
    } else {
      // Disabling Maintenance Mode -> Normal Confirmation Modal
      final confirmed = await _showDisableMaintenanceModal();
      if (confirmed != true) return;
    }

    setState(() => _isTogglingMaintenance = true);

    final adminUser = AuthRepository.instance.currentUser;
    final adminId = adminUser?.id ?? 'admin';

    try {
      final updatedSettings = await AdminRepository.instance.setMaintenanceMode(
        targetState,
        adminId,
      );
      await RateLimitService.instance.recordAdminCooldown(
        actionKey: 'admin_maintenance_toggle',
        cooldownSeconds: _maintenanceCooldownSeconds,
      );

      final cooldownToStart = updatedSettings.cooldownRemainingSeconds > 0
          ? updatedSettings.cooldownRemainingSeconds
          : _maintenanceCooldownSeconds;
      _startCooldownTimer(cooldownToStart);

      // DISPATCH PERSONALIZED EMAILS IN BACKGROUND TO REGISTERED TEACHER & STUDENT ACCOUNTS ONLY
      AdminRepository.instance.getMaintenanceEmailRecipients().then((
        recipients,
      ) {
        if (recipients.isNotEmpty) {
          EmailService.instance.sendSystemMaintenanceAlertEmail(
            recipients: recipients,
            isEnabled: targetState,
          );
        }
      });

      if (mounted) {
        setState(() {
          _isMaintenanceMode = updatedSettings.isMaintenanceMode;
          _isTogglingMaintenance = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: targetState ? AppTheme.catRed : AppTheme.catGreen,
            content: Text(
              targetState
                  ? 'System Maintenance Mode is now ACTIVE. Teacher, Student, and Parent accounts are restricted.'
                  : 'System Maintenance Mode has been DISABLED. Normal login access restored.',
            ),
          ),
        );
      }
    } catch (e) {
      await _loadMaintenanceState();
      if (mounted) {
        setState(() => _isTogglingMaintenance = false); // UI rollback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.catRed,
            content: Text(
              'Failed to update maintenance mode: ${e.toString().replaceAll('Bad state: ', '')}',
            ),
          ),
        );
      }
    }
  }

  Future<bool?> _showEnableMaintenanceWarningModal() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _EnableMaintenanceDialog(),
    );
  }

  Future<bool?> _showDisableMaintenanceModal() {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.lock_open_rounded,
                color: theme.colorScheme.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              const Text('Disable Maintenance Mode?'),
            ],
          ),
          content: const Text(
            'This will restore normal system access. Teachers, Students, and Parents will be able to log in again immediately.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Restore System Access'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. GLOBAL ANNOUNCEMENT COMPOSER (EDGE CASES #7 & #8)
  // =========================================================================

  Future<void> _handleSendAnnouncement() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    bool hasValidationError = false;
    if (title.length < 3 || title.length > 100) {
      setState(() {
        _titleError = 'Title must be between 3 and 100 characters.';
      });
      hasValidationError = true;
    } else {
      if (_titleError != null) setState(() => _titleError = null);
    }

    if (message.length < 5 || message.length > 1000) {
      setState(() {
        _messageError = 'Message must be between 5 and 1,000 characters.';
      });
      hasValidationError = true;
    } else {
      if (_messageError != null) setState(() => _messageError = null);
    }

    if (hasValidationError) return;

    if (_selectedAudienceCount == 0) {
      setState(() {
        _messageError = 'Cannot send broadcast: No active non-archived recipients in selected audience.';
      });
      return;
    }

    // Rate Limiting & Cooldown Check (30 seconds via RateLimitService)
    final cooldownRemaining = await RateLimitService.instance
        .checkAdminCooldown(actionKey: 'admin_broadcast', cooldownSeconds: 30);
    if (cooldownRemaining > 0) {
      setState(() {
        _messageError =
            'Please wait $cooldownRemaining seconds before sending another announcement.';
      });
      return;
    }

    // Synchronous mutex lock BEFORE any await
    setState(() {
      _isSubmittingAnnouncement = true;
      _titleError = null;
      _messageError = null;
    });

    final adminUser = AuthRepository.instance.currentUser;
    final adminId = adminUser?.id ?? 'admin';

    try {
      final sent = await AdminRepository.instance.sendBroadcastAnnouncement(
        title: title,
        message: message,
        targetAudience: _selectedAudience,
        adminId: adminId,
      );

      await RateLimitService.instance.recordAdminCooldown(
        actionKey: 'admin_broadcast',
        cooldownSeconds: 30,
      );
      _titleController.clear();
      _messageController.clear();

      if (mounted) {
        setState(() {
          _broadcasts.insert(0, sent);
          _isSubmittingAnnouncement = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.catGreen,
            content: Text('Global Announcement sent successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingAnnouncement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.catRed,
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleCharCount = _titleController.text.length;
    final charCount = _messageController.text.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Broadcasts & Maintenance Control',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage system-wide announcements and toggle operational maintenance mode.',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),

          // =================================================================
          // SECTION 1: SYSTEM MAINTENANCE MODE CARD (60-30-10, NO CHECK ICON)
          // =================================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _isMaintenanceMode
                  ? (isDark ? const Color(0xFF261919) : const Color(0xFFFFF5F5))
                  : (isDark ? theme.colorScheme.surface : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isMaintenanceMode
                    ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA))
                    : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'System Maintenance Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: _isMaintenanceMode
                                  ? (isDark
                                      ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
                                      : const Color(0xFFFEE2E2))
                                  : (isDark
                                      ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                                      : const Color(0xFFDCFCE7)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isMaintenanceMode
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                    : const Color(0xFF22C55E).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isMaintenanceMode
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isMaintenanceMode
                                      ? 'ACTIVE (LOCKED)'
                                      : 'OPERATIONAL',
                                  style: TextStyle(
                                    color: _isMaintenanceMode
                                        ? (isDark
                                            ? const Color(0xFFFCA5A5)
                                            : const Color(0xFFB91C1C))
                                        : (isDark
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFF15803D)),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _isMaintenanceMode
                            ? 'Teachers, Students, and Parents cannot log in. Active sessions are locked out.'
                            : 'All users (Teachers, Students, Parents) can log in and use the system normally.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                          height: 1.35,
                        ),
                      ),
                      if (_cooldownRemainingSeconds > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF78350F).withValues(alpha: 0.35)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Cooldown active: ${_formatCooldown(_cooldownRemainingSeconds)} remaining before maintenance mode can be toggled again.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                if (_isTogglingMaintenance)
                  LoadingAnimationWidget.staggeredDotsWave(
                    color: theme.colorScheme.primary,
                    size: 22,
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Transform.scale(
                        scale: 0.95,
                        child: Switch(
                          value: _isMaintenanceMode,
                          activeTrackColor: const Color(0xFFEF4444),
                          activeThumbColor: Colors.white,
                          inactiveThumbColor:
                              isDark ? Colors.grey.shade400 : Colors.white,
                          inactiveTrackColor: isDark
                              ? Colors.grey.shade700
                              : const Color(0xFFCBD5E1),
                          onChanged: (_isTogglingMaintenance ||
                                  _cooldownRemainingSeconds > 0)
                              ? null
                              : (val) => _handleMaintenanceToggle(val),
                        ),
                      ),
                      if (_cooldownRemainingSeconds > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            'Locked (${_formatCooldown(_cooldownRemainingSeconds)})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // =================================================================
          // SECTION 2: GLOBAL ANNOUNCEMENT COMPOSER (60-30-10 PALETTE)
          // =================================================================
          if (_isInitialLoading)
            const ShimmerComposeCard()
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.campaign_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compose Global Push Announcement',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Broadcast instant notifications to active institutional accounts.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Target Audience Dropdown Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Target Audience:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedAudience,
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: 'all',
                                  enabled: (_userCounts['total'] ?? 0) > 0,
                                  child: Text(
                                    'All Users (${_userCounts['total'] ?? 0} active${(_userCounts['total'] ?? 0) == 0 ? ' - No users' : ''})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: (_userCounts['total'] ?? 0) == 0
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'teachers',
                                  enabled: (_userCounts['teachers'] ?? 0) > 0,
                                  child: Text(
                                    'Teachers (${_userCounts['teachers'] ?? 0} active${(_userCounts['teachers'] ?? 0) == 0 ? ' - No users' : ''})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: (_userCounts['teachers'] ?? 0) == 0
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'students',
                                  enabled: (_userCounts['students'] ?? 0) > 0,
                                  child: Text(
                                    'Students (${_userCounts['students'] ?? 0} active${(_userCounts['students'] ?? 0) == 0 ? ' - No users' : ''})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: (_userCounts['students'] ?? 0) == 0
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'parents',
                                  enabled: (_userCounts['parents'] ?? 0) > 0,
                                  child: Text(
                                    'Parents (${_userCounts['parents'] ?? 0} active${(_userCounts['parents'] ?? 0) == 0 ? ' - No users' : ''})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: (_userCounts['parents'] ?? 0) == 0
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedAudience = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title Input with Inline Error Outline
                  TextField(
                    controller: _titleController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'Announcement Title',
                      hintText:
                          'e.g., Campus Schedule Advisory or System Update',
                      counterText: '',
                      errorText: _titleError,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFDC2626),
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFDC2626),
                          width: 2.0,
                        ),
                      ),
                      errorStyle: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Title Live Character Counter (Real Max Limit 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '3 – 100 characters required',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        Text(
                          '$titleCharCount / 100 characters',
                          style: TextStyle(
                            fontSize: 12,
                            color: titleCharCount > 90
                                ? AppTheme.catRed
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                            fontWeight: titleCharCount > 90
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Message Input with Inline Error Outline
                  TextField(
                    controller: _messageController,
                    maxLength: 1000,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Message Content',
                      hintText:
                          'Type your message here (up to 1,000 characters)...',
                      counterText: '',
                      errorText: _messageError,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFDC2626),
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFDC2626),
                          width: 2.0,
                        ),
                      ),
                      errorStyle: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Message Live Character Counter & Submit Button
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '$charCount / 1000 characters',
                          style: TextStyle(
                            fontSize: 12,
                            color: charCount > 950
                                ? AppTheme.catRed
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                            fontWeight: charCount > 950
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDark
                                ? Colors.white12
                                : Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: (_isSubmittingAnnouncement ||
                                  _selectedAudienceCount == 0)
                              ? null
                              : _handleSendAnnouncement,
                          icon: _isSubmittingAnnouncement
                              ? LoadingAnimationWidget.staggeredDotsWave(
                                  color: Colors.white,
                                  size: 16,
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isSubmittingAnnouncement
                                ? 'Sending...'
                                : 'Send Broadcast',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedAudienceCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userCounts['total'] == 0
                                    ? 'Broadcast disabled: There are currently no active non-archived users in the system.'
                                    : 'Broadcast disabled: No active non-archived $_selectedAudience found to receive announcements.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 28),

          // =================================================================
          // SECTION 3: BROADCAST HISTORY LIST
          // =================================================================
          Text(
            'Broadcast History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoadingBroadcasts)
            const Column(
              children: [
                ShimmerBroadcastItem(),
                ShimmerBroadcastItem(),
                ShimmerBroadcastItem(),
              ],
            )
          else if (_broadcasts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.campaign_outlined,
                      color: theme.colorScheme.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Broadcast Announcements Sent Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Institutional broadcasts and urgent push announcements dispatched to faculty, students, or parents will be archived here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _broadcasts.length,
              itemBuilder: (context, i) {
                final b = _broadcasts[i];
                return ExpandableNotificationCard(
                  notification: b,
                  showDelete: false,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EnableMaintenanceDialog extends StatefulWidget {
  const _EnableMaintenanceDialog();

  @override
  State<_EnableMaintenanceDialog> createState() =>
      _EnableMaintenanceDialogState();
}

class _EnableMaintenanceDialogState extends State<_EnableMaintenanceDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _inlineError;
  bool _isConfirmed = false;
  static const String _requiredText = 'I confirm';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final trimmed = value.trim();
    final isMatch = trimmed.toLowerCase() == _requiredText.toLowerCase();

    setState(() {
      _isConfirmed = isMatch;
      if (isMatch) {
        _inlineError = null;
        // Auto-submit when strictly confirmed
        Future.delayed(const Duration(milliseconds: 200), _handleConfirm);
      } else if (value.isNotEmpty &&
          !_requiredText.toLowerCase().startsWith(
            value.trimLeft().toLowerCase(),
          )) {
        _inlineError = "Please type '$_requiredText' exactly.";
      } else {
        _inlineError = null;
      }
    });
  }

  void _handleConfirm() {
    if (_isConfirmed) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.catRed, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable Maintenance Mode?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.catRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.catRed.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.catRed, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CRITICAL WARNING: Enabling System Maintenance Mode will immediately enforce full system lock down.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.catRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The following actions will take effect immediately:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _AdminBroadcastsTabState._buildBulletPoint(
                'Non-admin users (Teachers, Students, Parents) CANNOT log in.',
              ),
              _AdminBroadcastsTabState._buildBulletPoint(
                'All currently active Teachers, Students, and Parents will be FORCEFULLY LOGGED OUT of their accounts.',
              ),
              _AdminBroadcastsTabState._buildBulletPoint(
                'Any pending offline teacher queues will be preserved before logout.',
              ),
              _AdminBroadcastsTabState._buildBulletPoint(
                'Only System Administrators can access the portal to perform IT maintenance.',
              ),
              const SizedBox(height: 18),

              // Type to confirm instruction
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                  children: const [
                    TextSpan(text: 'To confirm system lockdown, please type '),
                    TextSpan(
                      text: _requiredText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.catRed,
                      ),
                    ),
                    TextSpan(text: ' below:'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Input field with real-time inline validation (strictly adhering to inline-input-validation skill)
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLength: 15,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => null, // Hide counter text
                inputFormatters: [LengthLimitingTextInputFormatter(15)],
                onChanged: _onTextChanged,
                onSubmitted: (_) {
                  if (_isConfirmed) _handleConfirm();
                },
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: _requiredText,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    fontWeight: FontWeight.normal,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _inlineError != null
                          ? AppTheme.catRed
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                      width: _inlineError != null ? 1.5 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _inlineError != null
                          ? AppTheme.catRed
                          : theme.colorScheme.primary,
                      width: 2.0,
                    ),
                  ),
                ),
              ),

              // Inline error underneath the field
              if (_inlineError != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.catRed,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: const TextStyle(
                          color: AppTheme.catRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
