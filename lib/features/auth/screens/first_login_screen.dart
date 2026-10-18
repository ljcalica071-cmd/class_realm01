import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';

class FirstLoginScreen extends StatefulWidget {
  const FirstLoginScreen({super.key});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> with SingleTickerProviderStateMixin {
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _childLrnLast4Ctrl = TextEditingController();
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
    final confirm = _confirmPassCtrl.text;
    final result = AppValidators.validatePasswordComplexity(
      password: v,
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

  void _validateMatch() {
    setState(() {
      _passwordsMatch = AppValidators.passwordsMatch(_newPassCtrl.text, _confirmPassCtrl.text);
    });
  }

  bool get _isValid => _hasMinLength && _hasUpper && _hasLower && _hasNumber && _passwordsMatch;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _childLrnLast4Ctrl.dispose();
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

    if (user.role == UserRole.parent) {
      final phone = _parentPhoneCtrl.text.trim();
      final lrn4 = _childLrnLast4Ctrl.text.trim();

      if (phone.length != 11 || !phone.startsWith('09')) {
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Phone Number Required',
          message: 'Please enter your registered 11-digit mobile phone number starting with 09.',
        );
        return;
      }

      if (lrn4.length != 4) {
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'LRN Required',
          message: 'Please enter the last 4 digits of your linked child\'s 12-digit LRN.',
        );
        return;
      }

      final lastName = user.lastName ??
          (user.fullName.contains(' ')
              ? user.fullName.split(' ').last
              : user.fullName);
      final tempPassword = ParentCredentialHelper.generateTempPassword(
        lastName,
        user.birthday ?? DateTime.now(),
      );

      if (_newPassCtrl.text.trim().toLowerCase() == tempPassword.toLowerCase()) {
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Password Rule Violation',
          message:
              'Your new password cannot be the same as your temporary password. Please choose a different, secure password.',
        );
        return;
      }

      final verified = await SupabaseParentRepository()
          .verifyParentIdentityForFirstLogin(
        parentId: user.id,
        contactNumber: phone,
        childLrnLast4: lrn4,
      );

      if (!verified) {
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Identity Verification Failed',
          message:
              'Identity verification failed. Please enter the exact 11-digit phone number and the last 4 digits of your child\'s LRN registered with the teacher.',
        );
        return;
      }
    } else {
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
          child: PasswordOtpDialog(
            email: user.email,
            initialResendCooldown: (otpResponse['resendAfter'] as num?)?.toInt() ?? 60,
            initialInputCountdown: (otpResponse['expiresIn'] as num?)?.toInt() ?? 600,
            initialResendCount: (otpResponse['resendCount'] as num?)?.toInt() ?? 0,
            onResend: () => AuthRepository.instance.sendFirstLoginOtp(isResend: true),
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

  Widget _buildParentIdentityVerificationSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parent Identity Verification',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Confirm your registered details to verify and activate your account.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _parentPhoneCtrl,
            keyboardType: TextInputType.number,
            maxLength: 11,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(
              labelText: 'Registered 11-Digit Phone Number *',
              hintText: '09XXXXXXXXX',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.phone_android_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _childLrnLast4Ctrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(
              labelText: 'Last 4 Digits of Child\'s LRN *',
              hintText: 'e.g. 1234',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.badge_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
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

          return PopScope(
            canPop: !_isLoading,
            child: Scaffold(
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

                          if (user?.role == UserRole.parent) ...[
                            _buildParentIdentityVerificationSection(theme),
                            const SizedBox(height: 20),
                          ],

                          // New Password
                          TextField(
                            controller: _newPassCtrl,
                            enabled: !_isLoading,
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
                          PasswordRequirementsChecklist(
                            hasMinLength: _hasMinLength,
                            hasUpper: _hasUpper,
                            hasLower: _hasLower,
                            hasNumber: _hasNumber,
                          ),

                          const SizedBox(height: 24),

                          // Confirm Password
                          TextField(
                            controller: _confirmPassCtrl,
                            enabled: !_isLoading,
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
                            label: 'Set New Password',
                            isLoading: _isLoading,
                            onPressed: _isValid ? _submit : null,
                          ),
                          const SizedBox(height: 14),

                          // Back to Login Link
                          Center(
                            child: TextButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      AuthRepository.instance.logout();
                                      AppTheme.themeModeNotifier.value = ThemeMode.light;
                                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                disabledForegroundColor: const Color(0xFF94A3B8),
                              ),
                              icon: Icon(
                                Icons.arrow_back,
                                size: 16,
                                color: _isLoading ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                              ),
                              label: Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: _isLoading ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}
