import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';
import '../../../widgets/common/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deptController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final newTeacher = UserModel(
        id: 'usr_t_${DateTime.now().millisecondsSinceEpoch}',
        username: _usernameController.text.trim(),
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: UserRole.teacher,
        status: AccountStatus.pending,
        departmentOrSection: _deptController.text.trim().isEmpty ? 'Senior High Department' : _deptController.text.trim(),
      );

      MockDatabase.instance.users.add(newTeacher);

      AppModals.showSuccessDialog(
        context: context,
        title: 'Registration Submitted',
        message: 'Your teacher account has been created and is currently pending Admin approval. You may log in once approved.',
        onConfirm: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Account Registration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Join ClassRealm as Educator',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fill in your details to request access. An administrator must approve your account before setup.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: 'Full Name with Title',
                    hint: 'e.g. Prof. Juan Santos',
                    controller: _nameController,
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) => v == null || v.isEmpty ? 'Full name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Institutional Email',
                    hint: 'jsantos@classrealm.edu',
                    controller: _emailController,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email is required' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Department / Specialization',
                    hint: 'e.g. STEM Mathematics',
                    controller: _deptController,
                    prefixIcon: Icons.science_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Preferred Username',
                    hint: 'jsantos',
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
                    label: 'Submit Registration Request',
                    isLoading: _isLoading,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Already have an account? Sign In', style: TextStyle(color: AppColors.primary)),
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
}
