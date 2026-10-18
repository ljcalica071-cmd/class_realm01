import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

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

  void _showParentRecoveryDialog() {
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
                'Parent Account Recovery',
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
      _showParentRecoveryDialog();
      return;
    }

    if (!_formKey.currentState!.validate() || !_isFormValid) {
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
          message: 'No registered account found with email: $email.\nPlease verify your email address or contact school administration.',
        );
        return;
      }

      // Check if user has parent role
      if (user.role == UserRole.parent) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showParentRecoveryDialog();
        return;
      }

      // 2. Dispatch OTP via EmailService
      final otpResult = await AuthRepository.instance.sendForgotPasswordOtp(
        email: email,
        recipientName: user.fullName,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 3. Open shared PasswordOtpDialog modal
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PasswordOtpDialog(
          email: email,
          title: 'Verify Password Reset',
          subtitle: 'We sent a 6-digit verification code to:\n$email',
          submitButtonLabel: 'Verify & Reset Password',
          initialResendCooldown: (otpResult['resendAfter'] as num?)?.toInt() ?? 60,
          initialInputCountdown: (otpResult['expiresIn'] as num?)?.toInt() ?? 600,
          onVerify: (code) => AuthRepository.instance.verifyForgotPasswordOtp(code),
          onResend: () => AuthRepository.instance.sendForgotPasswordOtp(
            email: email,
            recipientName: user.fullName,
            isResend: true,
          ),
        ),
      );

      if (verified != true || !mounted) return;

      // 4. Update forgotten password through strict security gate
      setState(() => _isLoading = true);
      final updateError = await AuthRepository.instance.updateForgottenPassword(
        email: email,
        newPassword: _newPassController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (updateError != null) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Password Reset Failed',
          message: updateError,
        );
        return;
      }

      // 5. Success confirmation
      AppModals.showSuccessDialog(
        context: context,
        title: 'Password Reset Successful',
        message: 'Your account password has been updated securely. You can now sign in using your new password.',
        confirmLabel: 'Proceed to Sign In',
        onConfirm: () {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppModals.showErrorDialog(
        context: context,
        title: 'Reset Request Failed',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // --- REUSABLE CARD MATCHING LOGIN SCREEN ---
  Widget _buildFormCard(ThemeData theme, bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 24 : 36),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Eduardo Barretto Senior Integrated School',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email input
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_newPassFocusNode);
                    },
                    validator: AppValidators.validateEmail,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: Icon(
                        LucideIcons.mail,
                        color: theme.colorScheme.primary,
                      ),
                      hintText: 'Email address',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDC2626)),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Password input
                  TextFormField(
                    controller: _newPassController,
                    focusNode: _newPassFocusNode,
                    obscureText: _obscureNew,
                    maxLength: 30,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_confirmPassFocusNode);
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
                      FilteringTextInputFormatter.deny(RegExp(r'(.)\1{3,}')),
                    ],
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: Icon(
                        LucideIcons.lock,
                        color: theme.colorScheme.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? LucideIcons.eye : LucideIcons.eyeOff,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      hintText: 'New password',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Shared Password Requirements Checklist
                  PasswordRequirementsChecklist(
                    hasMinLength: _hasMinLength,
                    hasUpper: _hasUpper,
                    hasLower: _hasLower,
                    hasNumber: _hasNumber,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password input
                  TextFormField(
                    controller: _confirmPassController,
                    focusNode: _confirmPassFocusNode,
                    obscureText: _obscureConfirm,
                    maxLength: 30,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (_isFormValid && !_isLoading) {
                        _handleResetFlow();
                      }
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
                      FilteringTextInputFormatter.deny(RegExp(r'(.)\1{3,}')),
                    ],
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: Icon(
                        LucideIcons.lockKeyhole,
                        color: theme.colorScheme.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? LucideIcons.eye : LucideIcons.eyeOff,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      hintText: 'Confirm new password',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _confirmPassController.text.isEmpty
                              ? theme.colorScheme.primary
                              : (_passwordsMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _confirmPassController.text.isEmpty
                              ? const Color(0xFFCBD5E1)
                              : (_passwordsMatch ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                        ),
                      ),
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

                  // Reset Button — full width matching Login CTA
                  AppPrimaryButton(
                    onPressed: _isFormValid && !_isLoading ? _handleResetFlow : null,
                    isLoading: _isLoading,
                    label: _isLoading ? 'VERIFYING...' : 'RESET PASSWORD',
                    width: double.infinity,
                    height: 48,
                  ),

                  const SizedBox(height: 16),

                  // Back to Sign In Link
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      },
                      icon: Icon(
                        LucideIcons.arrowLeft,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(
                        'Back to Sign In',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
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
  }

  // --- DESKTOP SPLIT LAYOUT MATCHING LOGIN SCREEN ---
  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      children: [
        // Left Branding Column
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/branding/school_logo.png',
                      width: 64,
                      height: 64,
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLASSREALM',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'CALAMBA CITY, LAGUNA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  'One Realm for Every Learning Journey.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Integrated Senior High School Attendance, Activity and Requirement Tracking, Teacher Lesson Planning, and Learning Materials Management System.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Form Card Column
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildFormCard(theme, false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- MOBILE LAYOUT MATCHING LOGIN SCREEN ---
  Widget _buildMobileLayout(ThemeData theme) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/branding/school_logo.png',
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'CLASSREALM',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'One Realm for Every Learning Journey.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildFormCard(theme, true),
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
          final isDesktop = MediaQuery.of(context).size.width >= 900;
          final theme = Theme.of(context);

          return Scaffold(
            body: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/auth/school.jpg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black45,
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: isDesktop
                      ? _buildDesktopLayout(theme)
                      : _buildMobileLayout(theme),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
