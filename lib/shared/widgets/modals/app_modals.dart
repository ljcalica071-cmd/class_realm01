import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/shared/widgets/buttons/app_buttons.dart';

class AppModals {
  static Future<void> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    String cancelLabel = 'Cancel',
    Color? confirmColor,
  }) {
    final theme = Theme.of(context);
    final isDelete = confirmLabel.trim().toLowerCase().contains('delete') ||
        title.trim().toLowerCase().contains('delete');
    final effectiveColor =
        confirmColor ?? (isDelete ? AppTheme.catRed : theme.colorScheme.primary);
    return showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: theme,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          backgroundColor: theme.colorScheme.surface,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: effectiveColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.help_outline_rounded, color: effectiveColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text(cancelLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    AppPrimaryButton(
                      label: confirmLabel,
                      backgroundColor: effectiveColor,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onConfirm();
                      },
                      height: 40,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: theme,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          backgroundColor: theme.colorScheme.surface,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.catRed.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: AppTheme.catRed, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppPrimaryButton(
                    label: 'OK',
                    backgroundColor: AppTheme.catRed,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (onConfirm != null) onConfirm();
                    },
                    width: 100,
                    height: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Close',
    VoidCallback? onConfirm,
  }) {
    final theme = Theme.of(context);
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SuccessDialog',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curvedVal = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curvedVal,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 20,
              backgroundColor: theme.colorScheme.surface,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Vector Checkmark Badge (Strictly Vector Icon, Zero Emojis)
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x4010B981),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        )
                            .animate()
                            .scale(
                              duration: 500.ms,
                              curve: Curves.elasticOut,
                            ),
                      ),
                    )
                        .animate()
                        .scale(
                          duration: 350.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 24),

                    // Dialog Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Message
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (onConfirm != null) onConfirm();
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(
                          confirmLabel,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> showWarningDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: theme,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          backgroundColor: theme.colorScheme.surface,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.catOrange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.catOrange, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppPrimaryButton(
                    label: 'OK',
                    backgroundColor: AppTheme.catOrange,
                    onPressed: () => Navigator.of(ctx).pop(),
                    width: 100,
                    height: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color? confirmColor,
  }) {
    final theme = Theme.of(context);
    final isDelete = confirmLabel.trim().toLowerCase().contains('delete') ||
        title.trim().toLowerCase().contains('delete');
    final effectiveColor =
        confirmColor ?? (isDelete ? AppTheme.catRed : theme.colorScheme.primary);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: theme,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          backgroundColor: theme.colorScheme.surface,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(cancelLabel,
                          style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                    ),
                    const SizedBox(width: 8),
                    AppPrimaryButton(
                      label: confirmLabel,
                      backgroundColor: effectiveColor,
                      onPressed: () => Navigator.of(ctx).pop(true),
                      height: 40,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Archive dialog with 5-second cooldown on the confirm button
  static Future<bool?> showArchiveCooldownDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Archive',
    String cancelLabel = 'Cancel',
    Color? confirmColor,
    int cooldownSeconds = 5,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = confirmColor ?? AppTheme.catOrange;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: theme,
        child: _ArchiveCooldownDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          confirmColor: effectiveColor,
          cooldownSeconds: cooldownSeconds,
        ),
      ),
    );
  }

  /// Permanent delete dialog requiring user to type 'I confirm'.
  /// Once 'I confirm' is typed, it automatically agrees and executes deletion (no delete button needed).
  /// Max 10 chars, inline validation with red border and message underneath.
  static Future<bool?> showTypeToConfirmDeleteDialog({
    required BuildContext context,
    required String title,
    required String message,
    String requiredText = 'I confirm',
    String cancelLabel = 'Cancel',
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: theme,
        child: _TypeToConfirmDeleteDialog(
          title: title,
          message: message,
          requiredText: requiredText,
          cancelLabel: cancelLabel,
        ),
      ),
    );
  }
}

class _ArchiveCooldownDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final int cooldownSeconds;

  const _ArchiveCooldownDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
    required this.cooldownSeconds,
  });

  @override
  State<_ArchiveCooldownDialog> createState() => _ArchiveCooldownDialogState();
}

class _ArchiveCooldownDialogState extends State<_ArchiveCooldownDialog> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.cooldownSeconds;
    if (_remainingSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          if (_remainingSeconds > 1) {
            _remainingSeconds--;
          } else {
            _remainingSeconds = 0;
            t.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCoolingDown = _remainingSeconds > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.confirmColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.archive_outlined,
                    color: widget.confirmColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    widget.cancelLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: isCoolingDown
                      ? null
                      : () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.confirmColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: widget.confirmColor.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: isCoolingDown ? 0 : 2,
                  ),
                  child: Text(
                    isCoolingDown
                        ? '${widget.confirmLabel} (${_remainingSeconds}s)'
                        : widget.confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToConfirmDeleteDialog extends StatefulWidget {
  final String title;
  final String message;
  final String requiredText;
  final String cancelLabel;

  const _TypeToConfirmDeleteDialog({
    required this.title,
    required this.message,
    required this.requiredText,
    required this.cancelLabel,
  });

  @override
  State<_TypeToConfirmDeleteDialog> createState() =>
      _TypeToConfirmDeleteDialogState();
}

class _TypeToConfirmDeleteDialogState extends State<_TypeToConfirmDeleteDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _inlineError;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (_hasTriggered) return;

    final trimmed = value.trim();
    final target = widget.requiredText.trim();

    // Automatic confirmation trigger when exact phrase is typed
    if (trimmed.toLowerCase() == target.toLowerCase()) {
      _hasTriggered = true;
      setState(() {
        _inlineError = null;
      });
      // Auto-submit immediately once "I confirm" is typed
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
      return;
    }

    setState(() {
      if (value.isNotEmpty &&
          !target.toLowerCase().startsWith(value.trimLeft().toLowerCase())) {
        _inlineError = "Please type '${widget.requiredText}' exactly.";
      } else {
        _inlineError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.catRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppTheme.catRed,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Instructional instruction
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'To confirm deletion, please type '),
                  TextSpan(
                    text: widget.requiredText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.catRed,
                    ),
                  ),
                  const TextSpan(
                    text: ' below. It will delete automatically once entered:',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Max 10 chars input field with real-time inline validation
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: 10,
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: _onTextChanged,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.requiredText,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  fontWeight: FontWeight.normal,
                ),
                counterText: '',
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _inlineError != null
                        ? AppTheme.catRed
                        : theme.colorScheme.outline.withValues(alpha: 0.25),
                    width: _inlineError != null ? 1.5 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _inlineError != null
                        ? AppTheme.catRed
                        : theme.colorScheme.primary,
                    width: 2.0,
                  ),
                ),
              ),
            ),

            // Strictly inline error underneath the input field (no bottom SnackBars)
            if (_inlineError != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.catRed,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: const TextStyle(
                        color: AppTheme.catRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    widget.cancelLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

