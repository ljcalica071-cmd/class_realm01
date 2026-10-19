import 'package:flutter/material.dart';
import 'package:class_realm/features/admin/sub_features/user_management/widgets/admin_add_teacher_dialog.dart';
import 'package:class_realm/routes/app_routes.dart';

class AdminAddTeacherScreen extends StatelessWidget {
  const AdminAddTeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Add New Teacher'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
            }
          },
        ),
      ),
      body: const SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: AdminAddTeacherDialog(),
          ),
        ),
      ),
    );
  }
}
