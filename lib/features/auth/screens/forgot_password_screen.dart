import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';
import '../../../widgets/common/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1: Enter Email, 2: Enter OTP, 3: New Password
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _handleSendOtp() {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      AppModals.showErrorDialog(context: context, title: 'Invalid Email', message: 'Please enter a valid registered email address.');
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 2;
      });
      AppModals.showSuccessDialog(
        context: context,
        title: 'OTP Sent Successfully',
        message: 'A 6-digit verification code has been sent to ${_emailController.text.trim()}. (Simulated code: 123456)',
      );
    });
  }

  void _handleVerifyOtp() {
    if (_otpController.text.trim() != '123456' && _otpController.text.trim().length != 6) {
      AppModals.showErrorDialog(context: context, title: 'Invalid Verification Code', message: 'Please enter the correct 6-digit OTP code (Demo code: 123456).');
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 3;
      });
    });
  }

  void _handleResetPassword() {
    if (_newPassController.text.length < 6) {
      AppModals.showErrorDialog(context: context, title: 'Password Too Short', message: 'New password must be at least 6 characters long.');
      return;
    }
    if (_newPassController.text != _confirmPassController.text) {
      AppModals.showErrorDialog(context: context, title: 'Passwords Do Not Match', message: 'Please ensure both password fields match.');
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppModals.showSuccessDialog(
        context: context,
        title: 'Password Reset Successful',
        message: 'Your account password has been updated securely. You can now log in with your new password.',
        onConfirm: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Recovery & Password Reset'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  _step == 1
                      ? 'Forgot Your Password?'
                      : _step == 2
                          ? 'Enter Verification Code'
                          : 'Set New Password',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 1
                      ? 'Enter your registered school email address to receive a secure OTP verification code.'
                      : _step == 2
                          ? 'We have sent a 6-digit confirmation code to ${_emailController.text}.'
                          : 'Create a secure new password for your Eduardo Barretto SHS account.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // Step 1: Email Input
                if (_step == 1) ...[
                  AppTextField(
                    label: 'Registered Email Address',
                    hint: 'user@barretto-shs.edu.ph',
                    controller: _emailController,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    label: 'Send Verification OTP',
                    isLoading: _isLoading,
                    onPressed: _handleSendOtp,
                  ),
                ],

                // Step 2: OTP Input
                if (_step == 2) ...[
                  AppTextField(
                    label: '6-Digit OTP Code',
                    hint: '123456',
                    controller: _otpController,
                    prefixIcon: Icons.security,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    label: 'Verify Code',
                    isLoading: _isLoading,
                    onPressed: _handleVerifyOtp,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _step = 1),
                      child: const Text('Resend OTP or Change Email', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                  ),
                ],

                // Step 3: New Password Input
                if (_step == 3) ...[
                  AppTextField(
                    label: 'New Password',
                    hint: '••••••••',
                    controller: _newPassController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Confirm New Password',
                    hint: '••••••••',
                    controller: _confirmPassController,
                    obscureText: true,
                    prefixIcon: Icons.lock_reset,
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    label: 'Update Password & Login',
                    isLoading: _isLoading,
                    onPressed: _handleResetPassword,
                  ),
                ],

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Sign In', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
