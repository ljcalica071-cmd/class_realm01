import 'package:flutter/material.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/shared/widgets/modals/change_password_modal.dart';
import 'package:class_realm/shared/widgets/modals/legal_documents_modal.dart';

/// Unified Settings list shared across Student, Parent, and Teacher portals.
/// Strictly follows the ordered sequence:
/// 1. Change Password (labeled Next Update)
/// 2. App Version
/// 3. Terms of Service
/// 4. Privacy Policy
class PortalSettingsContent extends StatefulWidget {
  final String portalLabel;

  const PortalSettingsContent({super.key, required this.portalLabel});

  @override
  State<PortalSettingsContent> createState() => _PortalSettingsContentState();
}

class _PortalSettingsContentState extends State<PortalSettingsContent> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(theme, 'SYSTEM SETTINGS & LEGAL POLICIES'),
        Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 1. Change Password
              ListTile(
                leading: Icon(
                  Icons.lock_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Update your account security password',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  final user = AuthRepository.instance.currentUser;
                  if (user != null) {
                    ChangePasswordModal.show(context, user: user);
                  }
                },
              ),
              Divider(height: 1, color: borderColor),

              // 3. App Version
              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'App Version',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Eduardo Barretto Senior Integrated School',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '2.0.0 (SSHS Edition)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Divider(height: 1, color: borderColor),

              // 4. Terms of Service
              ListTile(
                leading: Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Terms of Service',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Read our user responsibilities and acceptable use terms',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => LegalDocumentsModal.showTermsOfService(context),
              ),
              Divider(height: 1, color: borderColor),

              // 5. Privacy Policy
              ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'RA 10173 compliance & account deletion policy',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => LegalDocumentsModal.showPrivacyPolicy(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
