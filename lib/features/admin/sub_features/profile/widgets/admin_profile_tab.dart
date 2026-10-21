import 'package:flutter/material.dart';
import 'package:class_realm/models/user_model.dart';

class AdminProfileTab extends StatelessWidget {
  final UserModel? adminUser;

  const AdminProfileTab({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = adminUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Profile information is unavailable.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Log in again or contact your system administrator.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final displayName = user.fullName.trim().isEmpty
        ? 'Name not provided'
        : user.fullName.trim();
    final email = user.email.trim().isEmpty ? 'Not provided' : user.email.trim();
    final initial = displayName == 'Name not provided'
        ? '?'
        : displayName.characters.first.toUpperCase();
    final role = user.role.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[0]}')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    final status = user.status.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[0]}')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Administrator Profile', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Your account details and access information.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(constraints.maxWidth < 600 ? 20 : 28),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: Text(
                            initial,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: (constraints.maxWidth - 180)
                              .clamp(160, 700)
                              .toDouble(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, detailsConstraints) {
                      final columns = detailsConstraints.maxWidth >= 900
                          ? 3
                          : (detailsConstraints.maxWidth >= 600 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: columns == 1 ? 4.2 : 2.5,
                        children: [
                          _ProfileDetailCard(
                            icon: Icons.badge_outlined,
                            label: 'Access role',
                            value: role,
                          ),
                          _ProfileDetailCard(
                            icon: Icons.verified_user_outlined,
                            label: 'Account status',
                            value: status,
                          ),
                          _ProfileDetailCard(
                            icon: Icons.alternate_email,
                            label: 'Email address',
                            value: email,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileDetailCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileDetailCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
