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

  // Announcement Composer State
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedAudience = 'all'; // 'all', 'teachers', 'students_parents'
  bool _isSubmittingAnnouncement = false;
  String? _titleError;
  String? _messageError;

  // Active User Counts by Role (excluding archived users)
  Map<String, int> _userCounts = {'teachers': 0, 'students': 0, 'parents': 0, 'total': 0};

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
    _titleController.dispose();
    _messageController.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
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
    if (mounted) {
      setState(() {
        _isMaintenanceMode = settings.isMaintenanceMode;
      });
    }
  }

  Future<void> _loadBroadcastHistory() async {
    final list = await AdminRepository.instance.getBroadcastAnnouncements(limit: 50);
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
    // 5-second persistent cooldown via RateLimitService
    final cooldownRemaining = await RateLimitService.instance.checkAdminCooldown(
      actionKey: 'admin_maintenance_toggle',
      cooldownSeconds: 5,
    );
    if (cooldownRemaining > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait $cooldownRemaining seconds before changing maintenance mode again.'),
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
      await AdminRepository.instance.setMaintenanceMode(targetState, adminId);
      await RateLimitService.instance.recordAdminCooldown(
        actionKey: 'admin_maintenance_toggle',
        cooldownSeconds: 5,
      );
      
      // DISPATCH EMAILS IN BACKGROUND (Fire and forget)
      AdminRepository.instance.getActiveUserEmails().then((emails) {
        if (emails.isNotEmpty) {
          EmailService.instance.sendSystemMaintenanceAlertEmail(
            recipientEmails: emails,
            isEnabled: targetState,
          );
        }
      });

      if (mounted) {
        setState(() {
          _isMaintenanceMode = targetState;
          _isTogglingMaintenance = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: targetState ? AppTheme.catRed : AppTheme.catGreen,
            content: Text(
              targetState
                  ? 'System Maintenance Mode is now ACTIVE. Non-admin users are restricted.'
                  : 'System Maintenance Mode has been DISABLED. Normal access restored.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTogglingMaintenance = false); // UI rollback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.catRed, content: Text('Failed to update maintenance mode: $e')),
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
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.catGreen, size: 28),
              SizedBox(width: 12),
              Text('Disable Maintenance Mode?'),
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
                backgroundColor: AppTheme.catGreen,
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
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
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
    final cooldownRemaining = await RateLimitService.instance.checkAdminCooldown(
      actionKey: 'admin_broadcast',
      cooldownSeconds: 30,
    );
    if (cooldownRemaining > 0) {
      setState(() {
        _messageError = 'Please wait $cooldownRemaining seconds before sending another announcement.';
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
          SnackBar(backgroundColor: AppTheme.catRed, content: Text('Error: $e')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // =================================================================
          // SECTION 1: SYSTEM MAINTENANCE MODE CARD
          // =================================================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isMaintenanceMode
                  ? AppTheme.catRed.withValues(alpha: isDark ? 0.2 : 0.08)
                  : (isDark ? theme.colorScheme.surface : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isMaintenanceMode
                    ? AppTheme.catRed.withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isMaintenanceMode
                        ? AppTheme.catRed.withValues(alpha: 0.2)
                        : AppTheme.catGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMaintenanceMode ? Icons.build_circle_rounded : Icons.check_circle_outline_rounded,
                    color: _isMaintenanceMode ? AppTheme.catRed : AppTheme.catGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
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
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isMaintenanceMode ? AppTheme.catRed : AppTheme.catGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isMaintenanceMode ? 'ACTIVE (LOCKED)' : 'OPERATIONAL',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isMaintenanceMode
                            ? 'Non-admin users cannot log in. Active sessions were terminated.'
                            : 'All users (Teachers, Students, Parents) can log in and use the system normally.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTogglingMaintenance)
                  LoadingAnimationWidget.staggeredDotsWave(
                    color: theme.colorScheme.primary,
                    size: 20,
                  )
                else
                  Switch(
                    value: _isMaintenanceMode,
                    activeThumbColor: AppTheme.catRed,
                    onChanged: (val) => _handleMaintenanceToggle(val),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // =================================================================
          // SECTION 2: GLOBAL ANNOUNCEMENT COMPOSER
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
                color: isDark ? Colors.white12 : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_outlined, color: AppTheme.catPurple, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Compose Global Push Announcement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Target Audience Dropdown
                Row(
                  children: [
                    Text(
                      'Target Audience:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedAudience,
                      underline: Container(),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          enabled: (_userCounts['total'] ?? 0) > 0,
                          child: Text(
                            'All Users (${_userCounts['total'] ?? 0} active${(_userCounts['total'] ?? 0) == 0 ? ' - No users' : ''})',
                            style: TextStyle(
                              color: (_userCounts['total'] ?? 0) == 0 ? Colors.grey : null,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'teachers',
                          enabled: (_userCounts['teachers'] ?? 0) > 0,
                          child: Text(
                            'Teachers (${_userCounts['teachers'] ?? 0} active${(_userCounts['teachers'] ?? 0) == 0 ? ' - No users' : ''})',
                            style: TextStyle(
                              color: (_userCounts['teachers'] ?? 0) == 0 ? Colors.grey : null,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'students',
                          enabled: (_userCounts['students'] ?? 0) > 0,
                          child: Text(
                            'Students (${_userCounts['students'] ?? 0} active${(_userCounts['students'] ?? 0) == 0 ? ' - No users' : ''})',
                            style: TextStyle(
                              color: (_userCounts['students'] ?? 0) == 0 ? Colors.grey : null,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'parents',
                          enabled: (_userCounts['parents'] ?? 0) > 0,
                          child: Text(
                            'Parents (${_userCounts['parents'] ?? 0} active${(_userCounts['parents'] ?? 0) == 0 ? ' - No users' : ''})',
                            style: TextStyle(
                              color: (_userCounts['parents'] ?? 0) == 0 ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedAudience = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title Input with Inline Error Outline
                TextField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Announcement Title',
                    hintText: 'e.g., Campus Schedule Advisory or System Update',
                    counterText: '',
                    errorText: _titleError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
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
                const SizedBox(height: 14),

                // Message Input with Inline Error Outline
                TextField(
                  controller: _messageController,
                  maxLength: 1000,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Message Content',
                    hintText: 'Type your message here (up to 1,000 characters)...',
                    counterText: '',
                    errorText: _messageError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
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
                const SizedBox(height: 6),

                // Live Character Counter & Submit Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$charCount / 1000 characters',
                      style: TextStyle(
                        fontSize: 12,
                        color: charCount > 950 ? AppTheme.catRed : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: charCount > 950 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (_isSubmittingAnnouncement || _selectedAudienceCount == 0)
                          ? null
                          : _handleSendAnnouncement,
                      icon: _isSubmittingAnnouncement
                          ? LoadingAnimationWidget.staggeredDotsWave(
                              color: Colors.white,
                              size: 16,
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmittingAnnouncement ? 'Sending...' : 'Send Broadcast',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (_selectedAudienceCount == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
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
          !_requiredText.toLowerCase().startsWith(value.trimLeft().toLowerCase())) {
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
                  border:
                      Border.all(color: AppTheme.catRed.withValues(alpha: 0.3)),
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
                  'Non-admin users (Teachers, Students, Parents) CANNOT log in.'),
              _AdminBroadcastsTabState._buildBulletPoint(
                  'All currently active Teachers, Students, and Parents will be FORCEFULLY LOGGED OUT of their accounts.'),
              _AdminBroadcastsTabState._buildBulletPoint(
                  'Any pending offline teacher queues will be preserved before logout.'),
              _AdminBroadcastsTabState._buildBulletPoint(
                  'Only System Administrators can access the portal to perform IT maintenance.'),
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
                buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null, // Hide counter text
                inputFormatters: [
                  LengthLimitingTextInputFormatter(15),
                ],
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
