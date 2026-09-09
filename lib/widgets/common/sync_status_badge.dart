import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/academic_models.dart';
import '../../data/mock_database.dart';

class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  @override
  Widget build(BuildContext context) {
    final status = MockDatabase.instance.syncStatus;
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case SyncStatus.online:
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.wifi;
        label = 'Online';
        break;
      case SyncStatus.offline:
        bg = const Color(0xFFF1F5F9);
        fg = AppColors.textSecondary;
        icon = Icons.wifi_off;
        label = 'Offline Mode (Local)';
        break;
      case SyncStatus.pendingSync:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        icon = Icons.sync_problem;
        label = 'Pending Sync (3)';
        break;
      case SyncStatus.syncing:
        bg = AppColors.infoLight;
        fg = AppColors.info;
        icon = Icons.sync;
        label = 'Syncing...';
        break;
      case SyncStatus.synced:
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.cloud_done;
        label = 'Synced';
        break;
      case SyncStatus.syncError:
        bg = AppColors.errorLight;
        fg = AppColors.error;
        icon = Icons.error_outline;
        label = 'Sync Error';
        break;
    }

    return Tooltip(
      message: 'Click to simulate network / sync state toggle',
      child: InkWell(
        onTap: () {
          setState(() {
            MockDatabase.instance.toggleOfflineSync();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Simulated Status Changed to: ${MockDatabase.instance.syncStatus.name.toUpperCase()}'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppColors.sidebarBg,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fg.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
