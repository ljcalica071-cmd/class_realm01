import 'package:flutter/material.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/teacher_profile_tab.dart';

/// Settings tab for Teacher portal, seamlessly integrated into the Teacher Profile view.
class TeacherSettingsTab extends StatelessWidget {
  const TeacherSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherProfileTab(initialTab: 1);
  }
}
