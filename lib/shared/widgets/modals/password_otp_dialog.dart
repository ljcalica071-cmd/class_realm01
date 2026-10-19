import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

/// Reusable modal dialog for verifying a 6-digit OTP code dispatched via email.
/// Used in both First Login Activation and Forgot Password Recovery flows.
/// Features anti-spam rate limiting, animated cursor, 6 separate digit boxes,
/// inline countdown timer placed directly above the boxes, and top-right close button.
class PasswordOtpDialog extends StatefulWidget {
  final String email;
  final String title;
  final String? subtitle;
  final String submitButtonLabel;
  final int initialResendCooldown;
  final int initialInputCountdown;
  final int initialResendCount;
  final Future<FirstLoginOtpVerification> Function(String code)? onVerify;
  final Future<Map<String, dynamic>> Function()? onResend;

  const PasswordOtpDialog({
    super.key,
    required this.email,
    this.title = 'Verify Password Change',
    this.subtitle,
    this.submitButtonLabel = 'Verify Account',
    this.initialResendCooldown = 60,
    this.initialInputCountdown = 600,
    this.initialResendCount = 0,
    this.onVerify,
    this.onResend,
  });

  @override
  State<PasswordOtpDialog> createState() => _PasswordOtpDialogState();
}

class _PasswordOtpDialogState extends State<PasswordOtpDialog>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  AnimationController? _cursorBlinkController;
  int _selectedIndex = 0;

  String? _error;
  bool _isVerifying = false;
  bool _isLockedOut = false;
  int _failedAttempts = 0;

  Timer? _resendTimer;
  int _resendCooldown = 60;
  int _resendAttempts = 0;

  Timer? _inputTimer;
  int _inputCountdown = 600;

  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    final lockout = LocalStorageService.getOtpLockoutRemaining(widget.email);
    if (lockout != null && lockout.inSeconds > 0) {
      _isLockedOut = true;
      _inputCountdown = lockout.inSeconds;
      _resendCooldown = 60;
      _resendAttempts = 4;
      _error = 'Too many incorrect attempts. Please try again after 10 minutes.';
    } else {
      _resendCooldown = widget.initialResendCooldown;
      _inputCountdown = widget.initialInputCountdown;
      _resendAttempts = widget.initialResendCount;
    }

    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _handleBackspaceKey();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1).clamp(0, _otpController.text.length);
            _otpController.selection =
                TextSelection.collapsed(offset: _selectedIndex);
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() {
            _selectedIndex =
                (_selectedIndex + 1).clamp(0, _otpController.text.length);
            _otpController.selection =
                TextSelection.collapsed(offset: _selectedIndex);
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    _startTimers(reset: false);
  }

  void _startTimers({bool reset = true}) {
    if (reset) {
      setState(() {
        _resendCooldown = 60;
        _inputCountdown = 600;
        _isLockedOut = false;
      });
    }

    _resendTimer?.cancel();
    _inputTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });

    _inputTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_inputCountdown > 0) {
        setState(() => _inputCountdown--);
      } else if (_isLockedOut) {
        LocalStorageService.clearOtpLockout(widget.email);
        setState(() {
          _isLockedOut = false;
          _failedAttempts = 0;
          _error = 'Lockout period ended. Please request a new verification code.';
        });
        timer.cancel();
      } else {
        setState(() {
          _error = 'The verification code has expired. Please request a new code.';
        });
        timer.cancel();
      }
    });
  }

  String _formatOtpTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _handleBackspaceKey() {
    if (_isLockedOut || _isVerifying) return;
    final text = _otpController.text;
    if (text.isEmpty) {
      if (_error != null) setState(() => _error = null);
      return;
    }

    final sel = _otpController.selection;
    if (!sel.isCollapsed && sel.start >= 0 && sel.end <= text.length) {
      final newText = text.substring(0, sel.start) + text.substring(sel.end);
      final nextIndex = sel.start.clamp(0, newText.length);
      _otpController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: nextIndex),
      );
      setState(() {
        _selectedIndex = nextIndex;
        _error = null;
      });
      return;
    }

    int deletePos = _selectedIndex;
    if (deletePos > 0 && deletePos <= text.length) {
      final newText =
          text.substring(0, deletePos - 1) + text.substring(deletePos);
      final nextIndex = (deletePos - 1).clamp(0, newText.length);
      _otpController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: nextIndex),
      );
      setState(() {
        _selectedIndex = nextIndex;
        _error = null;
      });
    } else if (deletePos == 0 && text.isNotEmpty) {
      final newText = text.substring(1);
      _otpController.value = TextEditingValue(
        text: newText,
        selection: const TextSelection.collapsed(offset: 0),
      );
      setState(() {
        _selectedIndex = 0;
        _error = null;
      });
    } else {
      final newText = text.substring(0, text.length - 1);
      final nextIndex = newText.length;
      _otpController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: nextIndex),
      );
      setState(() {
        _selectedIndex = nextIndex;
        _error = null;
      });
    }
  }

  void _onDigitBoxTapped(int index) {
    if (_isLockedOut || _isVerifying) return;
    _focusNode.requestFocus();
    final text = _otpController.text;
    setState(() {
      _error = null;
      if (index < text.length) {
        _selectedIndex = index;
        _otpController.selection = TextSelection(
          baseOffset: index,
          extentOffset: index + 1,
        );
      } else {
        _selectedIndex = text.length.clamp(0, 5);
        _otpController.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
    });
  }

  void _showResendSuccessToast(String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.checkCircle2,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  Future<void> _handleResend() async {
    final lockout = LocalStorageService.getOtpLockoutRemaining(widget.email);
    if (lockout != null && lockout.inSeconds > 0) {
      final mins = (lockout.inSeconds / 60).ceil();
      setState(() => _error = 'Too many incorrect attempts. Please try again after $mins minute(s).');
      return;
    }

    if (_resendAttempts >= 4 ||
        _resendCooldown > 0 ||
        _isLockedOut ||
        _isVerifying ||
        _isResending) {
      if (_resendAttempts >= 4) {
        setState(() => _error = 'Maximum resend attempts reached.');
      }
      return;
    }

    setState(() {
      _isResending = true;
      _error = null;
      _otpController.clear();
      _selectedIndex = 0;
    });

    try {
      final Map<String, dynamic> result;
      if (widget.onResend != null) {
        result = await widget.onResend!();
      } else {
        result =
            await AuthRepository.instance.sendFirstLoginOtp(isResend: true);
      }

      if (!mounted) return;
      setState(() {
        _isResending = false;
        _resendAttempts =
            (result['resendCount'] as num?)?.toInt() ?? _resendAttempts + 1;
        _resendCooldown = (result['resendAfter'] as num?)?.toInt() ?? 60;
        _inputCountdown = (result['expiresIn'] as num?)?.toInt() ?? 600;
        _error = null;
      });
      _startTimers(reset: false);
      _showResendSuccessToast('New verification code sent!');
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focusNode.requestFocus();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _error = error.toString().contains('resend_limit')
            ? 'Maximum resend attempts reached. Try again later.'
            : 'Unable to resend code: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (_isVerifying || _isLockedOut || code.length != 6) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final FirstLoginOtpVerification result;
      if (widget.onVerify != null) {
        result = await widget.onVerify!(code);
      } else {
        result = await AuthRepository.instance.verifyFirstLoginOtp(code);
      }

      if (!mounted) return;
      if (result.verified) {
        await LocalStorageService.clearOtpLockout(widget.email);
        Navigator.pop(context, true);
        return;
      }

      _failedAttempts++;
      final reason = result.reason;
      if (reason == 'locked' || _failedAttempts >= 5) {
        await LocalStorageService.setOtpLockout(
          widget.email,
          const Duration(minutes: 10),
        );
        setState(() {
          _isLockedOut = true;
          _inputCountdown = result.retryAfter > 0 ? result.retryAfter : 600;
          _error =
              'Too many incorrect attempts. Please try again after 10 minutes.';
          _otpController.clear();
          _selectedIndex = 0;
        });
        _startTimers(reset: false);
      } else {
        final remaining =
            result.attemptsRemaining ?? (5 - _failedAttempts).clamp(0, 5);
        setState(() {
          _error = reason == 'expired'
              ? 'This code has expired. Request a new code.'
              : 'Incorrect or expired code. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
          // Clear field so user can enter the correct 6-digit code on next attempt
          _otpController.clear();
          _selectedIndex = 0;
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _focusNode.requestFocus();
        });
      }
    } catch (error) {
      if (!mounted) return;
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        await LocalStorageService.setOtpLockout(
          widget.email,
          const Duration(minutes: 10),
        );
        setState(() {
          _isLockedOut = true;
          _inputCountdown = 600;
          _error =
              'Too many incorrect attempts. Please try again after 10 minutes.';
          _otpController.clear();
          _selectedIndex = 0;
        });
        _startTimers(reset: false);
      } else {
        setState(() {
          _error =
              'Unable to verify code: ${error.toString().replaceFirst('Exception: ', '')}';
          _otpController.clear();
          _selectedIndex = 0;
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _focusNode.requestFocus();
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _cursorBlinkController?.dispose();
    _cursorBlinkController = null;
    _otpController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    _inputTimer?.cancel();
    super.dispose();
  }

  Widget _buildOtpDigitBoxes(ThemeData theme) {
    final hasError = _error != null;
    final currentLength = _otpController.text.length;
    final isFocused = _focusNode.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Invisible input field that catches keyboard text and system paste
            Positioned.fill(
              child: Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: _otpController,
                  focusNode: _focusNode,
                  autofocus: true,
                  enabled: !_isLockedOut && !_isVerifying,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (!_isLockedOut) _error = null;
                      _selectedIndex = val.length.clamp(0, 5);
                    });
                    if (val.length == 6 && !_isLockedOut && !_isVerifying) {
                      _verify();
                    }
                  },
                ),
              ),
            ),

            // Visual 6 separated digit boxes with proper focus, cursor & selection indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < currentLength;
                final digit = isFilled ? _otpController.text[index] : '';

                final isSelected = isFocused && (_selectedIndex == index);
                final isNextEmpty = isFocused &&
                    (index == currentLength && currentLength < 6) &&
                    (_selectedIndex >= currentLength);
                final isActive = (isSelected || isNextEmpty) && !_isLockedOut;

                Color borderColor;
                double borderWidth = 1.0;
                Color boxBg;
                List<BoxShadow>? shadows;

                if (hasError) {
                  borderColor = Colors.red.shade500;
                  borderWidth = isActive ? 2.0 : 1.6;
                  boxBg = Colors.red.withValues(alpha: 0.04);
                  if (isActive) {
                    shadows = [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.18),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ];
                  }
                } else if (isActive) {
                  borderColor = const Color(0xFF2563EB);
                  borderWidth = 2.2;
                  boxBg = const Color(0xFF2563EB).withValues(alpha: 0.06);
                  shadows = [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ];
                } else if (isFilled) {
                  borderColor = const Color(0xFF94A3B8);
                  borderWidth = 1.4;
                  boxBg = Colors.white;
                } else {
                  borderColor = const Color(0xFFCBD5E1);
                  borderWidth = 1.0;
                  boxBg = const Color(0xFFF8FAFC);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onDigitBoxTapped(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 48,
                    height: 58,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: boxBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                      boxShadow: shadows,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (digit.isNotEmpty)
                          Text(
                            digit,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: hasError
                                  ? Colors.red.shade600
                                  : const Color(0xFF0F172A),
                            ),
                          )
                        else if (isActive && _cursorBlinkController != null)
                          FadeTransition(
                            opacity: _cursorBlinkController!,
                            child: Container(
                              width: 2.2,
                              height: 24,
                              decoration: BoxDecoration(
                                color: hasError
                                    ? Colors.red.shade600
                                    : const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),

                        if (isFilled && isActive && !hasError)
                          Positioned(
                            bottom: 6,
                            child: Container(
                              width: 18,
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),

        // Clear code action button
        if (_otpController.text.isNotEmpty &&
            !_isLockedOut &&
            !_isVerifying) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _otpController.clear();
                _selectedIndex = 0;
                _error = null;
              });
              _focusNode.requestFocus();
            },
            child: const Text(
              'Clear code',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isVerifying,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        title: null,
        content: SizedBox(
          width: 380,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Top-right Close ('X') button replacing bottom Cancel button
              Positioned(
                top: -12,
                right: -12,
                child: IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF64748B)),
                  splashRadius: 20,
                  tooltip: 'Close',
                  onPressed: _isVerifying ? null : () => Navigator.pop(context, false),
                ),
              ),

              // Modal Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),

                  // Shield Icon
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.shieldCheck,
                      size: 36,
                      color: Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    widget.subtitle ??
                        'We sent a 6-digit verification code to:\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 1. Timer badge placed DIRECTLY ABOVE the 6 input boxes
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _inputCountdown <= 60
                          ? Colors.red.withValues(alpha: 0.08)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _inputCountdown <= 60
                            ? Colors.red.shade400
                            : const Color(0xFFBFDBFE),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 14,
                          color: _inputCountdown <= 60
                              ? Colors.red.shade600
                              : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isLockedOut
                              ? 'Locked: try again in ${_formatOtpTimer(_inputCountdown)}'
                              : _inputCountdown > 0
                                  ? 'Expires in ${_formatOtpTimer(_inputCountdown)}'
                                  : 'Code expired (time passed)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: _inputCountdown <= 60 || _isLockedOut
                                ? Colors.red.shade700
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. 6-digit OTP input boxes with active cursor & selection indicators
                  _buildOtpDigitBoxes(theme),

                  // 3. Error message below input field
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // 4. Verify Account Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _inputCountdown > 0 &&
                              !_isLockedOut &&
                              !_isVerifying &&
                              _otpController.text.length == 6
                          ? _verify
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isVerifying
                          ? LoadingAnimationWidget.staggeredDotsWave(
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              widget.submitButtonLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Resend Code Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive the code? ",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      _isResending
                          ? LoadingAnimationWidget.staggeredDotsWave(
                              color: const Color(0xFF2563EB),
                              size: 16,
                            )
                          : OutlinedButton(
                              onPressed: !_isLockedOut &&
                                      _resendCooldown == 0 &&
                                      _resendAttempts < 4
                                  ? _handleResend
                                  : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8FAFC),
                                side:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _resendAttempts >= 4
                                    ? 'Limit Reached'
                                    : _resendCooldown > 0
                                        ? 'Resend in ${_resendCooldown}s'
                                        : 'Resend',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _resendAttempts >= 4
                                      ? const Color(0xFFDC2626)
                                      : _resendCooldown > 0
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
