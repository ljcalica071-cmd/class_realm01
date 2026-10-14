import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/sync_status_badge.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

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
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          else
            IconButton(
              icon: Icon(isSidebarExpanded ? Icons.menu_open : Icons.menu),
              onPressed: onToggleSidebar,
            ),
          if (!isMobile) const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) const Spacer(),
          IconButton(
            icon: Icon(theme.brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () {
              final notifier = AppTheme.themeModeNotifier;
              final isDark = notifier.value == ThemeMode.light;
              notifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
              final user = adminUser ?? AuthRepository.instance.currentUser;
              if (user != null) {
                LocalStorageService.saveUserThemeMode(user.id, isDark, email: user.email);
              } else {
                LocalStorageService.saveThemeMode(isDark);
              }
            },
          ),
          if (!isMobile) const SizedBox(width: 8),
          if (!isMobile) const SyncStatusBadge(),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            radius: isMobile ? 16 : 20,
            child: Text(
              adminUser?.fullName.substring(0, 1) ?? 'A',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
          ),
          if (!isMobile) ...[
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
          ]
        ],
      ),
    );
  }
}
