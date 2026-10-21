import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/auth/widgets/auth_responsive_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _newPassFocusNode = FocusNode();
  final FocusNode _confirmPassFocusNode = FocusNode();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Real-time password validation states
  bool _hasMinLength = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    AppTheme.themeModeNotifier.value = ThemeMode.light;
    _newPassController.addListener(_validatePasswordFields);
    _confirmPassController.addListener(_validatePasswordFields);
  }

  void _validatePasswordFields() {
    final password = _newPassController.text;
    final confirm = _confirmPassController.text;

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
    });
  }

  bool get _isFormValid {
    final email = _emailController.text.trim();
    final emailError = AppValidators.validateEmail(email);
    return emailError == null &&
        _hasMinLength &&
        _hasUpper &&
        _hasLower &&
        _hasNumber &&
        _passwordsMatch;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _emailFocusNode.dispose();
    _newPassFocusNode.dispose();
    _confirmPassFocusNode.dispose();
    super.dispose();
  }

  void _showParentRestoreyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.info,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Parent Account Restorey',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Parent accounts (@classrealm.com) do not use email OTP codes.\n\nPlease contact your child\'s Subject Teacher or Class Adviser. They can securely reset your password from the Teacher Portal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: 'Understood',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleResetFlow() async {
    final email = _emailController.text.trim().toLowerCase();

    // Check if parent account domain
    if (ParentCredentialHelper.isParentDomain(email)) {
      _showParentRestoreyDialog();
      return;
    }

    if (!_formKey.currentState!.validate() || !_isFormValid) {
      return;
    }

    final lockout = LocalStorageService.getOtpLockoutRemaining(email);
    if (lockout != null && lockout.inSeconds > 0) {
      final mins = (lockout.inSeconds / 60).ceil();
      AppModals.showErrorDialog(
        context: context,
        title: 'Account Temporarily Locked',
        message: 'Too many incorrect attempts. Please try again after $mins minute(s).',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Look up user account
      final user = await AuthRepository.instance.getUserByEmail(email);
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Account Not Found',
          message: 'It looks like there\'s no account associated with $email.\nPlease double-check your spelling or contact the ClassRealm Admin for assistance.',
        );
        return;
      }

      // Check if user has parent role
      if (user.role == UserRole.parent) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showParentRestoreyDialog();
        return;
      }

      // 2. Dispatch OTP via EmailService
      final otpResult = await AuthRepository.instance.sendForgotPasswordOtp(
        email: email,
        recipientName: user.fullName,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 3. Open shared PasswordOtpDialog modal (suppress autofill before opening modal)
      TextInput.finishAutofillContext(shouldSave: false);
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PasswordOtpDialog(
          email: email,
          title: 'Verify Password Reset',
          subtitle: 'We sent a 6-digit verification code to:\n$email',
          submitButtonLabel: 'Verify & Reset Password',
          initialResendCooldown: (otpResult['resendAfter'] as num?)?.toInt() ?? 60,
          initialInputCountdown: (otpResult['expiresIn'] as num?)?.toInt() ?? 300,
          onVerify: (code) => AuthRepository.instance.verifyForgotPasswordOtp(code),
          onResend: () => AuthRepository.instance.sendForgotPasswordOtp(
            email: email,
            recipientName: user.fullName,
            isResend: true,
          ),
        ),
      );

      if (verified != true || !mounted) {
        TextInput.finishAutofillContext(shouldSave: false);
        return;
      }

      // 4. Update forgotten password through strict security gate
      setState(() => _isLoading = true);
      final updateError = await AuthRepository.instance.updateForgottenPassword(
        email: email,
        newPassword: _newPassController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (updateError != null) {
        TextInput.finishAutofillContext(shouldSave: false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Password Reset Failed',
          message: updateError,
        );
        return;
      }

      // 5. Success confirmation (saving/updating is handled cleanly upon actual login)
      TextInput.finishAutofillContext(shouldSave: false);
      AppModals.showSuccessDialog(
        context: context,
        title: 'Password Reset Successful',
        message: 'Your account password has been updated securely. You can now log in using your new password.',
        confirmLabel: 'Proceed to Login',
        onConfirm: () {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      TextInput.finishAutofillContext(shouldSave: false);
      AppModals.showErrorDialog(
        context: context,
        title: 'Reset Request Failed',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthResponsiveScaffold(
      cardTitle: 'Reset Password',
      cardSubtitle: 'Eduardo Barretto Senior Integrated School',
      formChild: _buildFormContent(context),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Email input
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              inputFormatters: AppValidators.emailFormatters,
              onFieldSubmitted: (_) {
                FocusScope.of(context).requestFocus(_newPassFocusNode);
              },
              validator: AppValidators.validateEmail,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: AuthResponsiveScaffold.inputDecoration(
                hintText: 'Email address',
                prefixIcon: const Icon(
                  LucideIcons.mail,
                  color: Color(0xFF475569),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // New Password input
            TextFormField(
              controller: _newPassController,
              focusNode: _newPassFocusNode,
              obscureText: _obscureNew,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                FocusScope.of(context).requestFocus(_confirmPassFocusNode);
              },
              inputFormatters: AppValidators.passwordFormatters,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$currentLength/${maxLength ?? 50}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: currentLength >= (maxLength ?? 50)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
                    ),
                  ),
                );
              },
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: AuthResponsiveScaffold.inputDecoration(
                hintText: 'New password',
                prefixIcon: const Icon(
                  LucideIcons.lock,
                  color: Color(0xFF475569),
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Shared Password Requirements Checklist in Frosted Section
            AuthResponsiveScaffold.frostedSection(
              child: PasswordRequirementsChecklist(
                hasMinLength: _hasMinLength,
                hasUpper: _hasUpper,
                hasLower: _hasLower,
                hasNumber: _hasNumber,
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password input
            TextFormField(
              controller: _confirmPassController,
              focusNode: _confirmPassFocusNode,
              obscureText: _obscureConfirm,
              maxLength: 50,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_isFormValid && !_isLoading) {
                  _handleResetFlow();
                }
              },
              inputFormatters: AppValidators.passwordFormatters,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$currentLength/${maxLength ?? 50}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: currentLength >= (maxLength ?? 50)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
                    ),
                  ),
                );
              },
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: AuthResponsiveScaffold.inputDecoration(
                hintText: 'Confirm new password',
                prefixIcon: const Icon(
                  LucideIcons.lockKeyhole,
                  color: Color(0xFF475569),
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                focusedBorderColor: _confirmPassController.text.isEmpty
                    ? null
                    : (_passwordsMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                enabledBorderColor: _confirmPassController.text.isEmpty
                    ? null
                    : (_passwordsMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
              ),
            ),
            if (_confirmPassController.text.isNotEmpty && !_passwordsMatch)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Passwords do not match',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                ),
              ),

            const SizedBox(height: 24),

            // Reset Button
            AuthResponsiveScaffold.primaryButton(
              onPressed: _isFormValid && !_isLoading ? _handleResetFlow : null,
              isLoading: _isLoading,
              label: _isLoading ? 'VERIFYING...' : 'RESET PASSWORD',
            ),

            const SizedBox(height: 16),

            // Back to Login Link
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : () {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                icon: Icon(
                  LucideIcons.arrowLeft,
                  size: 16,
                  color: _isLoading ? const Color(0xFF94A3B8) : const Color(0xFF487898),
                ),
                label: Text(
                  'Back to Login',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _isLoading ? const Color(0xFF94A3B8) : const Color(0xFF487898),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
