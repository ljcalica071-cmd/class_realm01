import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_schedule_view.dart';
import 'package:class_realm/features/parent/sub_features/communications/widgets/parent_teacher_contact_view.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/widgets/common/app_modals.dart';

class ParentDrawer extends StatelessWidget {
  final UserModel parent;
  final UserModel? linkedStudent;
  final UserModel teacher;

  const ParentDrawer({
    super.key,
    required this.parent,
    required this.linkedStudent,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.onPrimary,
                  radius: 28,
                  child: Icon(
                    Icons.family_restroom,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  parent.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  linkedStudent == null
                      ? 'No linked student'
                      : 'Linked Student: ${linkedStudent!.fullName} (${linkedStudent!.departmentOrSection})',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text("Student's Schedule"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentScheduleView(linkedStudent: linkedStudent),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_phone_outlined),
            title: const Text("Teacher Contact"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentTeacherContactView(teacher: teacher),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.catRed),
            title: const Text(
              'Logout',
              style: TextStyle(color: AppTheme.catRed),
            ),
            onTap: () {
              AppModals.showConfirmationDialog(
                context: context,
                title: 'Confirm Logout',
                message: 'Are you sure you want to log out of the parent portal?',
                confirmLabel: 'Logout',
                confirmColor: AppTheme.catRed,
                onConfirm: () async {
                  await AuthRepository.instance.logout();
                  if (context.mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
