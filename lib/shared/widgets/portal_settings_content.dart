import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/shared/services/in_app_notification_service.dart';
import 'package:class_realm/shared/widgets/buttons/app_buttons.dart';
import 'package:class_realm/shared/widgets/modals/app_modals.dart';
import 'package:class_realm/shared/widgets/modals/legal_documents_modal.dart';

/// Unified Settings list shared across Student, Parent, and Teacher portals.
/// Strictly follows the ordered sequence:
/// 1. Enable Notifications (labeled Next Update)
/// 2. Change Password (labeled Next Update)
/// 3. App Version
/// 4. Terms of Service
/// 5. Privacy Policy
/// 6. Save Changes
class PortalSettingsContent extends StatefulWidget {
  final String portalLabel;

  const PortalSettingsContent({
    super.key,
    required this.portalLabel,
  });

  @override
  State<PortalSettingsContent> createState() => _PortalSettingsContentState();
}

class _PortalSettingsContentState extends State<PortalSettingsContent> {
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = LocalStorageService.arePushNotificationsEnabled();
  }

  Widget _buildNextUpdateBadge(ThemeData theme) {
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        'Next Update',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(theme, 'SYSTEM SETTINGS & LEGAL POLICIES'),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              // 1. Enable Notifications
              SwitchListTile(
                secondary: Icon(
                  LucideIcons.bell,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Enable Push Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _notificationsEnabled
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFF64748B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _notificationsEnabled
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFF64748B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _notificationsEnabled ? 'Active' : 'Disabled',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _notificationsEnabled
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'Receive instant heads-up popup alerts for 3/6/10 attendance warnings and school notices',
                  style: TextStyle(fontSize: 12),
                ),
                value: _notificationsEnabled,
                activeThumbColor: theme.colorScheme.primary,
                onChanged: (val) {
                  setState(() => _notificationsEnabled = val);
                  LocalStorageService.setPushNotificationsEnabled(val);
                  if (val) {
                    InAppNotificationService.showBanner(
                      title: 'Push Notifications Enabled',
                      message: 'You will now receive instant pop-up alerts on this device.',
                      severity: InAppNotificationSeverity.info,
                    );
                  } else {
                    InAppNotificationService.dismiss();
                  }
                },
              ),
              Divider(height: 1, color: borderColor),

              // 2. Change Password
              ListTile(
                leading: Icon(
                  Icons.lock_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    _buildNextUpdateBadge(theme),
                  ],
                ),
                subtitle: const Text(
                  'Update your account security password',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  AppModals.showUpcomingFeatureDialog(
                    context,
                    featureName: 'In-App Password Change',
                  );
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Eduardo Barretto Senior Integrated School',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '1.0.0 (SSHS Edition)',
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
        const SizedBox(height: 20),

        // 6. Save Changes
        SizedBox(
          height: 48,
          child: AppButton.primary(
            icon: Icons.check_circle_outline_rounded,
            label: 'Save Changes (Next Update)',
            onPressed: () {
              AppModals.showUpcomingFeatureDialog(
                context,
                featureName: '${widget.portalLabel} Settings & Preferences',
              );
            },
          ),
        ),
      ],
    );
  }
}
