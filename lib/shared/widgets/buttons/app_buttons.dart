import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// SEMANTIC BUTTON TYPE ENUM
// ─────────────────────────────────────────────
enum AppButtonType {
  primary, // colorScheme.primary — main CTA (Add, Save, Submit, Import)
  success, // catGreen — confirm positive actions (Mark Present, Approve)
  danger, // catRed — destructive actions (Delete, Mark All Absent)
  warning, // catOrange — cautionary actions (Archive, Mark Late)
  outline, // Outlined + primary color — secondary actions (Cancel, View History)
  ghost, // Text-only — tertiary actions (View All, See more)
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
  final double? minWidth;
  final double height;
  final bool isSmall;
  final Color? backgroundColor;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.width,
    this.minWidth,
    this.height = 42,
    this.isSmall = false,
    this.backgroundColor,
  });

  // Convenience constructors for common semantic uses
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.minWidth,
    this.isSmall = false,
    this.backgroundColor,
  }) : type = AppButtonType.primary,
       height = 42;

  const AppButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.minWidth,
    this.isSmall = false,
    this.backgroundColor,
  }) : type = AppButtonType.success,
       height = 42;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.minWidth,
    this.isSmall = false,
    this.backgroundColor,
  }) : type = AppButtonType.danger,
       height = 42;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.minWidth,
    this.isSmall = false,
    this.backgroundColor,
  }) : type = AppButtonType.outline,
       height = 42;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.minWidth,
    this.isSmall = false,
    this.backgroundColor,
  }) : type = AppButtonType.outline,
       height = 42;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.minWidth,
    this.isSmall = false,
    this.backgroundColor,
  }) : type = AppButtonType.ghost,
       height = 42;

  Color _bgColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;
    final primary = Theme.of(context).colorScheme.primary;
    switch (type) {
      case AppButtonType.primary:
        return primary;
      case AppButtonType.success:
        return AppTheme.catGreen;
      case AppButtonType.danger:
        return AppTheme.catRed;
      case AppButtonType.warning:
        return AppTheme.catOrange;
      case AppButtonType.outline:
        return Colors.transparent;
      case AppButtonType.ghost:
        return Colors.transparent;
    }
  }

  Color _fgColor(BuildContext context) {
    if (backgroundColor != null) return Colors.white;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    switch (type) {
      case AppButtonType.primary:
      case AppButtonType.success:
      case AppButtonType.danger:
      case AppButtonType.warning:
        return Colors.white;
      case AppButtonType.outline:
        return primary;
      case AppButtonType.ghost:
        return onSurface.withValues(alpha: 0.75);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = _fgColor(context);
    final bg = _bgColor(context);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final double fontSize = isSmall ? 11.5 : (isMobile ? 12.5 : 13.0);
    final double iconSize = isSmall ? 14 : 16;
    final double h = isSmall ? 32 : height;
    final EdgeInsets padding = isSmall
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 8);

    final borderRadius = BorderRadius.circular(9);
    final isDark = theme.brightness == Brightness.dark;
    final bool isDisabled = !isLoading && onPressed == null;

    final Color disabledBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final Color disabledFg = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : const Color(0xFF94A3B8);
    final Color effectiveFg = isDisabled ? disabledFg : fg;

    final childRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: LoadingAnimationWidget.staggeredDotsWave(
              color: effectiveFg,
              size: iconSize * 1.5,
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: effectiveFg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: effectiveFg,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final constraints = BoxConstraints(
      minWidth: minWidth ?? (width ?? 0),
      maxWidth: width ?? double.infinity,
      minHeight: h,
      maxHeight: h,
    );

    if (type == AppButtonType.outline) {
      return ConstrainedBox(
        constraints: constraints,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            disabledForegroundColor: disabledFg,
            side: BorderSide(
              color: isDisabled
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFCBD5E1))
                  : theme.colorScheme.primary.withValues(alpha: 0.6),
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
      return ConstrainedBox(
        constraints: constraints,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: fg,
            disabledForegroundColor: disabledFg,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            padding: padding,
          ),
          onPressed: isLoading ? null : onPressed,
          child: childRow,
        ),
      );
    }

    return ConstrainedBox(
      constraints: constraints,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: disabledBg,
          disabledForegroundColor: disabledFg,
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
  final double? minWidth;
  final double height;
  final bool isSmall;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.width,
    this.minWidth,
    this.height = 42,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    AppButtonType resolvedType = AppButtonType.primary;
    final lower = label.trim().toLowerCase();
    if (backgroundColor == AppTheme.catRed ||
        lower == 'delete' ||
        lower.startsWith('delete') ||
        lower.contains('delete')) {
      resolvedType = AppButtonType.danger;
    } else if (backgroundColor == AppTheme.catOrange) {
      resolvedType = AppButtonType.warning;
    } else if (backgroundColor == AppTheme.catGreen) {
      resolvedType = AppButtonType.success;
    }

    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      width: width,
      minWidth: minWidth,
      height: height,
      isSmall: isSmall,
      type: resolvedType,
      backgroundColor: backgroundColor,
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? width;
  final double? minWidth;
  final double height;
  final bool isSmall;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.width,
    this.minWidth,
    this.height = 42,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      width: width,
      minWidth: minWidth,
      height: height,
      isSmall: isSmall,
      type: AppButtonType.outline,
    );
  }
}
