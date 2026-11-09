import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    this.isSidebarExpanded = true,
    required this.onToggleSidebar,
    required this.title,
    required this.adminUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      width: double.infinity,
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: Icon(
                    LucideIcons.menu,
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) const Spacer(),
          if (!isMobile) const SyncStatusBadge(),
          if (!isMobile) const SizedBox(width: 16),
          IconButton(
            tooltip: theme.brightness == Brightness.dark
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                theme.brightness == Brightness.dark
                    ? LucideIcons.sun
                    : LucideIcons.moon,
                key: ValueKey<bool>(theme.brightness == Brightness.dark),
                color: theme.colorScheme.onSurface,
              ),
            ),
            onPressed: () {
              final notifier = AppTheme.themeModeNotifier;
              final currentIsDark = theme.brightness == Brightness.dark;
              final newIsDark = !currentIsDark;
              notifier.value = newIsDark ? ThemeMode.dark : ThemeMode.light;
              final user = adminUser ?? AuthRepository.instance.currentUser;
              if (user != null) {
                LocalStorageService.saveUserThemeMode(
                  user.id,
                  newIsDark,
                  email: user.email,
                );
              } else {
                LocalStorageService.saveThemeMode(newIsDark);
              }
            },
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            radius: 18,
            child: Text(
              adminUser?.fullName.isNotEmpty == true
                  ? adminUser!.fullName.substring(0, 1).toUpperCase()
                  : 'A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'System Administrator',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
