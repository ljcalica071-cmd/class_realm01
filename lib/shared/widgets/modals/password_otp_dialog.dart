import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

/// Reusable modal dialog for verifying a 6-digit OTP code dispatched via email.
/// Used in both First Login Activation and Forgot Password Recovery flows.
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
    this.initialInputCountdown = 300,
    this.initialResendCount = 0,
    this.onVerify,
    this.onResend,
  });

  @override
  State<PasswordOtpDialog> createState() => _PasswordOtpDialogState();
}

class _PasswordOtpDialogState extends State<PasswordOtpDialog> {
  final _otpController = TextEditingController();
  FocusNode? _otpFocusNode;
  FocusNode get _focusNode => _otpFocusNode ??= FocusNode();
  String? _error;
  bool _isVerifying = false;
  bool _isLockedOut = false;

  Timer? _resendTimer;
  int _resendCooldown = 60;
  int _resendAttempts = 0;

  Timer? _inputTimer;
  int _inputCountdown = 300;

  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _resendCooldown = widget.initialResendCooldown;
    _inputCountdown = widget.initialInputCountdown;
    _resendAttempts = widget.initialResendCount;
    _startTimers(reset: false);
  }

  void _startTimers({bool reset = true}) {
    if (reset) {
      setState(() {
        _resendCooldown = 60;
        _inputCountdown = 300;
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
        setState(() {
          _isLockedOut = false;
          _error = 'The code has expired. Request a new code.';
        });
        timer.cancel();
      } else {
        timer.cancel();
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
    if (_resendAttempts >= 4) {
      setState(() {
        _error = 'Maximum resend attempts reached.';
      });
      return;
    }

    setState(() {
      _isResending = true;
      _error = null;
      _otpController.clear();
    });

    try {
      final Map<String, dynamic> result;
      if (widget.onResend != null) {
        result = await widget.onResend!();
      } else {
        result = await AuthRepository.instance.sendFirstLoginOtp();
      }

      if (!mounted) return;
      setState(() {
        _isResending = false;
        _resendAttempts = (result['resendCount'] as num?)?.toInt() ?? _resendAttempts + 1;
        _resendCooldown = (result['resendAfter'] as num?)?.toInt() ?? 60;
        _inputCountdown = (result['expiresIn'] as num?)?.toInt() ?? 300;
        _error = null;
      });
      _startTimers(reset: false);
      _showResendSuccessToast('New verification code sent!');
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
        Navigator.pop(context, true);
        return;
      }

      final reason = result.reason;
      if (reason == 'locked') {
        setState(() {
          _isLockedOut = true;
          _inputCountdown = result.retryAfter > 0 ? result.retryAfter : 900;
          _error = 'Too many incorrect codes. Try again after 15 minutes.';
        });
        _startTimers(reset: false);
      } else {
        final remaining = result.attemptsRemaining ?? 0;
        setState(() {
          _error = reason == 'expired'
              ? 'This code has expired. Request a new code.'
              : 'Incorrect or expired code. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to verify code: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode?.dispose();
    _resendTimer?.cancel();
    _inputTimer?.cancel();
    super.dispose();
  }

  Widget _buildOtpDigitBoxes(ThemeData theme) {
    final hasError = _error != null;
    final currentLength = _otpController.text.length;

    return Stack(
      children: [
        // Invisible input field that handles keyboard, paste, backspace natively
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
                });
                if (val.length == 6 && !_isLockedOut && !_isVerifying) {
                  _verify();
                }
              },
            ),
          ),
        ),

        // Visual 6 separated digit boxes matching the UI design
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_isLockedOut && !_isVerifying) _focusNode.requestFocus();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < currentLength;
              final isCurrent =
                  index == currentLength && _focusNode.hasFocus && !hasError;
              final digit = isFilled ? _otpController.text[index] : '';

              Color borderColor;
              double borderWidth = 1.0;
              Color boxBg = const Color(0xFFF8FAFC);

              if (hasError) {
                borderColor = Colors.red.shade600;
                borderWidth = 1.8;
                boxBg = Colors.red.withValues(alpha: 0.04);
              } else if (isCurrent) {
                borderColor = const Color(0xFF2563EB);
                borderWidth = 2.0;
              } else if (isFilled) {
                borderColor = Colors.grey.shade400;
                borderWidth = 1.2;
              } else {
                borderColor = Colors.grey.shade300;
              }

              return Container(
                width: 48,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: Text(
                  digit,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: hasError
                        ? Colors.red.shade600
                        : const Color(0xFF0F172A),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(32),
        title: null,
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  size: 38,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 28),

              // Separated 6 digit boxes matching admin add teacher
              _buildOtpDigitBoxes(theme),

              // Single inline error message below the input field
              if (_error != null) ...[
                const SizedBox(height: 14),
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

              const SizedBox(height: 16),
              if (_isLockedOut)
                Text(
                  'Try again in ${(_inputCountdown ~/ 60).toString().padLeft(2, '0')}:${(_inputCountdown % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                )
              else if (_inputCountdown > 0)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey<int>(_inputCountdown > 0 ? 1 : 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.timer,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expires in ${(_inputCountdown ~/ 60).toString().padLeft(2, '0')}:${(_inputCountdown % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Text(
                  'Code has expired. Please request a new one.',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),

              const SizedBox(height: 24),
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

              const SizedBox(height: 18),
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
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isVerifying
                    ? null
                    : () {
                        Navigator.pop(context, false);
                      },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
