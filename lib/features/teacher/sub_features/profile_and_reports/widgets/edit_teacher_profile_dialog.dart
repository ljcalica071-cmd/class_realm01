import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/consultation_hours_picker.dart';

/// Modal dialog allowing a teacher to edit their complete profile,
/// with strict inline validation matching the Add Teacher standard,
/// ClassRealm's native birthdate picker, per-day consultation hours,
/// and email OTP verification for email address modifications.
class EditTeacherProfileDialog extends StatefulWidget {
  final UserModel teacher;
  final ValueChanged<UserModel>? onProfileUpdated;

  const EditTeacherProfileDialog({
    super.key,
    required this.teacher,
    this.onProfileUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required UserModel teacher,
    ValueChanged<UserModel>? onProfileUpdated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => EditTeacherProfileDialog(
        teacher: teacher,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<EditTeacherProfileDialog> createState() =>
      _EditTeacherProfileDialogState();
}

class _EditTeacherProfileDialogState extends State<EditTeacherProfileDialog> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _facebookCtrl;

  late String _selectedGender;
  late DateTime _selectedBirthday;
  String? _consultationHours;
  bool _isConsultationHoursValid = true;

  late bool _isPhonePublic;
  late bool _isFacebookPublic;

  bool _isSubmitting = false;
  bool _hasAttemptedSave = false;

  // Inline error strings
  String? _firstNameError;
  String? _middleNameError;
  String? _lastNameError;
  String? _birthdayError;
  String? _emailError;
  String? _subjectError;
  String? _phoneError;
  String? _facebookError;

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;
    _firstNameCtrl = TextEditingController(text: t.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: t.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: t.lastName ?? '');
    _emailCtrl = TextEditingController(text: t.email);
    _subjectCtrl = TextEditingController(text: t.subjectSpecialization ?? '');
    _phoneCtrl = TextEditingController(text: t.contactNumber ?? '');
    _facebookCtrl = TextEditingController(text: t.facebookLink ?? '');

    _selectedGender = (t.gender != null && t.gender!.isNotEmpty)
        ? t.gender!
        : 'Female';
    _selectedBirthday = t.birthday ?? DateTime(1995, 1, 1);
    _consultationHours = t.consultationHours;
    _isPhonePublic = t.isPhonePublic;
    _isFacebookPublic = t.isFacebookPublic;

    // Listen to changes to dynamically update Save button enabled state & run live validation
    _firstNameCtrl.addListener(_onFieldChanged);
    _middleNameCtrl.addListener(_onFieldChanged);
    _lastNameCtrl.addListener(_onFieldChanged);
    _emailCtrl.addListener(_onFieldChanged);
    _subjectCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);
    _facebookCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    _runLiveValidation();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _runLiveValidation() {
    // 1. First Name live validation
    if (_hasAttemptedSave || _firstNameError != null) {
      _firstNameError = AppValidators.validateName(
        _firstNameCtrl.text,
        'First name',
      );
    }

    // 2. Middle Initial live validation
    if (_hasAttemptedSave || _middleNameError != null) {
      _middleNameError = AppValidators.validateMiddleInitial(
        _middleNameCtrl.text,
      );
    }

    // 3. Last Name live validation
    if (_hasAttemptedSave || _lastNameError != null) {
      _lastNameError = AppValidators.validateName(
        _lastNameCtrl.text,
        'Last name',
      );
    }

    // 4. Subject Specialization live validation (Optional: 2-100 chars, no empty spaces)
    final spec = _subjectCtrl.text.trim();
    if (spec.isNotEmpty) {
      if (spec.length < 2) {
        if (_hasAttemptedSave || _subjectError != null) {
          _subjectError =
              'Subject specialization must be at least 2 characters.';
        }
      } else if (spec.length > 100) {
        _subjectError = 'Subject specialization cannot exceed 100 characters.';
      } else {
        _subjectError = null;
      }
    } else {
      _subjectError = null;
    }

    // 5. Phone Number live validation (Optional: 11-digit starting with 09)
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      final phoneRegex = RegExp(r'^09\d{9}$');
      if (phone.length == 11 && phoneRegex.hasMatch(phone)) {
        _phoneError = null;
      } else if (_hasAttemptedSave || _phoneError != null) {
        if (phone.length == 11 && !phoneRegex.hasMatch(phone)) {
          _phoneError = 'Phone number must be an 11-digit mobile number starting with 09 (e.g. 09123456789).';
        } else if (phone.length > 11) {
          _phoneError = 'Phone number cannot exceed 11 digits.';
        } else if (_hasAttemptedSave && phone.length < 11) {
          _phoneError = 'Phone number must be an 11-digit mobile number starting with 09 (e.g. 09123456789).';
        }
      }
    } else {
      _phoneError = null;
    }

    // 6. Facebook Link live validation (Optional: valid URL)
    final fb = _facebookCtrl.text.trim();
    if (fb.isNotEmpty) {
      final fbRegex = RegExp(
        r'^https?:\/\/(www\.)?(facebook\.com|fb\.me)\/[A-Za-z0-9._%+-]{3,}\/?$',
        caseSensitive: false,
      );
      if (fbRegex.hasMatch(fb)) {
        _facebookError = null;
      } else if (_hasAttemptedSave || _facebookError != null) {
        _facebookError = 'Enter a valid Facebook profile URL (e.g. https://facebook.com/karen.gonzaga).';
      }
    } else {
      _facebookError = null;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.removeListener(_onFieldChanged);
    _middleNameCtrl.removeListener(_onFieldChanged);
    _lastNameCtrl.removeListener(_onFieldChanged);
    _emailCtrl.removeListener(_onFieldChanged);
    _subjectCtrl.removeListener(_onFieldChanged);
    _phoneCtrl.removeListener(_onFieldChanged);
    _facebookCtrl.removeListener(_onFieldChanged);

    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _phoneCtrl.dispose();
    _facebookCtrl.dispose();
    super.dispose();
  }

  String _normalize(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == 'Not specified' ||
        trimmed == 'null' ||
        trimmed == 'Not provided' ||
        trimmed == 'Not linked') {
      return '';
    }
    return trimmed;
  }

