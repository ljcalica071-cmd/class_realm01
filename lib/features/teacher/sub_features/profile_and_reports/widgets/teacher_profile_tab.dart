import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';

class TeacherProfileTab extends StatelessWidget {
  const TeacherProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t =
        MockDatabase.instance.currentUser ??
        MockDatabase.instance.users.firstWhere(
          (user) => user.id == 'T001' || user.role == UserRole.teacher,
          orElse: () => const UserModel(
            id: 'T001',
            username: 'teacher',
            fullName: 'Teacher',
            email: 'teacher@classrealm.edu',
            role: UserRole.teacher,
          ),
        );
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
            Text(
              'Faculty Educator Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.person, color: theme.colorScheme.primary),
              title: Text('Full Name', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              subtitle: Text(t.fullName, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.email, color: theme.colorScheme.primary),
              title: Text('Institutional Email', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              subtitle: Text(t.email, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
              title: Text('Username / Faculty ID', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              subtitle: Text(t.username, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
            const Divider(),
            ListTile(
              leading: Image.asset(
                'assets/branding/school_logo.png',
                width: 24,
                height: 24,
              ),
              title: Text('School Institution', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              subtitle: Text('Eduardo Barretto Senior Integrated School', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.science, color: theme.colorScheme.primary),
              title: Text('Department / Subject Specialization', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              subtitle: Text(t.departmentOrSection ?? 'General Mathematics', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.manage_accounts_outlined, color: theme.colorScheme.primary),
              title: Text('Role', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              subtitle: Text(t.role.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
