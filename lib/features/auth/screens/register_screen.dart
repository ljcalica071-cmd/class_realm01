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
  UserRole _selectedRole = UserRole.student; // Default is Student as requested
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deptOrSectionController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _deptOrSectionController.dispose();
    _studentIdController.dispose();
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
        id: 'usr_${_selectedRole.name}_${DateTime.now().millisecondsSinceEpoch}',
        username: _usernameController.text.trim(),
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
        status: _selectedRole == UserRole.teacher ? AccountStatus.pending : AccountStatus.active,
        departmentOrSection: _deptOrSectionController.text.trim().isEmpty ? 'Section A' : _deptOrSectionController.text.trim(),
        studentId: _selectedRole == UserRole.student ? (_studentIdController.text.trim().isEmpty ? '2024-SHS-0999' : _studentIdController.text.trim()) : null,
        contactNumber: _contactController.text.trim(),
      );

      MockDatabase.instance.users.add(newUser);

      AppModals.showSuccessDialog(
        context: context,
        title: _selectedRole == UserRole.teacher ? 'Registration Pending Approval' : 'Account Created Successfully',
        message: _selectedRole == UserRole.teacher
            ? 'Your teacher account has been submitted and is pending admin approval.'
            : 'Your account has been successfully created. You can now log in with your credentials.',
        onConfirm: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eduardo Barretto SHS - Registration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
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
                    'Create Account in ClassRealm',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select your role below and fill out your details to register in the portal.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Role Selection Segment
                  const Text('Select Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRoleTab(UserRole.student, 'Student (Default)', Icons.school),
                        const SizedBox(width: 8),
                        _buildRoleTab(UserRole.teacher, 'Teacher', Icons.person_pin),
                        const SizedBox(width: 8),
                        _buildRoleTab(UserRole.parent, 'Parent', Icons.family_restroom),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  AppTextField(
                    label: 'Full Name',
                    hint: _selectedRole == UserRole.teacher ? 'Prof. Juan Santos' : 'Juan Dela Cruz',
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

                  if (_selectedRole == UserRole.student) ...[
                    AppTextField(
                      label: 'Student ID Number',
                      hint: '2024-SHS-0150',
                      controller: _studentIdController,
                      prefixIcon: Icons.confirmation_number_outlined,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Grade & Section',
                      hint: 'Section A',
                      controller: _deptOrSectionController,
                      prefixIcon: Icons.class_outlined,
                    ),
                  ] else if (_selectedRole == UserRole.teacher) ...[
                    AppTextField(
                      label: 'Department / Specialization',
                      hint: 'STEM Mathematics Department',
                      controller: _deptOrSectionController,
                      prefixIcon: Icons.science_outlined,
                    ),
                  ] else ...[
                    AppTextField(
                      label: 'Linked Student Name / ID',
                      hint: 'Juan Dela Cruz (2024-SHS-0101)',
                      controller: _deptOrSectionController,
                      prefixIcon: Icons.family_restroom,
                    ),
                  ],

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
                    label: _selectedRole == UserRole.teacher ? 'Submit Teacher Registration Request' : 'Complete Account Registration',
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

  Widget _buildRoleTab(UserRole role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textPrimary)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      onSelected: (_) => setState(() => _selectedRole = role),
    );
  }
}
