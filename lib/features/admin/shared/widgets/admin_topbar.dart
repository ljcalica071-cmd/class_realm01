import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/sync_status_badge.dart';

class AdminTopbar extends StatelessWidget {
  final bool isSidebarExpanded;
  final VoidCallback onToggleSidebar;
  final String title;
  final UserModel? adminUser;

  const AdminTopbar({
    super.key,
    required this.isSidebarExpanded,
    required this.onToggleSidebar,
    required this.title,
    required this.adminUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isSidebarExpanded ? Icons.menu_open : Icons.menu),
            onPressed: onToggleSidebar,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(theme.brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () {
              final notifier = AppTheme.themeModeNotifier;
              notifier.value = notifier.value == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.light;
            },
          ),
          const SizedBox(width: 8),
          const SyncStatusBadge(),
          const SizedBox(width: 16),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              adminUser?.fullName.substring(0, 1) ?? 'A',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                adminUser?.fullName ?? 'Administrator',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'System Administrator',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
