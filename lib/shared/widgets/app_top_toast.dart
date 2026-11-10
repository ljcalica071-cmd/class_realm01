import 'dart:async';
import 'package:flutter/material.dart';

enum AppToastType { success, warning, error, info }

/// Global Floating Top Notification Banner
/// Appears centered at the top of the viewport with a smooth slide-down + fade-in
/// animation, auto-dismisses after 2 seconds with slide-up + fade-out,
/// and strictly throttles/replaces active banners to eliminate message spam.
class AppTopToast {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;
  static Timer? _hardFailsafeTimer;
  static _AppTopToastViewState? _activeState;

  /// Show a global top toast. If a toast is already displayed, it updates the message
  /// in-place and resets the 2-second cooldown, preventing spam and stacked banners.
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final defaultIcon = switch (type) {
      AppToastType.success => Icons.check_circle_rounded,
      AppToastType.warning => Icons.warning_amber_rounded,
      AppToastType.error => Icons.error_outline_rounded,
      AppToastType.info => Icons.info_outline_rounded,
    };

    final effectiveIcon = icon ?? defaultIcon;

    // If already showing, update content in-place without stacking
    if (_activeEntry != null && _activeState != null && _activeState!.mounted) {
      _activeState!.update(message: message, type: type, icon: effectiveIcon);
      _dismissTimer?.cancel();
      _hardFailsafeTimer?.cancel();
      _dismissTimer = Timer(duration, dismiss);
      _hardFailsafeTimer = Timer(duration + const Duration(milliseconds: 600), _forceClear);
      return;
    }

    _forceClear();

    late final OverlayEntry entry;
    void safeRemove() {
      try {
        if (entry.mounted) {
          entry.remove();
        }
      } catch (_) {}
      if (_activeEntry == entry) {
        _activeEntry = null;
        _activeState = null;
      }
    }

    entry = OverlayEntry(
      builder: (ctx) => _AppTopToastView(
        initialMessage: message,
        initialType: type,
        initialIcon: effectiveIcon,
        duration: duration,
        onMounted: (state) => _activeState = state,
        onDismissed: safeRemove,
      ),
    );

    _activeEntry = entry;
    try {
      overlay.insert(entry);
    } catch (_) {
      _activeEntry = null;
      return;
    }

    _dismissTimer?.cancel();
    _dismissTimer = Timer(duration, dismiss);

    // Hard failsafe: unconditionally removes overlay after duration + 500ms
    _hardFailsafeTimer?.cancel();
    _hardFailsafeTimer = Timer(duration + const Duration(milliseconds: 500), _forceClear);
  }

  static void success(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.success,
      icon: icon,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.warning,
      icon: icon,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.error,
      icon: icon,
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.info,
      icon: icon,
      duration: duration,
    );
  }

  /// Immediately dismisses the active toast with exit animation
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_activeState != null && _activeState!.mounted) {
      _activeState!.animateOut();
    } else {
      _forceClear();
    }
  }

  static void _forceClear() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _hardFailsafeTimer?.cancel();
    _hardFailsafeTimer = null;
    if (_activeEntry != null) {
      try {
        if (_activeEntry!.mounted) {
          _activeEntry?.remove();
        }
      } catch (_) {}
      _activeEntry = null;
      _activeState = null;
    }
  }
}

class _AppTopToastView extends StatefulWidget {
  final String initialMessage;
  final AppToastType initialType;
  final IconData initialIcon;
  final Duration duration;
  final ValueChanged<_AppTopToastViewState> onMounted;
  final VoidCallback onDismissed;

  const _AppTopToastView({
    required this.initialMessage,
    required this.initialType,
    required this.initialIcon,
    required this.duration,
    required this.onMounted,
    required this.onDismissed,
  });

  @override
  State<_AppTopToastView> createState() => _AppTopToastViewState();
}

class _AppTopToastViewState extends State<_AppTopToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  late String _message;
  late AppToastType _type;
  late IconData _icon;
  bool _isExiting = false;

  Timer? _viewDismissTimer;
  Timer? _viewHardKillTimer;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    _type = widget.initialType;
    _icon = widget.initialIcon;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();
    widget.onMounted(this);

    // Self-managed auto-dismiss timer ensures removal even if static timer was lost
    _viewDismissTimer = Timer(widget.duration, () {
      if (mounted) {
        animateOut();
      } else {
        widget.onDismissed();
      }
    });

    _viewHardKillTimer = Timer(widget.duration + const Duration(milliseconds: 600), () {
      widget.onDismissed();
    });
  }

  void update({
    required String message,
    required AppToastType type,
    required IconData icon,
  }) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _type = type;
      _icon = icon;
    });

    // Reset internal dismissal timers
    _viewDismissTimer?.cancel();
    _viewDismissTimer = Timer(widget.duration, () {
      if (mounted) {
        animateOut();
      } else {
        widget.onDismissed();
      }
    });

    _viewHardKillTimer?.cancel();
    _viewHardKillTimer = Timer(widget.duration + const Duration(milliseconds: 600), () {
      widget.onDismissed();
    });

    // Re-trigger the slide-in from top and fade-in smoothly for the new feedback message
    _controller.forward(from: 0.0);
  }

  void animateOut() {
    if (_isExiting) return;
    _isExiting = true;

    // Safety fallback: guaranteed cleanup after 420ms
    Timer(const Duration(milliseconds: 420), () {
      widget.onDismissed();
    });

    if (mounted) {
      _controller.reverse().whenComplete(() {
        widget.onDismissed();
      });
    } else {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _viewDismissTimer?.cancel();
    _viewHardKillTimer?.cancel();
    _controller.dispose();
    widget.onDismissed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Saturated high-contrast colors following 60-30-10 principles
    // Noticeably vibrant in light mode with clear solid borders and high-contrast text
    final (Color accentColor, Color bgCard, Color borderColor, Color textColor) =
        switch (_type) {
      AppToastType.success => (
          const Color(0xFF047857),
          isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
          isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
          isDark ? const Color(0xFFECFDF5) : const Color(0xFF064E3B),
        ),
      AppToastType.warning => (
          const Color(0xFFB45309),
          isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
          isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
          isDark ? const Color(0xFFFFFBEB) : const Color(0xFF78350F),
        ),
      AppToastType.error => (
          const Color(0xFFB91C1C),
          isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
          isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
          isDark ? const Color(0xFFFEF2F2) : const Color(0xFF7F1D1D),
        ),
      AppToastType.info => (
          const Color(0xFF1D4ED8),
          isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
          isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E3A8A),
        ),
    };

    return Positioned(
      top: media.padding.top + 54,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: animateOut,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 380,
                      maxWidth: 680,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(
                            alpha: isDark ? 0.45 : 0.16,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _icon,
                          size: 19,
                          color: accentColor,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
