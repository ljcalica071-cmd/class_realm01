import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';

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
    await Future.delayed(const Duration(milliseconds: 600));
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
      builder: (ctx) => _PasswordOtpDialog(
        email: user.email,
        initialResendCooldown: (otpResponse['resendAfter'] as num?)?.toInt() ?? 90,
        initialInputCountdown: (otpResponse['expiresIn'] as num?)?.toInt() ?? 60,
        initialResendCount: (otpResponse['resendCount'] as num?)?.toInt() ?? 0,
      ),
    );

    if (verified != true) return;

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
    if (user.role == UserRole.teacher) {
      Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
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
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 460),
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 35,
                      offset: const Offset(0, 15),
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
                          Text(
                            'Set New Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Welcome, $displayName! For security compliance, please set up your new personalized password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.65), height: 1.4),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
                        FilteringTextInputFormatter.deny(RegExp(r'(.)\1{3,}')),
                      ],
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        hintText: '--------',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Real-time Validation Rules
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
                        FilteringTextInputFormatter.deny(RegExp(r'(.)\1{3,}')),
                      ],
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        hintText: '--------',
                        prefixIcon: const Icon(Icons.lock_reset_outlined, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _confirmPassCtrl.text.isEmpty
                                ? theme.colorScheme.primary
                                : (_passwordsMatch ? Colors.green : Colors.red),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _confirmPassCtrl.text.isEmpty
                                ? theme.colorScheme.outline
                                : (_passwordsMatch ? Colors.green : Colors.red.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ),
                    if (_confirmPassCtrl.text.isNotEmpty && !_passwordsMatch)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          'Passwords do not match',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                      
                    const SizedBox(height: 32),

                    // Submit Button
                    AppPrimaryButton(
                      label: 'Activate Account & Set Password',
                      icon: Icons.check_circle_outline,
                      isLoading: _isLoading,
                      // Disable button natively when validation is not complete
                      onPressed: _isValid ? _submit : null,
                    ),
                    const SizedBox(height: 14),

                    // Back to Login Link
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          AuthRepository.instance.logout();
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
  }
}

class _PasswordOtpDialog extends StatefulWidget {
  final String email;
  final int initialResendCooldown;
  final int initialInputCountdown;
  final int initialResendCount;

  const _PasswordOtpDialog({
    required this.email,
    this.initialResendCooldown = 90,
    this.initialInputCountdown = 60,
    this.initialResendCount = 0,
  });

  @override
  State<_PasswordOtpDialog> createState() => _PasswordOtpDialogState();
}

class _PasswordOtpDialogState extends State<_PasswordOtpDialog> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _hasError = false;
  bool _isVerifying = false;
  bool _isLockedOut = false;
  String? _verificationMessage;

  Timer? _resendTimer;
  int _resendCooldown = 90;
  int _resendAttempts = 0;

  Timer? _inputTimer;
  int _inputCountdown = 60;

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
        _resendCooldown = 90;
        _inputCountdown = 60;
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
          _verificationMessage = 'The code has expired. Request a new code.';
        });
        timer.cancel();
      } else {
        timer.cancel();
      }
    });
  }

  void _showTopNotification(String message, {bool isError = false}) {
    final theme = Theme.of(context);
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isError ? theme.colorScheme.error : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
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
                  Icon(
                    isError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
                    color: isError ? theme.colorScheme.onError : theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isError ? theme.colorScheme.onError : theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
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
    if (_resendAttempts >= 3) {
      _showTopNotification('Maximum resend attempts reached.', isError: true);
      return;
    }

    setState(() {
      _isResending = true;
      _hasError = false;
      _otpController.clear();
    });
    _formKey.currentState?.reset();

    try {
      final result = await AuthRepository.instance.sendFirstLoginOtp();
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _resendAttempts = (result['resendCount'] as num?)?.toInt() ?? _resendAttempts + 1;
        _resendCooldown = (result['resendAfter'] as num?)?.toInt() ?? 90;
        _inputCountdown = (result['expiresIn'] as num?)?.toInt() ?? 60;
        _verificationMessage = null;
      });
      _startTimers(reset: false);
      _showTopNotification('New verification code sent!');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showTopNotification(
        error.toString().contains('resend_limit')
            ? 'Maximum resend attempts reached. Try again later.'
            : 'Unable to resend the code. ${error.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _verify() async {
    if (_isVerifying || _isLockedOut || !_formKey.currentState!.validate()) return;
    setState(() {
      _isVerifying = true;
      _hasError = false;
      _verificationMessage = null;
    });
    try {
      final result = await AuthRepository.instance.verifyFirstLoginOtp(
        _otpController.text,
      );
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
          _verificationMessage = 'Too many incorrect codes. Try again after 15 minutes.';
        });
        _startTimers(reset: false);
        _showTopNotification(
          'Too many incorrect codes. Try again after 15 minutes.',
          isError: true,
        );
      } else {
        setState(() {
          _hasError = true;
          _verificationMessage = reason == 'expired'
              ? 'This code has expired. Request a new code.'
              : 'The verification code is incorrect.';
        });
        _showTopNotification(
          reason == 'expired'
              ? 'This code has expired. Request a new code.'
              : 'Incorrect code. ${result.attemptsRemaining ?? 0} attempts remaining.',
          isError: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _verificationMessage = error.toString());
      _showTopNotification('Unable to verify the code. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    _inputTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(32),
      title: null,
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.shieldCheck,
                  size: 38,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify password change',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit verification code to:\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _otpController,
                enabled: !_isLockedOut && !_isVerifying,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  color: _hasError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                onChanged: (_) {
                  if (_hasError) setState(() => _hasError = false);
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    letterSpacing: 12,
                  ),
                  errorText: _hasError ? 'Incorrect verification code' : null,
                  filled: true,
                  fillColor: _hasError
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.length != 6) {
                    return 'Enter the 6-digit code';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              if (_verificationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _verificationMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
              if (_isLockedOut)
                Text(
                  'Try again in ${(_inputCountdown ~/ 60).toString().padLeft(2, '0')}:${(_inputCountdown % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: theme.colorScheme.error,
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
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.timer,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expires in ${(_inputCountdown ~/ 60).toString().padLeft(2, '0')}:${(_inputCountdown % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'Code has expired. Please request a new one.',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _inputCountdown > 0 && !_isLockedOut && !_isVerifying
                      ? _verify
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Verify Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  _isResending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: !_isLockedOut &&
                                  _resendCooldown == 0 &&
                                  _resendAttempts < 3
                              ? _handleResend
                              : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            _resendAttempts >= 3
                                ? 'Limit Reached'
                                : _resendCooldown > 0
                                ? 'Resend in ${_resendCooldown}s'
                                : 'Resend',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _resendAttempts >= 3
                                  ? theme.colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel Password Change',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
