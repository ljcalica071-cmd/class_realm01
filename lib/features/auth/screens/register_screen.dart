import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/services/email_service.dart';
import 'package:class_realm/core/services/email_verification_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  // Email Controller
  final _emailController = TextEditingController();

  // Selectable States
  String? _selectedGender;
  DateTime? _selectedBirthday;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  bool _autoValidate = true;

  // Anti-spam state
  static DateTime? _lastOtpSentTime;
  static String? _lastSentEmail;
  static String? _lastSentOtp;

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

    if (!_agreedToTerms) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    // 1. Verify email format and physical existence via API
    final verificationService = ApiEmailVerificationService();
    EmailVerificationResult emailResult;
    try {
      emailResult = await verificationService.verifyEmail(email);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted && e.toString().contains('SYSTEM_ERROR')) {
        AppModals.showErrorDialog(
          context: context,
          title: 'System Error',
          message: 'There is something wrong with the system right now, and we cannot create a new account at this moment. Please try again later.',
        );
      }
      return;
    }

    if (!emailResult.isValid) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Invalid Email',
          message:
              emailResult.reason ??
              'Please enter a valid and active email address.',
        );
      }
      return;
    }

    // 2. Proceed with OTP Verification
    final firstName = _firstNameController.text.trim();

    // Anti-spam check
    final now = DateTime.now();
    bool useExistingOtp = false;
    String currentOtp = '';

    if (_lastSentEmail == email &&
        _lastOtpSentTime != null &&
        _lastSentOtp != null) {
      final diff = now.difference(_lastOtpSentTime!).inSeconds;
      if (diff < 90) {
        // 90 seconds cooldown
        useExistingOtp = true;
        currentOtp = _lastSentOtp!;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Re-opened verification using previously sent code.'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    if (!useExistingOtp) {
      final random = Random();
      currentOtp = (100000 + random.nextInt(900000)).toString();

      final emailSent = await EmailService.instance.sendRegistrationOtpEmail(
        recipientEmail: email,
        recipientName: firstName,
        otpCode: currentOtp,
      );

      if (!emailSent) {
        setState(() => _isLoading = false);
        if (mounted) {
          AppModals.showErrorDialog(
            context: context,
            title: 'System Error',
            message: 'Failed to send verification email. Please check your connection and try again.',
          );
        }
        return;
      }

      _lastOtpSentTime = now;
      _lastSentEmail = email;
      _lastSentOtp = currentOtp;
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    // Calculate remaining timers if using existing OTP
    int initialResend = 90;
    int initialInput = 60;
    if (useExistingOtp && _lastOtpSentTime != null) {
      final passed = DateTime.now().difference(_lastOtpSentTime!).inSeconds;
      initialResend = (90 - passed).clamp(0, 90);
      initialInput = (60 - passed).clamp(0, 60);
    }

    // Show OTP Dialog
    final bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OtpVerificationDialog(
        email: email,
        name: firstName,
        initialOtp: currentOtp,
        initialResendCooldown: initialResend,
        initialInputCountdown: initialInput,
      ),
    );

    if (verified != true) return;

    // 3. Register user in Database
    setState(() => _isLoading = true);

    try {
      final middleName = _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final formattedBday =
          _selectedBirthday!.year.toString() +
          _selectedBirthday!.month.toString().padLeft(2, '0') +
          _selectedBirthday!.day.toString().padLeft(2, '0');
      final tempPassword = '${lastName.toLowerCase()}$formattedBday';

      final newTeacher = await AuthRepository.instance.registerTeacher(
        email: email,
        password: tempPassword,
        firstName: firstName,
        lastName: lastName,
        middleName: middleName.isNotEmpty ? middleName : null,
        gender: _selectedGender,
        birthday: _selectedBirthday,
      );

      if (!mounted) return;

      if (newTeacher == null) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Registration Failed',
          message: 'Unable to complete registration. Please check your credentials and try again.',
        );
        return;
      }

      AppModals.showSuccessDialog(
        context: context,
        title: 'Registration Successful',
        message: "Your registration has been submitted successfully. Please wait for the administrator's approval. Once approved, your login credentials will be sent to your registered email address.",
        confirmLabel: 'Continue to Sign In',
        onConfirm: () =>
            Navigator.pushReplacementNamed(context, AppRoutes.login),
      );
    } catch (e) {
      if (!mounted) return;
      String rawMessage = e.toString();
      String title = 'Registration Failed';
      String message = rawMessage.replaceFirst('Exception: ', '');

      if (rawMessage.contains('REG_PENDING')) {
        title = 'Application Pending';
        message = 'Your account registration is currently being processed and is waiting for the administrator\'s approval. Please check your email later for updates.';
      } else if (rawMessage.contains('REG_APPROVED')) {
        title = 'Account Approved';
        message = 'Your account has already been approved. Please check your email for the login credentials.';
      } else if (rawMessage.contains('REG_ACTIVE')) {
        title = 'Account Active';
        message = 'This email is already registered and active. Please proceed to login.';
      }

      AppModals.showErrorDialog(
        context: context,
        title: title,
        message: message,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            child: Image.asset(AssetPaths.landingBackground, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),

          // Scrollable Registration Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 35,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 36 : 24),
                    child: Form(
                      key: _formKey,
                  autovalidateMode: _autoValidate
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

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
                      const SizedBox(height: 16),

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
                        hint: 'e.g. karen.gonzaga@gmail.com',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: AppValidators.validateEmail,
                      ),
                      const SizedBox(height: 28),

                      // Consent documents stay in separate, scrollable dialogs.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreedToTerms,
                            onChanged: (value) {
                              setState(() => _agreedToTerms = value ?? false);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'I have read and agree to the ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _showTermsDialog,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Terms and Conditions'),
                                  ),
                                  Text(
                                    ' and the ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _showPrivacyDialog,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Privacy Policy'),
                                  ),
                                  Text(
                                    ', and that I am an authorized personnel.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Submit Button
                      AppPrimaryButton(
                        label: 'Submit Teacher Registration',
                        isLoading: _isLoading,
                        onPressed: _agreedToTerms ? _handleRegister : null,
                      ),
                      const SizedBox(height: 16),

                      // Already have an account link
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Already have an account? Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
}

  Future<void> _showTermsDialog() {
    return _showConsentDocumentDialog(
      title: 'Terms and Conditions',
      content: [
        _buildSubSection(
          '1. Acceptance of Terms',
          'By accessing or using ClassRealm, an Integrated Senior High School Academic Management System for Eduardo Barretto Senior Integrated School, you agree to be bound by these terms. If you do not agree, please do not use the system.',
        ),
        _buildSubSection(
          '2. User Responsibilities',
          '• Teachers: Responsible for accurate input of grades, assessments, and securing their authentication credentials.\n'
          '• Students: Must maintain academic integrity, provide accurate personal details, and ensure their RFID tags are only used by them.\n'
          '• Parents: Granted access strictly for monitoring their child\'s academic progress and attendance.',
        ),
        _buildSubSection(
          '3. Acceptable Use',
          'The system is provided solely for educational and administrative purposes. Users must interact with the platform securely and respect the privacy of other users.',
        ),
        _buildSubSection(
          '4. Prohibited Conduct & Anti-Cheating',
          'ClassRealm actively monitors "suspicious session events" (e.g., leaving the active quiz tab) during assessments. Any form of cheating, sharing of credentials, or bypassing monitoring mechanisms is strictly prohibited and will be logged for disciplinary review.',
        ),
        _buildSubSection(
          '5. Limitation of Liability',
          'The developers and the school are not liable for any temporary service interruptions or data loss caused by unauthorized user actions or hardware failures.',
        ),
      ],
    );
  }

  Future<void> _showPrivacyDialog() {
    return _showConsentDocumentDialog(
      title: 'Privacy Policy',
      subtitle: 'RA 10173 - Data Privacy Act',
      content: [
        const Text(
          'We protect your personal information in compliance with the Philippine Data Privacy Act of 2012 (RA 10173).',
          style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildSubSection(
          '1. Information We Collect',
          '• Personal Information: Names, Student IDs (LRN), Emails, Contact Numbers, Birthdays, and Gender.\n'
          '• Academic Data: Submissions, quiz/exam scores, calculated grades, and attendance records.\n'
          '• Biometric & Hardware Data: RFID logs via ESP32 for offline attendance tracking.\n'
          '• Technical Data: Suspicious session events during assessments.',
        ),
        _buildSubSection(
          '2. How We Use the Information',
          'Collected data is used strictly for academic evaluation, generating student progress reports, tracking attendance, and ensuring academic integrity during examinations.',
        ),
        _buildSubSection(
          '3. Offline & Cloud Storage Syncing',
          'ClassRealm uses an offline-first architecture. Data is temporarily stored locally on your device when offline, and automatically synced to our secure cloud databases once an internet connection is established.',
        ),
        _buildSubSection(
          '4. Third-Party Services',
          'We utilize secure, industry-standard third-party services including Firebase and Supabase for authentication and cloud database management. They comply with strict data security standards.',
        ),
        _buildSubSection(
          '5. Data Retention & User Rights',
          'Your data is retained only as long as necessary for educational records. Under RA 10173, you have the right to access, rectify, or object to the processing of your personal information by contacting the system administrator.',
        ),
      ],
    );
  }

  Future<void> _showConsentDocumentDialog({
    required String title,
    String? subtitle,
    required List<Widget> content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final dialogWidth = (MediaQuery.sizeOf(dialogContext).width - 80)
            .clamp(0.0, 520.0)
            .toDouble();
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildGenderField(ThemeData theme) {
    return Column(
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
        DropdownButtonFormField<String>(
          value: _selectedGender,
          autovalidateMode: _autoValidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
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
      ],
    );
  }

  Widget _buildBirthdayField() {
    return AppDatePickerField(
      label: 'Birthdate (YYYY-MM-DD)',
      initialDate: _selectedBirthday,
      autovalidateMode: _autoValidate
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime(
        DateTime.now().year - 18,
        DateTime.now().month,
        DateTime.now().day,
      ),
      onDateSelected: (d) => setState(() => _selectedBirthday = d),
      validator: (d) {
        if (d == null) return 'Birthdate is required.';
        final now = DateTime.now();
        int age = now.year - d.year;
        if (now.month < d.month || (now.month == d.month && now.day < d.day))
          age--;
        if (age < 18) return 'Teacher must be at least 18 years old.';
        return null;
      },
    );
  }
}

class _OtpVerificationDialog extends StatefulWidget {
  final String email;
  final String name;
  final String initialOtp;
  final int initialResendCooldown;
  final int initialInputCountdown;

  const _OtpVerificationDialog({
    required this.email,
    required this.name,
    required this.initialOtp,
    this.initialResendCooldown = 90,
    this.initialInputCountdown = 60,
  });

  @override
  State<_OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<_OtpVerificationDialog> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _hasError = false;
  late String _currentOtp;

  // 90 seconds before resend is allowed
  Timer? _resendTimer;
  int _resendCooldown = 90;
  int _resendAttempts = 0; // Maximum of 3 resends

  // 60 seconds visual timer
  Timer? _inputTimer;
  int _inputCountdown = 60;

  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.initialOtp;
    _resendCooldown = widget.initialResendCooldown;
    _inputCountdown = widget.initialInputCountdown;
    _startTimers(reset: false);
  }

  void _startTimers({bool reset = true}) {
    if (reset) {
      setState(() {
        _resendCooldown = 90;
        _inputCountdown = 60;
      });
    }

    _resendTimer?.cancel();
    _inputTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });

    _inputTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_inputCountdown > 0) {
        setState(() => _inputCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _showTopNotification(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: isError ? theme.colorScheme.error : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
                    color: isError ? theme.colorScheme.onError : theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isError ? theme.colorScheme.onError : theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> _handleResend() async {
    if (_resendAttempts >= 3) {
      _showTopNotification('Maximum resend attempts reached.', isError: true);
      return;
    }

    setState(() {
      _isResending = true;
      _hasError = false;
      _otpController.clear();
    });
    _formKey.currentState?.reset();

    final random = Random();
    _currentOtp = (100000 + random.nextInt(900000)).toString();

    final sent = await EmailService.instance.sendRegistrationOtpEmail(
      recipientEmail: widget.email,
      recipientName: widget.name,
      otpCode: _currentOtp,
    );

    if (mounted) {
      setState(() {
        _isResending = false;
        if (sent) {
          _resendAttempts++;
        }
      });
      if (sent) {
        // Update anti-spam trackers
        _RegisterScreenState._lastOtpSentTime = DateTime.now();
        _RegisterScreenState._lastSentEmail = widget.email;
        _RegisterScreenState._lastSentOtp = _currentOtp;
        _startTimers(reset: true);
        _showTopNotification('New verification code sent!');
      } else {
        _showTopNotification(
          'Failed to send code. Try again later.',
          isError: true,
        );
      }
    }
  }

  void _verify() {
    if (_formKey.currentState!.validate()) {
      if (_otpController.text == _currentOtp) {
        Navigator.pop(context, true);
      } else {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    _inputTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(32),
      title: null,
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.mailCheck,
                  size: 38,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit verification code to:\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  color: _hasError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                onChanged: (_) {
                  if (_hasError) setState(() => _hasError = false);
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    letterSpacing: 12,
                  ),
                  errorText: _hasError ? 'Incorrect verification code' : null,
                  filled: true,
                  fillColor: _hasError
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.length != 6) {
                    return 'Enter the 6-digit code';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              if (_inputCountdown > 0)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey<int>(_inputCountdown > 0 ? 1 : 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ), // Not harsh red
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.timer,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expires in 00:${_inputCountdown.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'Code has expired. Please request a new one.',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _inputCountdown > 0 ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Verify Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  _isResending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _resendCooldown == 0 && _resendAttempts < 3
                              ? _handleResend
                              : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            _resendAttempts >= 3
                                ? 'Limit Reached'
                                : _resendCooldown > 0
                                ? 'Resend in ${_resendCooldown}s'
                                : 'Resend',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _resendAttempts >= 3
                                  ? theme.colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel Registration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