  /// Evaluates whether actual changes were made compared to the initial teacher model.
  bool get _hasChanges {
    final t = widget.teacher;
    if (_normalize(_firstNameCtrl.text) != _normalize(t.firstName)) return true;
    if (_normalize(_middleNameCtrl.text) != _normalize(t.middleName)) {
      return true;
    }
    if (_normalize(_lastNameCtrl.text) != _normalize(t.lastName)) return true;

    final initialGender = (t.gender != null && t.gender!.isNotEmpty)
        ? t.gender!
        : 'Female';
    if (_selectedGender != initialGender) return true;

    final initialBday = t.birthday ?? DateTime(1995, 1, 1);
    if (_selectedBirthday.year != initialBday.year ||
        _selectedBirthday.month != initialBday.month ||
        _selectedBirthday.day != initialBday.day) {
      return true;
    }

    if (_normalize(_emailCtrl.text).toLowerCase() !=
        _normalize(t.email).toLowerCase()) {
      return true;
    }

    // Specialization comparison
    if (_normalize(_subjectCtrl.text) != _normalize(t.subjectSpecialization)) {
      return true;
    }

    // Consultation hours comparison
    if (_normalize(_consultationHours) != _normalize(t.consultationHours)) {
      return true;
    }

    // Phone comparison
    if (_normalize(_phoneCtrl.text) != _normalize(t.contactNumber)) return true;
    if (_isPhonePublic != t.isPhonePublic) return true;

    // Facebook comparison
    if (_normalize(_facebookCtrl.text) != _normalize(t.facebookLink)) {
      return true;
    }
    if (_isFacebookPublic != t.isFacebookPublic) return true;

    return false;
  }

  bool _validateInputs() {
    _hasAttemptedSave = true;
    bool valid = true;

    // 1. First Name (Required, AppValidators standard)
    _firstNameError = AppValidators.validateName(
      _firstNameCtrl.text,
      'First name',
    );
    if (_firstNameError != null) valid = false;

    // 2. Middle Initial / Name (Optional, validated if provided)
    _middleNameError = AppValidators.validateMiddleInitial(
      _middleNameCtrl.text,
    );
    if (_middleNameError != null) valid = false;

    // 3. Last Name (Required, AppValidators standard)
    _lastNameError = AppValidators.validateName(
      _lastNameCtrl.text,
      'Last name',
    );
    if (_lastNameError != null) valid = false;

    // 4. Birthday (Required, BirthdayValidator standard for teachers)
    _birthdayError = BirthdayValidator.validateBirthday(
      _selectedBirthday,
      'teacher',
    );
    if (_birthdayError != null) valid = false;

    // 5. Email (Required, AppValidators standard)
    _emailError = AppValidators.validateEmail(_emailCtrl.text);
    if (_emailError != null) valid = false;

    // 6. Subject Specialization (Optional, 2-100 chars, no empty spaces if non-empty)
    final spec = _subjectCtrl.text.trim();
    if (spec.isNotEmpty) {
      if (spec.length < 2) {
        _subjectError = 'Subject specialization must be at least 2 characters.';
        valid = false;
      } else if (spec.length > 100) {
        _subjectError = 'Subject specialization cannot exceed 100 characters.';
        valid = false;
      } else {
        _subjectError = null;
      }
    } else {
      _subjectError = null;
    }

    // 7. Phone Number (Optional, 11-digit starting with 09)
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      final phoneRegex = RegExp(r'^09\d{9}$');
      if (!phoneRegex.hasMatch(phone)) {
        _phoneError = 'Phone number must be an 11-digit mobile number starting with 09 (e.g. 09123456789).';
        valid = false;
      } else {
        _phoneError = null;
      }
    } else {
      _phoneError = null;
    }

