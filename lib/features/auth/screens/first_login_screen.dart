import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class FirstLoginScreen extends StatefulWidget {
  const FirstLoginScreen({super.key});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> with SingleTickerProviderStateMixin {
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Real-time validation states
  bool _hasMinLength = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    AppTheme.themeModeNotifier.value = ThemeMode.light;
    _newPassCtrl.addListener(_validatePassword);
    _confirmPassCtrl.addListener(_validateMatch);
  }

  void _validatePassword() {
    final v = _newPassCtrl.text;
    setState(() {
      _hasMinLength = v.length >= 8;
      _hasUpper = RegExp(r'[A-Z]').hasMatch(v);
      _hasLower = RegExp(r'[a-z]').hasMatch(v);
      _hasNumber = RegExp(r'[0-9]').hasMatch(v);
      _validateMatch();
    });
  }

  void _validateMatch() {
    setState(() {
      _passwordsMatch = _confirmPassCtrl.text.isNotEmpty && _confirmPassCtrl.text == _newPassCtrl.text;
    });
  }

  bool get _isValid => _hasMinLength && _hasUpper && _hasLower && _hasNumber && _passwordsMatch;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }


  void _submit() async {
    if (!_isValid) return;
    setState(() => _isLoading = true);
    if (!mounted) return;

    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      AppModals.showErrorDialog(
        context: context,
        title: 'Session Expired',
        message: 'No active session found. Please log in again.',
        onConfirm: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      );
      return;
    }

    if (user.role != UserRole.parent) {
      late Map<String, dynamic> otpResponse;
      try {
        otpResponse = await AuthRepository.instance.sendFirstLoginOtp();
      } catch (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Verification Code Not Sent',
          message: error.toString(),
        );
        return;
      }

      setState(() => _isLoading = false);
      if (!mounted) return;

      final bool? verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Theme(
          data: AppTheme.lightTheme,
          child: _PasswordOtpDialog(
            email: user.email,
            initialResendCooldown: (otpResponse['resendAfter'] as num?)?.toInt() ?? 60,
            initialInputCountdown: (otpResponse['expiresIn'] as num?)?.toInt() ?? 300,
            initialResendCount: (otpResponse['resendCount'] as num?)?.toInt() ?? 0,
          ),
        ),
      );

      if (verified != true) return;
    }

    setState(() => _isLoading = true);

    final error = await AuthRepository.instance.completeFirstLogin(
      user.id,
      _newPassCtrl.text.trim(),
    );

    if (error != null) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Password Setup Failed',
          message: error,
        );
      }
      return;
    }

    if (!mounted) return;
    final isUserDark = LocalStorageService.isUserDarkMode(user.id, email: user.email);
    AppTheme.themeModeNotifier.value = isUserDark ? ThemeMode.dark : ThemeMode.light;
    if (user.role == UserRole.teacher) {
      Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
    } else if (user.role == UserRole.parent) {
      Navigator.pushReplacementNamed(context, AppRoutes.parentHome);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
    }
  }

  Widget _buildValidationRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isValid ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
              fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final user = AuthRepository.instance.currentUser;
          final size = MediaQuery.of(context).size;
          final isDesktop = size.width >= 900;
          final theme = Theme.of(context);

          final displayName = user == null
              ? 'Faculty'
              : user.role == UserRole.teacher
              ? 'Teacher ${user.lastName ?? user.fullName}'
              : (user.firstName ?? user.fullName);

          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(AssetPaths.landingBackground, fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black45),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 460),
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F0F172A),
                            blurRadius: 35,
                            offset: Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
                                    ],
                                  ),
                                  child: Image.asset(AssetPaths.schoolLogo, height: 64, width: 64, fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Set New Password',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Welcome, $displayName! For security compliance, please set up your new personalized password.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // New Password
                          TextField(
                            controller: _newPassCtrl,
                            obscureText: _obscureNew,
                            maxLength: 30,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
                              FilteringTextInputFormatter.deny(RegExp(r'(.)\1{3,}')),
                            ],
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              labelStyle: const TextStyle(color: Color(0xFF64748B)),
                              hintText: '--------',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              prefixIcon: Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.primary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: const Color(0xFF64748B)),
                                onPressed: () => setState(() => _obscureNew = !_obscureNew),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Real-time Validation Rules
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildValidationRow('At least 8 characters', _hasMinLength),
                                _buildValidationRow('At least one uppercase letter', _hasUpper),
                                _buildValidationRow('At least one lowercase letter', _hasLower),
                                _buildValidationRow('At least one number', _hasNumber),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Confirm Password
                          TextField(
                            controller: _confirmPassCtrl,
                            obscureText: _obscureConfirm,
                            maxLength: 30,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
                              FilteringTextInputFormatter.deny(RegExp(r'(.)\1{3,}')),
                            ],
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              labelStyle: const TextStyle(color: Color(0xFF64748B)),
                              hintText: '--------',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              prefixIcon: Icon(Icons.lock_reset_outlined, size: 20, color: theme.colorScheme.primary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: const Color(0xFF64748B)),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _confirmPassCtrl.text.isEmpty
                                      ? theme.colorScheme.primary
                                      : (_passwordsMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _confirmPassCtrl.text.isEmpty
                                      ? const Color(0xFFCBD5E1)
                                      : (_passwordsMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ),
                          if (_confirmPassCtrl.text.isNotEmpty && !_passwordsMatch)
                            const Padding(
                              padding: EdgeInsets.only(top: 8, left: 12),
                              child: Text(
                                'Passwords do not match',
                                style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                              ),
                            ),
                            
                          const SizedBox(height: 32),

                          // Submit Button
                          AppPrimaryButton(
                            label: 'Activate Account & Set Password',
                            icon: Icons.check_circle_outline,
                            isLoading: _isLoading,
                            onPressed: _isValid ? _submit : null,
                          ),
                          const SizedBox(height: 14),

                          // Back to Login Link
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                AuthRepository.instance.logout();
                                AppTheme.themeModeNotifier.value = ThemeMode.light;
                                Navigator.pushReplacementNamed(context, AppRoutes.login);
                              },
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Back to Login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PasswordOtpDialog extends StatefulWidget {
  final String email;
  final int initialResendCooldown;
  final int initialInputCountdown;
  final int initialResendCount;

  const _PasswordOtpDialog({
    required this.email,
    this.initialResendCooldown = 60,
    this.initialInputCountdown = 300,
    this.initialResendCount = 0,
  });

  @override
  State<_PasswordOtpDialog> createState() => _PasswordOtpDialogState();
}

class _PasswordOtpDialogState extends State<_PasswordOtpDialog> {
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
      final result = await AuthRepository.instance.sendFirstLoginOtp();
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
      final result = await AuthRepository.instance.verifyFirstLoginOtp(code);
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
              const Text(
                'Verify Password Change',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
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
                      : const Text(
                          'Verify Account',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            ],
          ),
        ),
      ),
    );
  }
}
