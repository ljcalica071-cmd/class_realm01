import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:class_realm/models/academic_models.dart';

class SyncStatusBadge extends StatefulWidget {
  final bool onAppBar;
  const SyncStatusBadge({super.key, this.onAppBar = false});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return ValueListenableBuilder<bool>(
      valueListenable: AppLifecycleCoordinator.instance.isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppLifecycleCoordinator.instance.isSyncingNotifier,
          builder: (context, isSyncing, _) {
            final SyncStatus status;
            if (!isOnline) {
              status = SyncStatus.offline;
            } else if (isSyncing) {
              status = SyncStatus.syncing;
            } else {
              status = SyncStatus.online;
            }

            Color bg;
            Color fg;
            Color iconColor;
            Color textColor;
            IconData icon;
            String label;

            switch (status) {
              case SyncStatus.online:
                if (widget.onAppBar) {
                  bg = Colors.white.withValues(alpha: 0.18);
                  fg = const Color(0xFF4ADE80);
                  iconColor = const Color(0xFF4ADE80);
                  textColor = Colors.white;
                } else {
                  bg = AppTheme.catTeal.withValues(alpha: 0.12);
                  fg = AppTheme.catTeal;
                  iconColor = fg;
                  textColor = fg;
                }
                icon = LucideIcons.wifi;
                label = 'Online';
                break;
              case SyncStatus.offline:
                if (widget.onAppBar) {
                  bg = const Color(0xFFDC2626).withValues(alpha: 0.25);
                  fg = const Color(0xFFFCA5A5);
                  iconColor = const Color(0xFFFCA5A5);
                  textColor = Colors.white;
                } else {
                  bg = AppTheme.catRed.withValues(alpha: 0.12);
                  fg = AppTheme.catRed;
                  iconColor = fg;
                  textColor = fg;
                }
                icon = LucideIcons.wifiOff;
                label = 'Offline';
                break;
              case SyncStatus.pendingSync:
                if (widget.onAppBar) {
                  bg = const Color(0xFFD97706).withValues(alpha: 0.25);
                  fg = const Color(0xFFFCD34D);
                  iconColor = const Color(0xFFFCD34D);
                  textColor = Colors.white;
                } else {
                  bg = AppTheme.catOrange.withValues(alpha: 0.12);
                  fg = AppTheme.catOrange;
                  iconColor = fg;
                  textColor = fg;
                }
                icon = LucideIcons.cloudOff;
                label = 'Pending Sync';
                break;
              case SyncStatus.syncing:
                if (widget.onAppBar) {
                  bg = const Color(0xFF2563EB).withValues(alpha: 0.25);
                  fg = const Color(0xFF93C5FD);
                  iconColor = const Color(0xFF93C5FD);
                  textColor = Colors.white;
                } else {
                  bg = AppTheme.catBlue.withValues(alpha: 0.12);
                  fg = AppTheme.catBlue;
                  iconColor = fg;
                  textColor = fg;
                }
                icon = LucideIcons.refreshCw;
                label = 'Syncing...';
                break;
              case SyncStatus.synced:
                if (widget.onAppBar) {
                  bg = Colors.white.withValues(alpha: 0.18);
                  fg = const Color(0xFF4ADE80);
                  iconColor = const Color(0xFF4ADE80);
                  textColor = Colors.white;
                } else {
                  bg = AppTheme.catTeal.withValues(alpha: 0.12);
                  fg = AppTheme.catTeal;
                  iconColor = fg;
                  textColor = fg;
                }
                icon = LucideIcons.cloudCheck;
                label = 'Synced';
                break;
              case SyncStatus.syncError:
                if (widget.onAppBar) {
                  bg = const Color(0xFFDC2626).withValues(alpha: 0.25);
                  fg = const Color(0xFFFCA5A5);
                  iconColor = const Color(0xFFFCA5A5);
                  textColor = Colors.white;
                } else {
                  bg = AppTheme.catRed.withValues(alpha: 0.12);
                  fg = AppTheme.catRed;
                  iconColor = fg;
                  textColor = fg;
                }
                icon = LucideIcons.alertCircle;
                label = 'Sync Error';
                break;
            }

            return Tooltip(
              message: !isOnline
                  ? 'No internet connection detected. Offline Mode is active.'
                  : (isSyncing
                        ? 'Syncing local and cloud data...'
                        : 'Connected to cloud. Tap to verify connection.'),
              child: InkWell(
                onTap: () async {
                  AppLifecycleCoordinator.instance.setSyncing(true);
                  try {
                    final isConnected = await AppLifecycleCoordinator.instance
                        .checkConnectivity();
                    if (isConnected) {
                      await SyncCoordinator.instance.processPendingQueue();
                    }
                  } finally {
                    AppLifecycleCoordinator.instance.setSyncing(false);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.onAppBar
                          ? Colors.white.withValues(alpha: 0.35)
                          : fg.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      if (!isCompact) ...[
                        const SizedBox(width: 6),
                        Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
