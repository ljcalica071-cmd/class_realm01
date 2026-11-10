import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_grades_tab.dart';
import 'package:class_realm/features/parent/sub_features/communications/widgets/parent_teacher_contact_view.dart';
import 'package:class_realm/features/parent/sub_features/profile/screens/parent_settings_screen.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/core/utils/logout_helper.dart';

class ParentDrawer extends StatelessWidget {
  final UserModel parent;
  final UserModel? linkedStudent;
  final List<UserModel> allChildren;
  final int currentBottomTabIndex;
  final ValueChanged<int>? onSelectBottomTab;
  final VoidCallback? onSwitchChildTap;
  final ValueChanged<UserModel>? onSelectChild;
  final VoidCallback? onOpenGrades;
  final VoidCallback? onOpenTeachers;
  final UserModel? teacher;

  const ParentDrawer({
    super.key,
    required this.parent,
    required this.linkedStudent,
    this.allChildren = const [],
    this.currentBottomTabIndex = 0,
    this.onSelectBottomTab,
    this.onSwitchChildTap,
    this.onSelectChild,
    this.onOpenGrades,
    this.onOpenTeachers,
    this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final student = linkedStudent;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Drawer Header with Active Student & Downward Switcher Button ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.86),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        radius: 25,
                        child: Text(
                          parent.fullName.trim().isNotEmpty
                              ? parent.fullName.trim()[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Parent / Guardian Portal',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Active Child Pill with Downward Button
                  Material(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onSwitchChildTap != null
                          ? () {
                              Navigator.pop(context);
                              onSwitchChildTap!();
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student == null
                                        ? 'No Linked Student'
                                        : student.lastFirstMi,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (student != null)
                                    Text(
                                      [
                                        if (student
                                                .parentGuardianRelationship !=
                                            null)
                                          student.parentGuardianRelationship!,
                                        if (student.departmentOrSection != null)
                                          student.departmentOrSection!,
                                      ].join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (allChildren.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Drawer Menu Items ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                children: [
                  _buildDrawerSectionLabel(theme, 'ACADEMIC & SCHOOL RECORDS'),
                  _buildDrawerTile(
                    context: context,
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.assessment_outlined,
                    title: 'Report Card & Term Grades',
                    subtitle: 'View Term 1–3 & Final Subject Grades',
                    accentColor: AppTheme.catTeal,
                    onTap: () {
                      Navigator.pop(context);
                      if (onOpenGrades != null) {
                        onOpenGrades!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParentGradesScreen(
                              initialStudent: student,
                              allChildren: allChildren,
                              onSelectChild: onSelectChild,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _buildDrawerTile(
                    context: context,
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.contact_phone_outlined,
                    title: 'Subject Teachers Directory',
                    subtitle: 'Public contact info & consultation hours',
                    accentColor: AppTheme.catBlue,
                    onTap: () {
                      Navigator.pop(context);
                      if (onOpenTeachers != null) {
                        onOpenTeachers!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParentTeacherContactView(
                              teacher: teacher,
                              student: student,
                              allChildren: allChildren,
                              onSelectChild: onSelectChild,
                            ),
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 12),
                  _buildDrawerSectionLabel(theme, 'MAIN NAVIGATION'),
                  _buildNavShortcutTile(
                    context: context,
                    theme: theme,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home Overview',
                    isSelected: currentBottomTabIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectBottomTab?.call(0);
                    },
                  ),
                  _buildNavShortcutTile(
                    context: context,
                    theme: theme,
                    icon: Icons.fact_check_outlined,
                    activeIcon: Icons.fact_check_rounded,
                    label: 'Attendance Records',
                    isSelected: currentBottomTabIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectBottomTab?.call(1);
                    },
                  ),
                  _buildNavShortcutTile(
                    context: context,
                    theme: theme,
                    icon: Icons.calendar_month_outlined,
                    activeIcon: Icons.calendar_month_rounded,
                    label: 'Class Schedule',
                    isSelected: currentBottomTabIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectBottomTab?.call(2);
                    },
                  ),
                  _buildNavShortcutTile(
                    context: context,
                    theme: theme,
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications_rounded,
                    label: 'School Alerts',
                    isSelected: currentBottomTabIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectBottomTab?.call(3);
                    },
                  ),
                  _buildNavShortcutTile(
                    context: context,
                    theme: theme,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Parent Profile',
                    isSelected: currentBottomTabIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectBottomTab?.call(4);
                    },
                  ),
                  _buildNavShortcutTile(
                    context: context,
                    theme: theme,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ParentSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Logout Footer ──
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.catRed,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppTheme.catRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  AppModals.showConfirmationDialog(
                    context: context,
                    title: 'Confirm Logout',
                    message:
                        'Are you sure you want to log out of the parent portal?',
                    confirmLabel: 'Logout',
                    confirmColor: AppTheme.catRed,
                    onConfirm: () async {
                      await LogoutHelper.logout(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.09,
          ),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildNavShortcutTile({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : null,
      leading: Icon(
        isSelected ? activeIcon : icon,
        size: 20,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}