    // 8. Facebook Link (Optional, valid profile URL)
    final fb = _facebookCtrl.text.trim();
    if (fb.isNotEmpty) {
      final fbRegex = RegExp(
        r'^https?:\/\/(www\.)?(facebook\.com|fb\.me)\/[A-Za-z0-9._%+-]{3,}\/?$',
        caseSensitive: false,
      );
      if (!fbRegex.hasMatch(fb)) {
        _facebookError = 'Enter a valid Facebook profile URL (e.g. https://facebook.com/karen.gonzaga).';
        valid = false;
      } else {
        _facebookError = null;
      }
    } else {
      _facebookError = null;
    }

    // 9. Consultation Hours (Optional, valid duration if configured)
    if (!_isConsultationHoursValid) {
      valid = false;
    }

    setState(() {});
    return valid;
  }

  Future<void> _handleSave() async {
    if (!_hasChanges) return;
    if (!_validateInputs()) return;

    final originalEmail = widget.teacher.email.trim().toLowerCase();
    final newEmail = _emailCtrl.text.trim().toLowerCase();
    final emailChanged = originalEmail != newEmail;

    if (emailChanged) {
      // Prompt for Email OTP verification
      await _initiateEmailChangeOtpFlow(newEmail);
    } else {
      await _commitProfileUpdate();
    }
  }

  Future<void> _initiateEmailChangeOtpFlow(String newEmail) async {
    setState(() => _isSubmitting = true);

    try {
      final fullName = [
        _firstNameCtrl.text.trim(),
        _lastNameCtrl.text.trim(),
      ].join(' ');

      // Dispatch 6-digit OTP
      await AuthRepository.instance.sendTeacherEmailChangeOtp(
        newEmail: newEmail,
        teacherName: fullName,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Open PasswordOtpDialog to verify code
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PasswordOtpDialog(
          email: newEmail,
          title: 'Verify New Email Address',
          subtitle:
              'A 6-digit verification code has been dispatched to $newEmail. Enter it below to confirm your new email address.',
          submitButtonLabel: 'Verify & Update Email',
          onVerify: (code) => AuthRepository.instance
              .verifyTeacherEmailChangeOtp(newEmail: newEmail, code: code),
          onResend: () => AuthRepository.instance.sendTeacherEmailChangeOtp(
            newEmail: newEmail,
            teacherName: fullName,
          ),
        ),
      );

      if (verified == true) {
        await _commitProfileUpdate(emailToSave: newEmail);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppTopToast.show(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _commitProfileUpdate({String? emailToSave}) async {
    setState(() => _isSubmitting = true);

    try {
      final fName = _firstNameCtrl.text.trim();
      final mName = _middleNameCtrl.text.trim();
      final lName = _lastNameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final fb = _facebookCtrl.text.trim();
      final subject = _subjectCtrl.text.trim();
      final consult =
          (_consultationHours != null &&
              _consultationHours!.trim().isNotEmpty &&
              _consultationHours!.trim() != 'Not specified')
          ? _consultationHours!.trim()
          : null;

      await AuthRepository.instance.updateTeacherCompleteProfile(
        teacherId: widget.teacher.id,
        firstName: fName,
        middleName: mName.isNotEmpty ? mName : null,
        lastName: lName,
        gender: _selectedGender,
        birthday: _selectedBirthday,
        newEmail: emailToSave ?? widget.teacher.email,
        subjectSpecialization: subject.isNotEmpty ? subject : null,
        consultationHours: consult,
        facebookLink: fb.isNotEmpty ? fb : null,
        isFacebookPublic: _isFacebookPublic,
        contactNumber: phone.isNotEmpty ? phone : null,
        isPhonePublic: _isPhonePublic,
      );

      final updatedTeacher = widget.teacher.copyWith(
        firstName: fName,
        middleName: mName.isNotEmpty ? mName : null,
        lastName: lName,
        fullName: [fName, mName, lName].where((s) => s.isNotEmpty).join(' '),
        gender: _selectedGender,
        birthday: _selectedBirthday,
        email: emailToSave ?? widget.teacher.email,
        subjectSpecialization: subject.isNotEmpty ? subject : null,
        consultationHours: consult,
        facebookLink: fb.isNotEmpty ? fb : null,
        isFacebookPublic: _isFacebookPublic,
        contactNumber: phone.isNotEmpty ? phone : null,
        isPhonePublic: _isPhonePublic,
      );

      if (!mounted) return;
      widget.onProfileUpdated?.call(updatedTeacher);
      Navigator.of(context).pop();

      AppTopToast.show(
        context,
        message: 'Profile updated successfully!',
        type: AppToastType.success,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppTopToast.show(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          type: AppToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 650;
    final hasChanges = _hasChanges;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_note,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Faculty Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update your personal information, consultation schedule, and contact preferences.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: IDENTITY & BASIC INFO ---
                    _buildSectionTitle(
                      theme,
                      'Identity & Basic Information',
                      Icons.badge_outlined,
                    ),
                    const SizedBox(height: 14),

                    // First Name, Middle Initial & Last Name Row
                    if (isMobile) ...[
                      _buildTextField(
                        controller: _firstNameCtrl,
                        label: 'First Name *',
                        hint: 'e.g. Karen',
                        errorText: _firstNameError,
                        icon: Icons.badge_outlined,
                        maxLength: 30,
                        inputFormatters: AppValidators.nameFormatters,
                        theme: theme,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _middleNameCtrl,
                        label: 'Middle Initial',
                        hint: 'e.g. H.',
                        errorText: _middleNameError,
                        icon: Icons.person_outline,
                        maxLength: 2,
                        inputFormatters: AppValidators.middleInitialFormatters,
                        theme: theme,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _lastNameCtrl,
                        label: 'Last Name *',
                        hint: 'e.g. Gonzaga',
                        errorText: _lastNameError,
                        icon: Icons.badge_outlined,
                        maxLength: 30,
                        inputFormatters: AppValidators.nameFormatters,
                        theme: theme,
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildTextField(
                              controller: _firstNameCtrl,
                              label: 'First Name *',
                              hint: 'e.g. Karen',
                              errorText: _firstNameError,
                              icon: Icons.badge_outlined,
                              maxLength: 30,
                              inputFormatters: AppValidators.nameFormatters,
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: _buildTextField(
                              controller: _middleNameCtrl,
                              label: 'Middle Initial',
                              hint: 'e.g. H.',
                              errorText: _middleNameError,
                              icon: Icons.person_outline,
                              maxLength: 2,
                              inputFormatters:
                                  AppValidators.middleInitialFormatters,
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: _buildTextField(
                              controller: _lastNameCtrl,
                              label: 'Last Name *',
                              hint: 'e.g. Gonzaga',
                              errorText: _lastNameError,
                              icon: Icons.badge_outlined,
                              maxLength: 30,
                              inputFormatters: AppValidators.nameFormatters,
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Gender & Birthday Pickers (Matching Add Teacher standard)
                    if (isMobile) ...[
                      _buildGenderDropdown(theme),
                      const SizedBox(height: 14),
                      AppDatePickerField(
                        label: 'Birthdate *',
                        initialDate: _selectedBirthday,
                        firstDate: BirthdayValidator.getMinDate(),
                        lastDate: BirthdayValidator.getMaxDate('teacher'),
                        onDateSelected: (date) {
                          setState(() {
                            _selectedBirthday = date;
                            _birthdayError = BirthdayValidator.validateBirthday(
                              date,
                              'teacher',
                            );
                            _onFieldChanged();
                          });
                        },
                        validator: (v) =>
                            BirthdayValidator.validateBirthday(v, 'teacher'),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: _buildGenderDropdown(theme)),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 1,
                            child: AppDatePickerField(
                              label: 'Birthdate *',
                              initialDate: _selectedBirthday,
                              firstDate: BirthdayValidator.getMinDate(),
                              lastDate: BirthdayValidator.getMaxDate('teacher'),
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedBirthday = date;
                                  _birthdayError =
                                      BirthdayValidator.validateBirthday(
                                        date,
                                        'teacher',
                                      );
                                  _onFieldChanged();
                                });
                              },
                              validator: (v) =>
                                  BirthdayValidator.validateBirthday(
                                    v,
                                    'teacher',
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_birthdayError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _birthdayError!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Email Address
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email Address *',
                      hint: 'e.g. karen.gonzaga@gmail.com',
                      errorText: _emailError,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: AppValidators.emailFormatters,
                      theme: theme,
                      helperText: 'Note: Modifying your email requires a 6-digit OTP verification.',
                    ),
                    const SizedBox(height: 28),

                    // --- SECTION 2: PROFESSIONAL & CONSULTATION ---
                    _buildSectionTitle(
                      theme,
                      'Professional & Consultation Hours',
                      Icons.work_outline_rounded,
                    ),
                    const SizedBox(height: 14),

                    // Subject Specialization (Optional)
                    _buildTextField(
                      controller: _subjectCtrl,
                      label: 'Subject Specialization',
                      hint: 'e.g. General Mathematics & Statistics (Optional)',
                      errorText: _subjectError,
                      icon: Icons.science_outlined,
                      maxLength: 100,
                      helperText: 'Optional: 2–100 characters if specified.',
                      theme: theme,
                    ),
                    const SizedBox(height: 16),

                    // Consultation Hours Picker (Optional, per-day digital time picker)
                    Text(
                      'Consultation Schedule',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConsultationHoursPicker(
                      initialValue: _consultationHours,
                      onChanged: (formatted, isValid) {
                        _consultationHours = formatted;
                        _isConsultationHoursValid = isValid;
                        _onFieldChanged();
                      },
                    ),
                    const SizedBox(height: 28),

                    // --- SECTION 3: CONTACT & PRIVACY ---
                    _buildSectionTitle(
                      theme,
                      'Contact Information & Privacy Visibility',
                      Icons.contact_phone_outlined,
                    ),
                    const SizedBox(height: 14),

                    // Phone Number with Toggle (Optional)
                    _buildContactFieldWithPrivacy(
                      controller: _phoneCtrl,
                      label: 'Mobile Phone Number',
                      hint: '09XXXXXXXXX (11 digits, Optional)',
                      icon: Icons.phone_outlined,
                      errorText: _phoneError,
                      isPublic: _isPhonePublic,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      keyboardType: TextInputType.phone,
                      onTogglePublic: (val) {
                        setState(() {
                          _isPhonePublic = val;
                          _onFieldChanged();
                        });
                      },
                      theme: theme,
                    ),
                    const SizedBox(height: 16),

                    // Facebook Link with Toggle (Optional)
                    _buildContactFieldWithPrivacy(
                      controller: _facebookCtrl,
                      label: 'Facebook Profile Link',
                      hint: 'https://facebook.com/username (Optional)',
                      icon: Icons.facebook,
                      errorText: _facebookError,
                      isPublic: _isFacebookPublic,
                      keyboardType: TextInputType.url,
                      onTogglePublic: (val) {
                        setState(() {
                          _isFacebookPublic = val;
                          _onFieldChanged();
                        });
                      },
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Actions Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hasChanges ? 'Unsaved changes' : 'No changes made',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: hasChanges
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (_isSubmitting || !hasChanges)
                            ? null
                            : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasChanges
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.12,
                                ),
                          foregroundColor: hasChanges
                              ? Colors.white
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.38,
                                ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    String? errorText,
    String? helperText,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            if (maxLength != null) ...[
              const SizedBox(width: 4),
              Text(
                '${controller.text.length}/$maxLength',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: controller.text.length >= maxLength
                      ? const Color(0xFFEF4444)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: [
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            ...?inputFormatters,
          ],
          style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 18,
              color: hasError
                  ? const Color(0xFFDC2626)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.25,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue:
              ['Male', 'Female', 'Prefer not to say'].contains(_selectedGender)
              ? _selectedGender
              : 'Female',
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(
              value: 'Prefer not to say',
              child: Text('Prefer not to say'),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedGender = val;
                _onFieldChanged();
              });
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.wc_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.25,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactFieldWithPrivacy({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? errorText,
    required bool isPublic,
    required ValueChanged<bool> onTogglePublic,
    required ThemeData theme,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            // Privacy Visibility Switch
            Row(
              children: [
                Icon(
                  isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                  size: 14,
                  color: isPublic
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  isPublic ? 'Public' : 'Private',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isPublic
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: isPublic,
                    onChanged: onTogglePublic,
                    activeThumbColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 18,
              color: hasError
                  ? const Color(0xFFDC2626)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.25,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
