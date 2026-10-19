import 'package:flutter/material.dart';
import 'package:class_realm/features/admin/sub_features/broadcasts/widgets/admin_broadcasts_tab.dart';

/// Deprecated prototype tab. Use [AdminBroadcastsTab] instead.
@deprecated
class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminBroadcastsTab();
  }
}
