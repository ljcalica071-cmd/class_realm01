import 'package:flutter/material.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/core/utils/validators.dart';

class AdminAddTeacherScreen extends StatefulWidget {
  const AdminAddTeacherScreen({super.key});

  @override
  State<AdminAddTeacherScreen> createState() => _AdminAddTeacherScreenState();
}

class _AdminAddTeacherScreenState extends State<AdminAddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();

  // Split Name Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Email Controller
  final _emailController = TextEditingController();

  // Selectable States
  String? _selectedGender;
  DateTime? _selectedBirthday;
  bool _isLoading = false;
  bool _autoValidate = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    setState(() => _autoValidate = true);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGender == null || _selectedBirthday == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Missing Information',
        message: 'Please select your Gender and Birthday.',
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final email = _emailController.text.trim();
      final firstName = _firstNameController.text.trim();
      final middleName = _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      await AuthRepository.instance.createTeacherDirectlyByAdmin(
        email: email,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        gender: _selectedGender!,
        birthday: _selectedBirthday!,
      );

      if (!mounted) return;

      AppModals.showSuccessDialog(
        context: context,
        title: 'Teacher Account Created',
        message: "The teacher account has been successfully created. The temporary login credentials have been sent to their registered email address.",
        confirmLabel: 'Back to Directory',
        onConfirm: () => Navigator.pop(context, true),
      );
    } catch (e) {
      if (!mounted) return;
      AppModals.showErrorDialog(
        context: context,
        title: 'Creation Failed',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 850;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with School Crest Logo
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Image.asset(
                              AssetPaths.schoolLogo,
                              height: 48,
                              width: 48,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Eduardo Barretto Sr. Integrated School',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create Teacher Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
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
                        fontSize: 10,
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
                              inputFormatters: AppValidators.nameFormatters,
                              validator: (v) =>
                                  AppValidators.validateName(v, 'First name'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: AppTextField(
                              label: 'Middle Name (Optional)',
                              hint: 'e.g. P.',
                              controller: _middleNameController,
                              inputFormatters: AppValidators.nameFormatters,
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
                        inputFormatters: AppValidators.nameFormatters,
                        validator: (v) =>
                            AppValidators.validateName(v, 'First name'),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Middle Name (Optional)',
                        hint: 'e.g. P.',
                        controller: _middleNameController,
                        inputFormatters: AppValidators.nameFormatters,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Last Name
                    AppTextField(
                      label: 'Last Name',
                      hint: 'e.g. Gonzaga',
                      controller: _lastNameController,
                      prefixIcon: Icons.badge_outlined,
                      inputFormatters: AppValidators.nameFormatters,
                      validator: (v) =>
                          AppValidators.validateName(v, 'Last name'),
                    ),
                    const SizedBox(height: 12),

                    // Gender and Birthdate Row
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _buildGenderField(theme)),
                          const SizedBox(width: 12),
                          Expanded(flex: 6, child: _buildBirthdayField()),
                        ],
                      )
                    else ...[
                      _buildGenderField(theme),
                      const SizedBox(height: 12),
                      _buildBirthdayField(),
                    ],
                    const SizedBox(height: 20),

                    // Section Title: Account Details
                    Text(
                      'ACCOUNT DETAILS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email Address
                    AppTextField(
                      label: 'Email Address',
                      hint: 'e.g. karen.gonzaga@gmail.com',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                      validator: AppValidators.validateEmail,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    AppPrimaryButton(
                      label: 'Create Teacher Account',
                      isLoading: _isLoading,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 8),

                    // Cancel Button
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 14),
                        label: const Text(
                          'Cancel & Return to Directory',
                          style: TextStyle(fontSize: 13),
                        ),
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

  Widget _buildGenderField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
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
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
            ),
            errorStyle: TextStyle(fontSize: 12, color: theme.colorScheme.error),
          ),
          hint: Text(
            'Select Gender',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Gender is required.' : null,
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
          ],
          onChanged: (val) {
            setState(() => _selectedGender = val);
          },
        ),
      ],
    );
  }

  Widget _buildBirthdayField() {
    return AppDatePickerField(
      label: 'Birthdate *',
      initialDate: _selectedBirthday,
      firstDate: BirthdayValidator.getMinDate(),
      lastDate: BirthdayValidator.getMaxDate('teacher'),
      onDateSelected: (date) {
        setState(() => _selectedBirthday = date);
      },
      validator: (v) => BirthdayValidator.validateBirthday(v, 'teacher'),
    );
  }
}

