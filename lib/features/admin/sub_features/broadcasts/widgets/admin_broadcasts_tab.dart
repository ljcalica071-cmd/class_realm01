import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/admin_portal_models.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/widgets/common/expandable_notification_card.dart';

class AdminBroadcastsTab extends StatefulWidget {
  const AdminBroadcastsTab({super.key});

  @override
  State<AdminBroadcastsTab> createState() => _AdminBroadcastsTabState();
}

class _AdminBroadcastsTabState extends State<AdminBroadcastsTab> {
  // Maintenance State
  bool _isMaintenanceMode = false;
  bool _isTogglingMaintenance = false;
  DateTime? _lastMaintenanceToggleAt;

  // Announcement Composer State
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedAudience = 'all'; // 'all', 'teachers', 'students_parents'
  bool _isSubmittingAnnouncement = false;
  DateTime? _lastBroadcastAt;

  // Broadcast History State
  List<AppNotificationModel> _broadcasts = [];
  bool _isLoadingBroadcasts = true;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToRealtime();
    _messageController.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
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
        .subscribe();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadMaintenanceState(),
      _loadBroadcastHistory(),
    ]);
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
    // 5-second cooldown
    final now = DateTime.now();
    if (_lastMaintenanceToggleAt != null &&
        now.difference(_lastMaintenanceToggleAt!) < const Duration(seconds: 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait 5 seconds before changing maintenance mode again.')),
      );
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
    _lastMaintenanceToggleAt = DateTime.now();

    final adminUser = AuthRepository.instance.currentUser;
    final adminId = adminUser?.id ?? 'admin';

    try {
      await AdminRepository.instance.setMaintenanceMode(targetState, adminId);
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
      builder: (ctx) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.catRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.catRed.withValues(alpha: 0.3)),
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
                _buildBulletPoint('Non-admin users (Teachers, Students, Parents) CANNOT log in.'),
                _buildBulletPoint('All currently active Teachers, Students, and Parents will be FORCEFULLY LOGGED OUT of their accounts.'),
                _buildBulletPoint('Any pending offline teacher queues will be preserved before logout.'),
                _buildBulletPoint('Only System Administrators can access the portal to perform IT maintenance.'),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure you want to toggle Maintenance Mode now?',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.catRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enable Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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

    if (title.length < 3 || title.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title must be between 3 and 100 characters.')),
      );
      return;
    }
    if (message.length < 5 || message.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message must be between 5 and 1,000 characters.')),
      );
      return;
    }

    // Rate Limiting & Cooldown Check (Edge Case #7)
    final now = DateTime.now();
    if (_lastBroadcastAt != null && now.difference(_lastBroadcastAt!) < const Duration(seconds: 30)) {
      final remaining = 30 - now.difference(_lastBroadcastAt!).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $remaining seconds before sending another announcement.')),
      );
      return;
    }

    // Synchronous mutex lock BEFORE any await
    setState(() => _isSubmittingAnnouncement = true);

    final adminUser = AuthRepository.instance.currentUser;
    final adminId = adminUser?.id ?? 'admin';

    try {
      final sent = await AdminRepository.instance.sendBroadcastAnnouncement(
        title: title,
        message: message,
        targetAudience: _selectedAudience,
        adminId: adminId,
      );

      _lastBroadcastAt = DateTime.now();
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

  Future<void> _handleDeleteBroadcast(AppNotificationModel broadcast) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Archive Announcement?'),
        content: const Text(
          'This announcement will be soft-deleted. Users currently reading it will not experience an app crash.',
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.catRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AdminRepository.instance.softDeleteAnnouncement(broadcast.id);
      setState(() {
        _broadcasts.removeWhere((b) => b.id == broadcast.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement archived successfully.')),
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
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _isMaintenanceMode,
                    activeColor: AppTheme.catRed,
                    onChanged: (val) => _handleMaintenanceToggle(val),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // =================================================================
          // SECTION 2: GLOBAL ANNOUNCEMENT COMPOSER
          // =================================================================
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
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Users')),
                        DropdownMenuItem(value: 'teachers', child: Text('Teachers Only')),
                        DropdownMenuItem(value: 'students_parents', child: Text('Students & Parents')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedAudience = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title Input
                TextField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Announcement Title',
                    hintText: 'e.g., Campus Schedule Advisory or System Update',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),

                // Message Input
                TextField(
                  controller: _messageController,
                  maxLength: 1000,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Message Content',
                    hintText: 'Type your message here (up to 1,000 characters)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    counterText: '',
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmittingAnnouncement ? null : _handleSendAnnouncement,
                      icon: _isSubmittingAnnouncement
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmittingAnnouncement ? 'Sending...' : 'Send Broadcast',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_broadcasts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No announcements sent yet.',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
                  showDelete: true,
                  onDelete: () => _handleDeleteBroadcast(b),
                );
              },
            ),
        ],
      ),
    );
  }
}
