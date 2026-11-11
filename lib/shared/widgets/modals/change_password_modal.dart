import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/buttons/app_buttons.dart';
import 'package:class_realm/shared/widgets/modals/password_otp_dialog.dart';
import 'package:class_realm/shared/widgets/app_top_toast.dart';

/// Reusable In-App Change Password Modal.
/// Supports both Parent (current password re-authentication) and Email accounts
/// (Admin, Teacher, Student via current password re-auth + 2FA Email OTP).
/// Adheres strictly to the 60-30-10 color rule and inline input validation (no SnackBars).
class ChangePasswordModal extends StatefulWidget {
  final UserModel user;

  const ChangePasswordModal({super.key, required this.user});

  static Future<bool?> show(BuildContext context, {required UserModel user}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChangePasswordModal(user: user),
    );
  }

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final FocusNode _currentFocus = FocusNode();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _currentPassError;
  String? _newPassError;
  String? _confirmPassError;

  // Real-time password validation states
  bool _hasMinLength = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _passwordsMatch = false;

  bool get _isParent => widget.user.role == UserRole.parent;

  @override
  void initState() {
    super.initState();
    _currentPassCtrl.addListener(_onFieldsChanged);
    _newPassCtrl.addListener(_onFieldsChanged);
    _confirmPassCtrl.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    final password = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    final current = _currentPassCtrl.text;

    final result = AppValidators.validatePasswordComplexity(
      password: password,
      confirmPassword: confirm,
    );

    setState(() {
      _hasMinLength = result.hasMinLength;
      _hasUpper = result.hasUpper;
      _hasLower = result.hasLower;
      _hasNumber = result.hasNumber;
      _passwordsMatch = result.passwordsMatch;

      // Real-time live validation for confirm new password (matching forgot pass design)
      if (confirm.isNotEmpty) {
        if (!_passwordsMatch) {
          _confirmPassError = 'Passwords do not match';
        } else {
          _confirmPassError = null;
        }
      } else {
        _confirmPassError = null;
      }

      // Real-time check for same password
      if (password.isNotEmpty && current.isNotEmpty && password == current) {
        _newPassError = 'New password must be different from your current password.';
      } else if (_newPassError == 'New password must be different from your current password.' &&
          password != current) {
        _newPassError = null;
      }

      // Clear current password error when typing
      if (_currentPassError != null && current.isNotEmpty) {
        _currentPassError = null;
      }
    });
  }

  @override
  void dispose() {
    _currentPassCtrl.removeListener(_onFieldsChanged);
    _newPassCtrl.removeListener(_onFieldsChanged);
    _confirmPassCtrl.removeListener(_onFieldsChanged);
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final current = _currentPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    setState(() {
      _currentPassError = null;
      _newPassError = null;
      _confirmPassError = null;
    });

    bool hasClientError = false;

    if (current.isEmpty) {
      setState(() => _currentPassError = 'Current password is required.');
      hasClientError = true;
    }

    if (newPass.isEmpty) {
      setState(() => _newPassError = 'New password is required.');
      hasClientError = true;
    } else if (newPass == current) {
      setState(() {
        _newPassError = 'New password must be different from your current password.';
      });
      hasClientError = true;
    } else if (!_hasMinLength || !_hasUpper || !_hasLower || !_hasNumber) {
      setState(() {
        _newPassError = 'Password does not meet all complexity requirements.';
      });
      hasClientError = true;
    }

    if (confirm.isEmpty) {
      setState(() => _confirmPassError = 'Please confirm your new password.');
      hasClientError = true;
    } else if (confirm != newPass) {
      setState(() {
        _confirmPassError = 'Passwords do not match.';
      });
      hasClientError = true;
    }

    if (hasClientError) {
      return;
    }

    setState(() => _isLoading = true);

    // 1. Verify current password credentials before proceeding
    final authCheck = await AuthRepository.instance.reauthenticateCurrentPassword(current);
    if (authCheck != null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentPassError = authCheck;
      });
      return;
    }

    // 2. Branch: Parent vs Email Account
    if (_isParent) {
      // PARENT: Direct update via current password re-authentication
      final result = await AuthRepository.instance.changeParentPassword(
        parent: widget.user,
        currentPassword: current,
        newPassword: newPass,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result != null) {
        final field = result['field'];
        final msg = result['message'] ?? 'Failed to update password.';
        setState(() {
          if (field == 'current') {
            _currentPassError = msg;
          } else {
            _newPassError = msg;
          }
        });
        return;
      }

      AppTopToast.success(
        context,
        'Your parent account password has been changed successfully.',
      );
      Navigator.of(context).pop(true);
    } else {
      // EMAIL ROLES (Admin, Teacher, Student): 2FA Email OTP Verification
      late Map<String, dynamic> otpResult;
      try {
        otpResult = await AuthRepository.instance.sendChangePasswordOtp(
          email: widget.user.email,
          recipientName: widget.user.fullName,
        );
      } catch (err) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _newPassError = err.toString().replaceFirst('Exception: ', '');
        });
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PasswordOtpDialog(
          email: widget.user.email,
          title: 'Verify Password Change',
          subtitle: 'We sent a 6-digit verification code to:\n${widget.user.email}',
          submitButtonLabel: 'Verify & Update Password',
          initialResendCooldown: (otpResult['resendAfter'] as num?)?.toInt() ?? 60,
          initialInputCountdown: (otpResult['expiresIn'] as num?)?.toInt() ?? 300,
          onVerify: (code) => AuthRepository.instance.verifyChangePasswordOtp(code),
          onResend: () => AuthRepository.instance.sendChangePasswordOtp(
            email: widget.user.email,
            recipientName: widget.user.fullName,
            isResend: true,
          ),
        ),
      );

      if (verified != true || !mounted) {
        return;
      }

      setState(() => _isLoading = true);

      final updateError = await AuthRepository.instance.updatePasswordAfterChangeOtp(
        email: widget.user.email,
        currentPassword: current,
        newPassword: newPass,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (updateError != null) {
        setState(() => _newPassError = updateError);
        return;
      }

      AppTopToast.success(
        context,
        'Your password has been changed successfully.',
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryAccent = theme.colorScheme.primary;
    final surfaceColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569);

    return Dialog(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.lock,
                      color: primaryAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isParent
                              ? 'Enter your current password to set a new password.'
                              : 'Update your account security password with 2FA email verification.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondaryTextColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: secondaryTextColor,
                    ),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Current Password Field
              _buildPasswordField(
                label: 'Current Password',
                controller: _currentPassCtrl,
                focusNode: _currentFocus,
                obscureText: _obscureCurrent,
                onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                errorText: _currentPassError,
                isDark: isDark,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              // New Password Field
              _buildPasswordField(
                label: 'New Password',
                controller: _newPassCtrl,
                focusNode: _newFocus,
                obscureText: _obscureNew,
                onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                errorText: _newPassError,
                isDark: isDark,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              // Confirm New Password Field
              _buildPasswordField(
                label: 'Confirm New Password',
                controller: _confirmPassCtrl,
                focusNode: _confirmFocus,
                obscureText: _obscureConfirm,
                onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                errorText: _confirmPassError,
                isDark: isDark,
                textInputAction: TextInputAction.done,
                isConfirmField: true,
              ),
              const SizedBox(height: 18),

              // Complexity Checklist
              _buildComplexityChecklist(isDark),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: borderColor),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      label: _isParent ? 'Update Password' : 'Continue to Verification',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleSubmit,
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

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required String? errorText,
    required bool isDark,
    required TextInputAction textInputAction,
    bool isConfirmField = false,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    const errorColor = Color(0xFFDC2626);
    const successColor = Color(0xFF16A34A);
    final isConfirmSuccess = isConfirmField && controller.text.isNotEmpty && !hasError && _passwordsMatch;

    final borderColor = hasError
        ? errorColor
        : (isConfirmSuccess
            ? successColor
            : (isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1)));
    final focusedBorderColor = hasError
        ? errorColor
        : (isConfirmSuccess ? successColor : const Color(0xFF2563EB));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF334155),
              ),
            ),
            Text(
              '${controller.text.length}/50',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: controller.text.length >= 50
                    ? errorColor
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: (hasError || isConfirmSuccess) ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            maxLength: 50,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: AppValidators.passwordFormatters,
            textInputAction: textInputAction,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                ),
                onPressed: onToggleObscure,
                tooltip: obscureText ? 'Show password' : 'Hide password',
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle, size: 13, color: errorColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComplexityChecklist(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PASSWORD REQUIREMENTS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          _buildCheckItem('At least 8 characters', _hasMinLength, isDark),
          _buildCheckItem('At least 1 uppercase letter', _hasUpper, isDark),
          _buildCheckItem('At least 1 lowercase letter', _hasLower, isDark),
          _buildCheckItem('At least 1 number (0-9)', _hasNumber, isDark),
          _buildCheckItem('Passwords match', _passwordsMatch, isDark),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isMet, bool isDark) {
    const successColor = Color(0xFF16A34A);
    final unmetColor = isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            isMet ? LucideIcons.checkCircle2 : LucideIcons.circle,
            size: 14,
            color: isMet ? successColor : unmetColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
              color: isMet
                  ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                  : unmetColor,
            ),
          ),
        ],
      ),
    );
  }
}
