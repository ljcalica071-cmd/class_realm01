import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isExpanded;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.isExpanded,
    required this.onSelect,
    required this.onLogout,
  });

  Widget _buildNavItem(BuildContext context, int index, String label, IconData icon, {int badgeCount = 0}) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onSelect(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
            if (isExpanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.catRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: isExpanded ? 260 : 80,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Logo Header
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Image.asset(
                  'assets/branding/school_logo.png',
                  width: 32,
                  height: 32,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'CLASSREALM',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Nav Items
          _buildNavItem(context, 0, 'Dashboard', Icons.grid_view_rounded),
          _buildNavItem(context, 1, 'Broadcasts', Icons.campaign_rounded),
          _buildNavItem(context, 2, 'Teacher Management', Icons.people_outline_rounded),
          _buildNavItem(context, 3, 'Activity Analytics', Icons.analytics_outlined),
          _buildNavItem(context, 4, 'Admin Profile', Icons.person_outline_rounded),

          const Spacer(),
          const Divider(color: Colors.white12, height: 1),

          // Logout
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: AppTheme.catRed, size: 24),
                  if (isExpanded) ...[
                    const SizedBox(width: 16),
                    const Text('Logout', style: TextStyle(color: AppTheme.catRed, fontSize: 16)),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
