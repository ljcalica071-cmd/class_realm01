import 'package:flutter/material.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/logout_helper.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/parent/sub_features/profile/screens/parent_settings_screen.dart';

class ParentProfileTab extends StatefulWidget {
  final UserModel parent;
  final UserModel? linkedStudent;
  final List<UserModel> allChildren;
  final ValueChanged<UserModel>? onSelectChild;
  final Future<void> Function()? onRefresh;

  const ParentProfileTab({
    super.key,
    required this.parent,
    required this.linkedStudent,
    this.allChildren = const [],
    this.onSelectChild,
    this.onRefresh,
  });

  @override
  State<ParentProfileTab> createState() => _ParentProfileTabState();
}

class _ParentProfileTabState extends State<ParentProfileTab> {
  late UserModel _liveParent;

  @override
  void initState() {
    super.initState();
    _liveParent = widget.parent;
    _hydrateParentProfile();
  }

  @override
  void didUpdateWidget(covariant ParentProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parent.id != widget.parent.id ||
        oldWidget.parent.fullName != widget.parent.fullName ||
        oldWidget.parent.email != widget.parent.email ||
        oldWidget.parent.birthday != widget.parent.birthday) {
      _liveParent = widget.parent;
      _hydrateParentProfile();
    }
  }

  Future<void> _hydrateParentProfile() async {
    if (_liveParent.id.isEmpty) return;
    try {
      final fresh = await SupabaseParentRepository().getParentProfile(
        _liveParent.id,
      );
      if (!mounted || fresh == null) return;
      setState(() {
        _liveParent = fresh;
      });
      await LocalStorageService.saveUser(fresh);
    } catch (_) {
      // Keep cached parent profile if offline
    }
  }

  Future<void> _handleRefresh() async {
    await _hydrateParentProfile();
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  void _openParentSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParentSettingsScreen()),
    );
  }

  String _formatBirthday(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Map<String, List<UserModel>> _groupStudentsByRelationship(
    List<UserModel> children,
  ) {
    final grouped = <String, List<UserModel>>{};
    for (final child in children) {
      final rawRel = (child.parentGuardianRelationship ?? '').trim();
      final category = rawRel.isNotEmpty ? rawRel : 'Guardian';
      grouped.putIfAbsent(category, () => <UserModel>[]).add(child);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final parent = _liveParent;
    final linkedStudent = widget.linkedStudent;

    final effectiveChildren = widget.allChildren.isNotEmpty
        ? widget.allChildren
        : (linkedStudent != null ? <UserModel>[linkedStudent] : <UserModel>[]);

    final groupedByRelationship = _groupStudentsByRelationship(
      effectiveChildren,
    );

    final initial = parent.fullName.trim().isNotEmpty
        ? parent.fullName.trim()[0].toUpperCase()
        : 'P';
    final emailValue = parent.email.trim().isNotEmpty
        ? parent.email.trim()
        : 'Not registered';
    final statusLabel = parent.status.name.isNotEmpty
        ? '${parent.status.name[0].toUpperCase()}${parent.status.name.substring(1)}'
        : 'Active';

    return AppPullToRefresh(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          // ── Parent Profile Hero Card ──
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Parent / Guardian Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  parent.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (parent.email.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    parent.email.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── PARENT / GUARDIAN INFORMATION ──
          _buildSectionHeader(theme, 'PARENT / GUARDIAN INFORMATION'),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.person_outline_rounded,
            title: 'Full Name',
            value: parent.fullName.trim().isNotEmpty
                ? parent.fullName.trim()
                : 'Parent / Guardian',
          ),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.email_outlined,
            title: 'Email Address',
            value: emailValue,
          ),
          if (parent.birthday != null)
            _buildInfoTile(
              theme: theme,
              isDark: isDark,
              icon: Icons.cake_outlined,
              title: 'Birthday',
              value: _formatBirthday(parent.birthday!),
            ),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.verified_user_outlined,
            title: 'Account Status',
            value: statusLabel,
          ),

          const SizedBox(height: 20),

          // ── LINKED STUDENTS BY RELATIONSHIP ──
          _buildSectionHeader(
            theme,
            'LINKED STUDENTS BY RELATIONSHIP (${effectiveChildren.length})',
          ),
          if (effectiveChildren.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.14 : 0.1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.family_restroom_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No students are currently linked to this parent account.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...groupedByRelationship.entries.map((entry) {
              final relationshipCategory = entry.key;
              final studentsInGroup = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isDark ? 0.14 : 0.1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.03,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.14 : 0.07,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.family_restroom_rounded,
                            size: 17,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            relationshipCategory.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${studentsInGroup.length} ${studentsInGroup.length == 1 ? "Student" : "Students"}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...studentsInGroup.asMap().entries.map((item) {
                      final idx = item.key;
                      final student = item.value;
                      final isActive = student.id == linkedStudent?.id;
                      return Column(
                        children: [
                          if (idx > 0)
                            Divider(
                              height: 1,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            leading: CircleAvatar(
                              radius: 17,
                              backgroundColor: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                              child: Text(
                                student.fullName.trim().isNotEmpty
                                    ? student.fullName.trim()[0].toUpperCase()
                                    : 'S',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              student.fullName,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            trailing: isActive
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.catGreen.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppTheme.catGreen.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Viewing',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.catGreen,
                                      ),
                                    ),
                                  )
                                : (widget.onSelectChild != null
                                      ? TextButton(
                                          onPressed: () => widget.onSelectChild!
                                              .call(student),
                                          child: const Text(
                                            'Switch',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      : null),
                            onTap: widget.onSelectChild != null
                                ? () => widget.onSelectChild!.call(student)
                                : null,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              );
            }),

          const SizedBox(height: 20),

          // ── SETTINGS & PRIVACY ──
          _buildSectionHeader(theme, 'SETTINGS & PRIVACY'),
          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.14 : 0.1,
                  ),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Notifications, password, app version, terms of service & privacy policy',
                  style: TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openParentSettings(context),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── ACCOUNT LOGOUT ──
          Material(
            color: AppTheme.catRed.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.catRed.withValues(alpha: isDark ? 0.35 : 0.2),
                ),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.catRed,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppTheme.catRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'Log out of your parent account',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  AppModals.showConfirmationDialog(
                    context: context,
                    title: 'Confirm Logout',
                    message:
                        'Are you sure you want to log out of the parent portal?',
                    confirmLabel: 'Logout',
                    confirmColor: AppTheme.catRed,
                    onConfirm: () => LogoutHelper.logout(context),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
