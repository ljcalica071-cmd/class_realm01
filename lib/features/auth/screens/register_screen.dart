import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final newUser = UserModel(
        id: 'usr_teacher_${DateTime.now().millisecondsSinceEpoch}',
        username: _usernameController.text.trim(),
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: UserRole.teacher,
        status: AccountStatus.pending,
        contactNumber: _contactController.text.trim(),
      );

      MockDatabase.instance.users.add(newUser);

      AppModals.showSuccessDialog(
        context: context,
        title: 'Registration Pending Approval',
        message: 'Your teacher account has been submitted and is pending admin approval.',
        onConfirm: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eduardo Barretto SHS - Registration'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/auth/school.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDark ? Colors.black87 : Colors.black54,
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Account in ClassRealm',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Teacher registration is available for the web portal only. Student and parent accounts are created by the teacher.',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 20),

                    AppTextField(
                      label: 'Full Name',
                      hint: 'Karen P. Gonzaga',
                      controller: _nameController,
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) => v == null || v.isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Institutional / Personal Email',
                      hint: 'user@barretto-shs.edu.ph',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@') ? 'Valid email is required' : null,
                    ),
                    const SizedBox(height: 16),

                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Contact Number',
                      hint: '+63 917 123 4567',
                      controller: _contactController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Username',
                      hint: 'Choose a username',
                      controller: _usernameController,
                      prefixIcon: Icons.person_outline,
                      validator: (v) => v == null || v.isEmpty ? 'Username is required' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Password',
                      hint: '••••••••',
                      controller: _passwordController,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline,
                      validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 24),
                    AppPrimaryButton(
                      label: 'Submit Teacher Registration Request',
                      isLoading: _isLoading,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Already have an account? Sign In', style: TextStyle(color: theme.colorScheme.primary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
