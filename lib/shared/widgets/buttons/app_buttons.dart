import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// SEMANTIC BUTTON TYPE ENUM
// ─────────────────────────────────────────────
enum AppButtonType {
  primary,   // colorScheme.primary — main CTA (Add, Save, Submit, Import)
  success,   // catGreen — confirm positive actions (Mark Present, Approve)
  danger,    // catRed — destructive actions (Delete, Mark All Absent)
  warning,   // catOrange — cautionary actions (Archive, Mark Late)
  outline,   // Outlined + primary color — secondary actions (Cancel, View History)
  ghost,     // Text-only — tertiary actions (View All, See more)
}

// ─────────────────────────────────────────────
// APP BUTTON — Semantic, Theme-aware
// ─────────────────────────────────────────────
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonType type;
  final bool isLoading;
  final double? width;
  final double height;
  final bool isSmall;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.width,
    this.height = 42,
    this.isSmall = false,
  });

  // Convenience constructors for common semantic uses
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.isSmall = false,
  })  : type = AppButtonType.primary,
        height = 42;

  const AppButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.isSmall = false,
  })  : type = AppButtonType.success,
        height = 42;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.isSmall = false,
  })  : type = AppButtonType.danger,
        height = 42;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.isSmall = false,
  })  : type = AppButtonType.outline,
        height = 42;

  Color _bgColor(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    switch (type) {
      case AppButtonType.primary: return primary;
      case AppButtonType.success: return AppTheme.catGreen;
      case AppButtonType.danger:  return AppTheme.catRed;
      case AppButtonType.warning: return AppTheme.catOrange;
      case AppButtonType.outline: return Colors.transparent;
      case AppButtonType.ghost:   return Colors.transparent;
    }
  }

  Color _fgColor(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    switch (type) {
      case AppButtonType.primary:
      case AppButtonType.success:
      case AppButtonType.danger:
      case AppButtonType.warning: return Colors.white;
      case AppButtonType.outline: return primary;
      case AppButtonType.ghost:   return onSurface.withValues(alpha: 0.75);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = _fgColor(context);
    final bg = _bgColor(context);
    final double fontSize = isSmall ? 12 : 14;
    final double iconSize = isSmall ? 15 : 17;
    final double h = isSmall ? 34 : height;
    final EdgeInsets padding = isSmall
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    final borderRadius = BorderRadius.circular(9);

    final childRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ],
    );

    if (type == AppButtonType.outline) {
      return SizedBox(
        width: width,
        height: h,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            padding: padding,
          ),
          onPressed: isLoading ? null : onPressed,
          child: childRow,
        ),
      );
    }

    if (type == AppButtonType.ghost) {
      return SizedBox(
        width: width,
        height: h,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: fg,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            padding: padding,
          ),
          onPressed: isLoading ? null : onPressed,
          child: childRow,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          padding: padding,
        ),
        onPressed: isLoading ? null : onPressed,
        child: childRow,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LEGACY WRAPPERS (backward-compatible)
// ─────────────────────────────────────────────
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final double? width;
  final double height;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.width,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      width: width,
      height: height,
      type: AppButtonType.primary,
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? width;
  final double height;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.width,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      width: width,
      height: height,
      type: AppButtonType.outline,
    );
  }
}
