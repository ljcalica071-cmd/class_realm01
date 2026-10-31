import 'package:flutter/material.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class ParentProfileTab extends StatelessWidget {
  final UserModel parent;
  final UserModel? linkedStudent;
  final Future<void> Function()? onRefresh;

  const ParentProfileTab({
    super.key,
    required this.parent,
    required this.linkedStudent,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initial = parent.fullName.trim().isNotEmpty
        ? parent.fullName.trim()[0].toUpperCase()
        : 'P';
    final contactValue = parent.contactNumber?.trim().isNotEmpty == true
        ? parent.contactNumber!.trim()
        : 'Not provided';
    final emailValue = parent.email.trim().isNotEmpty
        ? parent.email.trim()
        : 'Not provided';

    final linkedStudentLabel = linkedStudent == null
        ? 'No linked student'
        : [
            linkedStudent!.fullName,
            if (linkedStudent!.departmentOrSection?.trim().isNotEmpty == true)
              linkedStudent!.departmentOrSection!.trim(),
          ].join(' · ');

    return AppPullToRefresh(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Parent / Guardian Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  parent.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (parent.email.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    parent.email.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'ACCOUNT & GUARDIANSHIP DETAILS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.family_restroom_outlined,
            title: 'Linked Student',
            value: linkedStudentLabel,
          ),
          if (linkedStudent != null)
            _buildInfoTile(
              theme: theme,
              isDark: isDark,
              icon: Icons.badge_outlined,
              title: 'Student LRN',
              value: linkedStudent!.lrn?.trim().isNotEmpty == true
                  ? linkedStudent!.lrn!.trim()
                  : 'Not provided',
            ),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.phone_outlined,
            title: 'Contact Number',
            value: contactValue,
          ),
          _buildInfoTile(
            theme: theme,
            isDark: isDark,
            icon: Icons.email_outlined,
            title: 'Email Address',
            value: emailValue,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
