import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:class_realm/models/academic_models.dart';

class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return ValueListenableBuilder<bool>(
      valueListenable: AppLifecycleCoordinator.instance.isSyncingNotifier,
      builder: (context, isSyncing, _) {
        final status = isSyncing ? SyncStatus.syncing : SyncStatus.online;

        Color bg;
        Color fg;
        IconData icon;
        String label;

        switch (status) {
          case SyncStatus.online:
            bg = AppTheme.catTeal.withValues(alpha: 0.12);
            fg = AppTheme.catTeal;
            icon = LucideIcons.wifi;
            label = 'Online';
            break;
          case SyncStatus.offline:
            bg = theme.colorScheme.onSurface.withValues(alpha: 0.08);
            fg = theme.colorScheme.onSurface.withValues(alpha: 0.5);
            icon = LucideIcons.wifiOff;
            label = 'Offline Mode (Local)';
            break;
          case SyncStatus.pendingSync:
            bg = AppTheme.catOrange.withValues(alpha: 0.12);
            fg = AppTheme.catOrange;
            icon = LucideIcons.cloudOff;
            label = 'Pending Sync';
            break;
          case SyncStatus.syncing:
            bg = AppTheme.catBlue.withValues(alpha: 0.12);
            fg = AppTheme.catBlue;
            icon = LucideIcons.refreshCw;
            label = 'Syncing...';
            break;
          case SyncStatus.synced:
            bg = AppTheme.catTeal.withValues(alpha: 0.12);
            fg = AppTheme.catTeal;
            icon = LucideIcons.cloudCheck;
            label = 'Synced';
            break;
          case SyncStatus.syncError:
            bg = AppTheme.catRed.withValues(alpha: 0.12);
            fg = AppTheme.catRed;
            icon = LucideIcons.alertCircle;
            label = 'Sync Error';
            break;
        }

        return Tooltip(
          message: 'Cloud & local database sync status',
          child: InkWell(
            onTap: () async {
              AppLifecycleCoordinator.instance.setSyncing(true);
              try {
                await SyncCoordinator.instance.processPendingQueue();
              } finally {
                AppLifecycleCoordinator.instance.setSyncing(false);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: fg.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  if (!isCompact) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
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
  }
}
