import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isExpanded;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleExpanded;
  final VoidCallback onLogout;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.isExpanded,
    required this.onSelect,
    required this.onToggleExpanded,
    required this.onLogout,
  });

  Widget _buildSectionHeader(String title, ThemeData theme, bool isMobile) {
    if (!isMobile && !isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Divider(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          height: 1,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 12, bottom: 4, right: 16),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required String label,
    required IconData icon,
    required ThemeData theme,
    required bool isMobile,
    int badgeCount = 0,
  }) {
    final isSelected = selectedIndex == index;
    final showExpanded = isMobile || isExpanded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Tooltip(
          message: !showExpanded ? label : '',
          waitDuration: const Duration(milliseconds: 300),
          child: Builder(
            builder: (itemContext) => InkWell(
              onTap: () {
                if (isMobile) {
                  final scaffold = Scaffold.maybeOf(itemContext);
                  if (scaffold?.isDrawerOpen == true) {
                    scaffold!.closeDrawer();
                  }
                }
                onSelect(index);
              },
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: Icon(
                          icon,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                          size: 20,
                        ),
                      ),
                    ),
                    if (showExpanded)
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    if (showExpanded && badgeCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppTheme.catRed,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
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
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 900;
    final showExpanded = isMobile || isExpanded;

    return Material(
      color: theme.colorScheme.surface,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        clipBehavior: Clip.hardEdge,
        width: isMobile ? 260 : (isExpanded ? 260 : 76),
        decoration: const BoxDecoration(),
        child: Column(
          children: [
            // Brand Header (Height: 70)
            Container(
              height: 70,
              padding: EdgeInsets.symmetric(
                horizontal: showExpanded ? 16 : 0,
              ),
              alignment: Alignment.centerLeft,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 180;
                  if (!showExpanded || (!isMobile && !isWide)) {
                    return Center(
                      child: IconButton(
                        icon: Icon(
                          LucideIcons.panelLeftOpen,
                          color: theme.colorScheme.onSurface,
                          size: 22,
                        ),
                        tooltip: 'Expand Menu',
                        onPressed: onToggleExpanded,
                      ),
                    );
                  }
                  return Row(
                    children: [
                      Image.asset(
                        'assets/branding/school_logo.png',
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CLASSREALM',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                            Text(
                              'ADMIN PORTAL',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile)
                        IconButton(
                          icon: Icon(
                            LucideIcons.panelLeftClose,
                            color: theme.colorScheme.onSurface,
                            size: 20,
                          ),
                          tooltip: 'Collapse Menu',
                          onPressed: onToggleExpanded,
                        ),
                    ],
                  );
                },
              ),
            ),
            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              height: 1,
            ),

            // Grouped Nav Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildNavItem(
                    context: context,
                    index: 0,
                    label: 'Dashboard',
                    icon: LucideIcons.layoutDashboard,
                    theme: theme,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 8),
                  _buildSectionHeader('COMMUNICATION & OPS', theme, isMobile),
                  _buildNavItem(
                    context: context,
                    index: 1,
                    label: 'Broadcasts',
                    icon: LucideIcons.megaphone,
                    theme: theme,
                    isMobile: isMobile,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 2,
                    label: 'Teacher Management',
                    icon: LucideIcons.users,
                    theme: theme,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 8),
                  _buildSectionHeader('SYSTEM & ANALYTICS', theme, isMobile),
                  _buildNavItem(
                    context: context,
                    index: 3,
                    label: 'Activity Analytics',
                    icon: LucideIcons.barChart3,
                    theme: theme,
                    isMobile: isMobile,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 4,
                    label: 'Admin Profile',
                    icon: LucideIcons.user,
                    theme: theme,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),

            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              height: 1,
            ),

            // Logout Button (Matching Teacher Portal)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Tooltip(
                  message: !showExpanded ? 'Log Out' : '',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Builder(
                    builder: (logoutContext) => InkWell(
                      onTap: () {
                        if (isMobile) {
                          final scaffold = Scaffold.maybeOf(logoutContext);
                          if (scaffold?.isDrawerOpen == true) {
                            scaffold!.closeDrawer();
                          }
                        }
                        onLogout();
                      },
                      hoverColor: Colors.redAccent.withValues(alpha: 0.08),
                      child: SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 56,
                              child: Center(
                                child: Icon(
                                  LucideIcons.logOut,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                              ),
                            ),
                            if (showExpanded)
                              const Expanded(
                                child: Text(
                                  'Log Out',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
