import 'package:flutter/material.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _tempPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureTemp = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _tempPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _showCelebratorySuccessDialog(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final isTeacher = user.role == UserRole.teacher;
    final displayName = user.lastName != null ? 'Teacher ${user.lastName}' : (user.firstName ?? user.fullName);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SuccessDialog',
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (ctx, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curveValue = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: curveValue,
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 16,
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
                    // Celebratory Animated Icon Badge
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'Password Setup Complete!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Informative Success Message
                    Text(
                      'Welcome to ClassRealm, $displayName! Your temporary password has been successfully replaced with your new secure credentials.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            isTeacher ? 'Account Status: Active Faculty' : 'Account Status: Active Learner',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Next Step Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: Text(
                          isTeacher ? 'Proceed to Academic Setup' : 'Enter Student Portal',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isTeacher) {
                            Navigator.pushReplacementNamed(context, AppRoutes.academicSetup);
                          } else {
                            Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
                          }
                        },
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

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final user = MockDatabase.instance.currentUser;
    if (user == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Session Expired',
        message: 'No active session found. Please log in again.',
        onConfirm: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      );
      return;
    }

    final error = MockDatabase.instance.completeFirstLogin(
      user.id,
      _tempPassCtrl.text.trim(),
      _newPassCtrl.text.trim(),
    );

    if (error != null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Password Setup Failed',
        message: error,
      );
      return;
    }

    // Show Celebratory Animated Modal
    _showCelebratorySuccessDialog(context, user);
  }

  @override
  Widget build(BuildContext context) {
    final user = MockDatabase.instance.currentUser;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final theme = Theme.of(context);

    final displayName = user != null
        ? (user.lastName != null ? 'Teacher ${user.lastName}' : (user.firstName ?? user.fullName))
        : 'Faculty';

    return Scaffold(
      body: Stack(
        children: [
          // Background Campus Photo with Depth Overlay
          Positioned.fill(
            child: Image.asset(
              AssetPaths.landingBackground,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
            ),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with School Crest Logo & Icon
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                AssetPaths.schoolLogo,
                                height: 64,
                                width: 64,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Set Permanent Password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Welcome, $displayName! For security compliance, you must change your temporary password to activate your account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Informational Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Password Requirement: Must be at least 8 characters long and contain both letters and numbers.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Temporary Password
                      TextFormField(
                        controller: _tempPassCtrl,
                        obscureText: _obscureTemp,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Temporary password is required.';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Current Temporary Password',
                          hintText: 'e.g. gonzaga19951024',
                          prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureTemp ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureTemp = !_obscureTemp),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Password
                      TextFormField(
                        controller: _newPassCtrl,
                        obscureText: _obscureNew,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'New password is required.';
                          }
                          if (v.trim().length < 8) {
                            return 'Password must be at least 8 characters.';
                          }
                          final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(v);
                          final hasNumber = RegExp(r'[0-9]').hasMatch(v);
                          if (!hasLetter || !hasNumber) {
                            return 'Must contain both letters and numbers.';
                          }
                          if (v.trim() == _tempPassCtrl.text.trim()) {
                            return 'New password must be different from temporary password.';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: _obscureConfirm,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please confirm your new password.';
                          }
                          if (v.trim() != _newPassCtrl.text.trim()) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_reset_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      AppPrimaryButton(
                        label: 'Activate Account & Set Password',
                        icon: Icons.check_circle_outline,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 14),

                      // Back to Login Link
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            MockDatabase.instance.logout();
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
          ),
        ],
      ),
    );
  }
}
