import 'package:flutter/material.dart';
import 'package:class_realm/models/user_model.dart';

class AdminProfileTab extends StatelessWidget {
  final UserModel? adminUser;

  const AdminProfileTab({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = adminUser?.fullName ?? 'Administrator';
    final email = adminUser?.email ?? 'admin@classrealm.edu';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Administrator Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Full Name'),
              subtitle: Text(name),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Address'),
              subtitle: Text(email),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Access Level'),
              subtitle: Text('System-wide Administrator'),
            ),
          ],
        ),
      ),
    );
  }
}
