import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/services/email_verification_service.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Split Name Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Email & Identity Controllers
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();

  // Selectable States
  String? _selectedGender;
  DateTime? _selectedBirthday;
  bool _isLoading = false;

  final EmailVerificationService _emailService = EmailVerificationService.instance;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your birthdate.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Verify Email via Service (Pre-configured for future API integration)
    final emailResult = await _emailService.verifyEmail(_emailController.text.trim());
    if (!emailResult.isValid) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppModals.showErrorDialog(
        context: context,
        title: 'Invalid Email Address',
        message: emailResult.reason ?? 'Please provide a valid, deliverable email address.',
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = middleName.isNotEmpty ? '$firstName $middleName $lastName' : '$firstName $lastName';
    final formattedBday = _selectedBirthday!.year.toString() +
        _selectedBirthday!.month.toString().padLeft(2, '0') +
        _selectedBirthday!.day.toString().padLeft(2, '0');
    final tempPassword = '${lastName.toLowerCase()}$formattedBday';

    final newTeacher = UserModel(
      id: 'usr_teacher_${DateTime.now().millisecondsSinceEpoch}',
      username: _usernameController.text.trim(),
      fullName: fullName,
      firstName: firstName,
      middleName: middleName.isNotEmpty ? middleName : null,
      lastName: lastName,
      gender: _selectedGender,
      birthday: _selectedBirthday,
      email: _emailController.text.trim(),
      role: UserRole.teacher,
      status: AccountStatus.pending,
    );

    // Save user to database
    MockDatabase.instance.users.add(newTeacher);

    AppModals.showSuccessDialog(
      context: context,
      title: 'Registration Request Submitted',
      message:
          'Welcome, Teacher $lastName! Your account registration has been submitted and is now pending review by the School Administrator.\n\nOnce approved, your initial temporary password will follow the DepEd standard format:\n[lastname_lower]$formattedBday (e.g., "$tempPassword").',
      onConfirm: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 850;

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

          // Scrollable Registration Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                padding: EdgeInsets.all(isDesktop ? 36 : 24),
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
                    children: [
                      // Header with School Crest Logo
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
                                height: 72,
                                width: 72,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Eduardo Barretto Sr. Integrated School',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Teacher Account Registration',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Complete your faculty profile to access the Strengthened SHS Grading Engine.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Information Notice about Auto-Generated Temp Password
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
                            const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Security Notice: Teachers do not create passwords during sign up. Upon Admin approval, your temporary password is automatically formatted as [lastname_lower][YYYYMMDD] from your birthdate.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section Title: Personal Information
                      Text(
                        'PERSONAL INFORMATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Split Names: First Name & Middle Name
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: AppTextField(
                                label: 'First Name',
                                hint: 'e.g. Karen',
                                controller: _firstNameController,
                                prefixIcon: Icons.person_outline,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]")),
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'First name is required (letters only).';
                                  }
                                  if (v.trim().length < 2) {
                                    return 'Must be at least 2 characters.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: AppTextField(
                                label: 'Middle Name (Optional)',
                                hint: 'e.g. P.',
                                controller: _middleNameController,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]")),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        AppTextField(
                          label: 'First Name',
                          hint: 'e.g. Karen',
                          controller: _firstNameController,
                          prefixIcon: Icons.person_outline,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]")),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'First name is required (letters only).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Middle Name (Optional)',
                          hint: 'e.g. P.',
                          controller: _middleNameController,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]")),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Last Name
                      AppTextField(
                        label: 'Last Name',
                        hint: 'e.g. Gonzaga',
                        controller: _lastNameController,
                        prefixIcon: Icons.badge_outlined,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\.]")),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Last name is required.';
                          }
                          if (v.trim().length < 2) {
                            return 'Must be at least 2 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Gender and Birthdate Row
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gender Selection
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gender',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedGender,
                                        isExpanded: true,
                                        hint: Text(
                                          'Select Gender',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'Male',
                                            child: Row(
                                              children: [
                                                Icon(Icons.male, size: 20, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Male'),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Female',
                                            child: Row(
                                              children: [
                                                Icon(Icons.female, size: 20, color: Colors.pink),
                                                SizedBox(width: 8),
                                                Text('Female'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) => setState(() => _selectedGender = v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Modern Date Picker
                            Expanded(
                              flex: 6,
                              child: AppDatePickerField(
                                label: 'Birthdate (YYYY-MM-DD)',
                                initialDate: _selectedBirthday,
                                onDateSelected: (d) => setState(() => _selectedBirthday = d),
                                validator: (d) {
                                  if (d == null) return 'Birthdate is required.';
                                  final now = DateTime.now();
                                  int age = now.year - d.year;
                                  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
                                  if (age < 18) return 'Teacher must be at least 18 years old.';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gender',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGender,
                                  isExpanded: true,
                                  hint: Text(
                                    'Select Gender',
                                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                                  ],
                                  onChanged: (v) => setState(() => _selectedGender = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppDatePickerField(
                          label: 'Birthdate (YYYY-MM-DD)',
                          initialDate: _selectedBirthday,
                          onDateSelected: (d) => setState(() => _selectedBirthday = d),
                          validator: (d) {
                            if (d == null) return 'Birthdate is required.';
                            final now = DateTime.now();
                            int age = now.year - d.year;
                            if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
                            if (age < 18) return 'Teacher must be at least 18 years old.';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Section Title: Account Details
                      Text(
                        'ACCOUNT DETAILS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Email Address (Clean label, ready for API checker)
                      AppTextField(
                        label: 'Email Address',
                        hint: 'e.g. karen.gonzaga@deped.gov.ph',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email address is required.';
                          }
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Please enter a valid email address (e.g. name@school.edu.ph).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Desired Username
                      AppTextField(
                        label: 'Preferred Username',
                        hint: 'e.g. kgonzaga',
                        controller: _usernameController,
                        prefixIcon: Icons.alternate_email,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9_\.]")),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Username is required.';
                          }
                          if (v.trim().length < 4) {
                            return 'Username must be at least 4 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      AppPrimaryButton(
                        label: 'Submit Teacher Registration',
                        isLoading: _isLoading,
                        onPressed: _handleRegister,
                      ),
                      const SizedBox(height: 16),

                      // Already have an account link
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Already have an account? Sign In'),
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
