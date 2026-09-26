import 'package:flutter/material.dart';
import 'package:class_realm/models/user_model.dart';

class ParentProfileTab extends StatelessWidget {
  final UserModel parent;
  final UserModel? linkedStudent;

  const ParentProfileTab({
    super.key,
    required this.parent,
    required this.linkedStudent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primary,
            child: Icon(Icons.person, size: 48, color: theme.colorScheme.onPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            parent.fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            parent.email,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('Linked Student'),
            subtitle: Text(
              linkedStudent == null
                  ? 'No linked student'
                  : '${linkedStudent!.fullName} (${linkedStudent!.departmentOrSection})',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Contact Number'),
            subtitle: Text(parent.contactNumber ?? '+63 917 123 4567'),
          ),
        ],
      ),
    );
  }
}
