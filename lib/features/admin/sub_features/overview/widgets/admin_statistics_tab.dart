import 'package:flutter/material.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/features/admin/sub_features/activity_analytics/widgets/admin_activity_analytics_tab.dart';

/// Deprecated prototype tab. Use [AdminActivityAnalyticsTab] instead.
@deprecated
class AdminStatisticsTab extends StatelessWidget {
  final List<UserModel>? teachers;
  final List<UserModel>? students;
  final List<UserModel>? parents;

  const AdminStatisticsTab({
    super.key,
    this.teachers,
    this.students,
    this.parents,
  });

  @override
  Widget build(BuildContext context) {
    return const AdminActivityAnalyticsTab();
  }
}
