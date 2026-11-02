import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/logout_helper.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class ParentProfileTab extends StatefulWidget {
  final UserModel parent;
  final UserModel? linkedStudent;
  final Future<void> Function()? onRefresh;

  const ParentProfileTab({
    super.key,
    required this.parent,
    required this.linkedStudent,
    this.onRefresh,
  });

  @override
  State<ParentProfileTab> createState() => _ParentProfileTabState();
}

class _ParentProfileTabState extends State<ParentProfileTab> {
  bool _notificationsEnabled = true;

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? inlineError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded),
                  SizedBox(width: 10),
                  Text('Change Password', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your current password and choose a strong new password.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: oldPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        inlineError!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final oldP = oldPasswordController.text.trim();
                    final newP = newPasswordController.text.trim();
                    final confP = confirmPasswordController.text.trim();

                    if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
                      setDialogState(() {
                        inlineError = 'All password fields are required.';
                      });
                      return;
                    }
                    if (newP.length < 6) {
                      setDialogState(() {
                        inlineError = 'New password must be at least 6 characters.';
                      });
                      return;
                    }
                    if (newP != confP) {
                      setDialogState(() {
                        inlineError = 'New password and confirmation do not match.';
                      });
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    AppModals.showSuccessDialog(
                      context: context,
                      title: 'Password Updated',
                      message:
                          'Your password has been changed successfully. Please remember your new credentials.',
                    );
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPolicySheet(BuildContext context, String title, String content) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.88,
          expand: false,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final parent = widget.parent;
    final linkedStudent = widget.linkedStudent;

    final initial = parent.fullName.trim().isNotEmpty
        ? parent.fullName.trim()[0].toUpperCase()
        : 'P';
    final contactValue = parent.contactNumber?.trim().isNotEmpty == true
        ? parent.contactNumber!.trim()
        : 'Not provided';
    final emailValue = parent.email.trim().isNotEmpty
        ? parent.email.trim()
        : 'Not provided';

    final linkedStudentLabel = linkedStudent == null
        ? 'No linked student'
        : [
            linkedStudent.fullName,
            if (linkedStudent.departmentOrSection?.trim().isNotEmpty == true)
              linkedStudent.departmentOrSection!.trim(),
          ].join(' · ');

    return AppPullToRefresh(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          // ── Parent Profile Card ──
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

          // ── ACCOUNT & GUARDIANSHIP DETAILS ──
          _buildSectionHeader(theme, 'ACCOUNT & GUARDIANSHIP DETAILS'),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.family_restroom_outlined,
            title: 'Linked Student',
            value: linkedStudentLabel,
          ),
          if (linkedStudent != null)
            _buildInfoTile(
              theme: theme,
              isDark: isDark,
              icon: Icons.badge_outlined,
              title: 'Student LRN',
              value: linkedStudent.lrn?.trim().isNotEmpty == true
                  ? linkedStudent.lrn!.trim()
                  : 'Not provided',
            ),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.phone_outlined,
            title: 'Contact Number',
            value: contactValue,
          ),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.email_outlined,
            title: 'Email Address',
            value: emailValue,
          ),

          const SizedBox(height: 20),

          // ── PREFERENCES (SETTINGS) ──
          _buildSectionHeader(theme, 'PREFERENCES'),
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
              child: SwitchListTile(
                secondary: Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Enable Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Receive alerts for attendance and finalized term grades',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _notificationsEnabled,
                activeThumbColor: theme.colorScheme.primary,
                onChanged: (val) {
                  setState(() => _notificationsEnabled = val);
                  AppModals.showSuccessDialog(
                    context: context,
                    title: val ? 'Notifications Enabled' : 'Notifications Muted',
                    message: val
                        ? 'You will receive immediate alerts for your child\'s attendance and grades.'
                        : 'Notification alerts have been muted.',
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── SECURITY ──
          _buildSectionHeader(theme, 'SECURITY'),
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
                  Icons.lock_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Update your account security password',
                  style: TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showChangePasswordDialog(context),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── ABOUT CLASSREALM ──
          _buildSectionHeader(theme, 'ABOUT CLASSREALM'),
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
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text(
                      'App Version',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    trailing: Text(
                      '1.0.0 (SSHS Edition)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text(
                      'Terms of Service',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      _showPolicySheet(
                        context,
                        'Terms of Service',
                        'ClassRealm is designed exclusively for Senior High School (SSHS) educational tracking under DepEd curriculum standards. By using this platform, parents agree to use attendance and academic records respectfully and coordinate directly with teachers during authorized consultation hours.',
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text(
                      'Privacy Policy',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      _showPolicySheet(
                        context,
                        'Privacy Policy',
                        'We uphold the Philippine Data Privacy Act of 2012 (RA 10173). Student academic records, LRNs, and attendance logs are securely encrypted and made accessible strictly to authorized parents and designated teachers. Student daily drafts and pending submissions remain confidential to preserve student privacy.',
                      );
                    },
                  ),
                ],
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
                leading: const Icon(Icons.logout_rounded, color: AppTheme.catRed),
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
