import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';

// ─────────────────────────────────────────────
// STATUS BADGE — Theme-aware, uses catX colors
// ─────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final bool isArchived;

  const StatusBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.isArchived = false,
  });

  factory StatusBadge.fromAccountStatus(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return StatusBadge(
          text: 'Active',
          backgroundColor: AppTheme.catGreen.withValues(alpha: 0.12),
          textColor: AppTheme.catGreen,
          icon: LucideIcons.checkCircle,
        );
      case AccountStatus.pending:
        return StatusBadge(
          text: 'First Login Pending',
          backgroundColor: AppTheme.catPurple.withValues(alpha: 0.12),
          textColor: AppTheme.catPurple,
          icon: LucideIcons.lockKeyhole,
        );
      case AccountStatus.rejected:
        return StatusBadge(
          text: 'Rejected',
          backgroundColor: AppTheme.catRed.withValues(alpha: 0.12),
          textColor: AppTheme.catRed,
          icon: LucideIcons.xCircle,
        );
      case AccountStatus.archived:
        return const StatusBadge(
          text: 'Archived',
          backgroundColor: Color(0xFFFEF3C7),
          textColor: Color(0xFFB45309),
          icon: LucideIcons.archive,
          isArchived: true,
        );
      case AccountStatus.pendingFirstLogin:
        return StatusBadge(
          text: 'First Login Pending',
          backgroundColor: AppTheme.catPurple.withValues(alpha: 0.12),
          textColor: AppTheme.catPurple,
          icon: LucideIcons.lockKeyhole,
        );
      case AccountStatus.deactivated:
        return StatusBadge(
          text: 'Deactivated',
          backgroundColor: AppTheme.catRed.withValues(alpha: 0.12),
          textColor: AppTheme.catRed,
          icon: LucideIcons.ban,
        );
    }
  }

  factory StatusBadge.fromAttendance(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return StatusBadge(
          text: 'Present',
          backgroundColor: AppTheme.catGreen.withValues(alpha: 0.12),
          textColor: AppTheme.catGreen,
        );
      case AttendanceStatus.late:
        return StatusBadge(
          text: 'Late',
          backgroundColor: AppTheme.catOrange.withValues(alpha: 0.12),
          textColor: AppTheme.catOrange,
        );
      case AttendanceStatus.absent:
        return StatusBadge(
          text: 'Absent',
          backgroundColor: AppTheme.catRed.withValues(alpha: 0.12),
          textColor: AppTheme.catRed,
        );
      case AttendanceStatus.excused:
        return StatusBadge(
          text: 'Excused',
          backgroundColor: AppTheme.catSlate.withValues(alpha: 0.12),
          textColor: AppTheme.catSlate,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color effectiveBg = backgroundColor;
    Color effectiveText = textColor;
    Border? effectiveBorder;

    if (isArchived) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      effectiveBg = isDark
          ? const Color(0xFFFBBF24).withValues(alpha: 0.16)
          : const Color(0xFFFEF3C7);
      effectiveText = isDark
          ? const Color(0xFFFACC15) // High-contrast radiant golden yellow for dark mode
          : const Color(0xFFB45309); // Deep amber-gold for light mode
      effectiveBorder = Border.all(
        color: isDark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.35)
            : const Color(0xFFFDE68A),
        width: 1,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(20),
        border: effectiveBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveText),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// APP SECTION BANNER — for Gradebook headers
// ─────────────────────────────────────────────
class AppSectionBanner extends StatelessWidget {
  final String title;
  final Color color;
  final IconData? icon;
  final List<Widget> trailing;

  const AppSectionBanner({
    super.key,
    required this.title,
    required this.color,
    this.icon,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// APP TABLE HEADER — consistent, theme-aware
// ─────────────────────────────────────────────
class AppTableHeader extends StatelessWidget {
  final List<AppTableColumn> columns;
  final bool hasCheckbox;
  final bool? isAllSelected;
  final ValueChanged<bool?>? onSelectAll;

  const AppTableHeader({
    super.key,
    required this.columns,
    this.hasCheckbox = false,
    this.isAllSelected,
    this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          if (hasCheckbox) ...[
            SizedBox(
              width: 24,
              child: Checkbox(
                value: isAllSelected,
                tristate: true,
                onChanged: onSelectAll,
                activeColor: theme.colorScheme.primary,
                side: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          ...columns.map((col) => Expanded(
            flex: col.flex,
            child: Text(
              col.label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )),
        ],
      ),
    );
  }
}

class AppTableColumn {
  final String label;
  final int flex;

  const AppTableColumn(this.label, {this.flex = 1});
}
