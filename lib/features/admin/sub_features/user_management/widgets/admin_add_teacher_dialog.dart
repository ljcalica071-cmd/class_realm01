import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum TeacherCreationStep { details, otpVerification, success }

class AdminAddTeacherDialog extends StatefulWidget {
  const AdminAddTeacherDialog({super.key});

  @override
  State<AdminAddTeacherDialog> createState() => _AdminAddTeacherDialogState();
}

class _AdminAddTeacherDialogState extends State<AdminAddTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  TeacherCreationStep _step = TeacherCreationStep.details;
  String? _gender;
  DateTime? _birthday;
  bool _isLoading = false;
  bool _submitted = false;
  String? _error;
  String? _successMessage;

  String? _createdEmail;
  String? _createdPassword;
  String? _createdFullName;
  bool _copied = false;

  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;
  int _failedAttempts = 0;
  String? _activeChallengeEmail;

  bool get _isLockedOut => _failedAttempts >= 5;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining--);
      }
    });
  }

  Future<void> _sendOtpCode() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _birthday == null) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }

    final email = _emailController.text.trim().toLowerCase();

    // Anti-spam mechanism: If active OTP already sent to this exact email and 60s cooldown is still ticking,
    // seamlessly proceed directly to Step 2 without spamming duplicate email or triggering server rate limit
    if (_activeChallengeEmail == email && _resendSecondsRemaining > 0) {
      setState(() {
        _step = TeacherCreationStep.otpVerification;
        _error = null;
        _successMessage =
            'A 6-digit verification OTP code has been sent to ${_emailController.text.trim()}.';
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _otpFocusNode.requestFocus();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final res = await AuthRepository.instance.sendAdminTeacherVerification(
        email: email,
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _gender!,
        birthday: _birthday!,
        isResend: false,
      );

      _activeChallengeEmail = email;
      final remainingCooldown =
          (res['remainingCooldownSeconds'] as num?)?.toInt() ?? 60;
      _startResendTimer(remainingCooldown);
      if (res['failedAttempts'] != null) {
        _failedAttempts = (res['failedAttempts'] as num).toInt();
      }

      if (mounted) {
        setState(() {
          _step = TeacherCreationStep.otpVerification;
          _error = null;
          _successMessage =
              'A 6-digit verification OTP code has been sent to ${_emailController.text.trim()}.';
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtpCode() async {
    if (_resendSecondsRemaining > 0 || _isLoading || _isLockedOut) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final res = await AuthRepository.instance.sendAdminTeacherVerification(
        email: email,
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _gender!,
        birthday: _birthday!,
        isResend: true,
      );
      if (mounted) {
        _activeChallengeEmail = email;
        _startResendTimer(60);
        if (res['failedAttempts'] != null) {
          _failedAttempts = (res['failedAttempts'] as num).toInt();
        }
        setState(() {
          _otpController.clear();
          // Attempts are preserved across resends! Do not reset _failedAttempts to 0.
          _error = null;
          _successMessage =
              'A new 6-digit verification code has been sent to ${_emailController.text.trim()}.';
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (error is AdminTeacherException && error.maxAttemptsExceeded) {
        setState(() {
          _failedAttempts = 5;
          _error = error.message;
        });
      } else {
        setState(() => _error = _messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpAndCreate() async {
    if (_isLockedOut) return;

    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await AuthRepository.instance.verifyAdminTeacherAndCreate(
        email: _emailController.text.trim(),
        code: code,
      );
      _resendTimer?.cancel();
      if (mounted) {
        setState(() {
          _step = TeacherCreationStep.success;
          _createdEmail = res['email']?.toString() ?? _emailController.text.trim();
          _createdPassword = res['temporaryPassword']?.toString() ?? '';
          _createdFullName = res['fullName']?.toString() ??
              '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (error is AdminTeacherException) {
        if (error.failedAttempts != null) {
          _failedAttempts = error.failedAttempts!;
        } else {
          _failedAttempts++;
        }
        if (_failedAttempts >= 5 || error.maxAttemptsExceeded) {
          _failedAttempts = 5;
          setState(() {
            _error = error.message;
          });
        } else {
          setState(() {
            _error = error.message;
          });
        }
      } else {
        _failedAttempts++;
        final remaining = (5 - _failedAttempts).clamp(0, 5);
        if (_failedAttempts >= 5) {
          setState(() {
            _error =
                'Maximum verification attempts exceeded (5/5). Please click Back to recheck teacher details.';
          });
        } else {
          final serverMsg = _messageFor(error);
          setState(() {
            _error = serverMsg.contains('attempt')
                ? serverMsg
                : 'Incorrect or expired code. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildOtpDigitBoxes(ThemeData theme, bool isDark) {
    final hasError = _error != null;
    final currentLength = _otpController.text.length;

    return Stack(
      children: [
        // Invisible input field that handles keyboard, paste, backspace natively
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              autofocus: true,
              enabled: !_isLockedOut,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (val) {
                setState(() {
                  if (!_isLockedOut) _error = null;
                });
                if (val.length == 6 && !_isLockedOut && !_isLoading) {
                  _verifyOtpAndCreate();
                }
              },
            ),
          ),
        ),

        // Visual 6 separated digit boxes matching the UI design
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_isLockedOut) _otpFocusNode.requestFocus();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < currentLength;
              final isCurrent =
                  index == currentLength && _otpFocusNode.hasFocus && !hasError;
              final digit = isFilled ? _otpController.text[index] : '';

              Color borderColor;
              double borderWidth = 1.0;
              Color boxBg =
                  isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;

              if (hasError) {
                borderColor = Colors.red.shade600;
                borderWidth = 1.8;
                boxBg = Colors.red.withValues(alpha: isDark ? 0.08 : 0.03);
              } else if (isCurrent) {
                borderColor = theme.colorScheme.primary;
                borderWidth = 2.0;
              } else if (isFilled) {
                borderColor = isDark ? Colors.white38 : Colors.grey.shade400;
                borderWidth = 1.2;
              } else {
                borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
              }

              return Container(
                width: 48,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: Text(
                  digit,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: hasError
                        ? Colors.red.shade600
                        : theme.colorScheme.onSurface,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _copyCredentials() {
    final text =
        'ClassRealm Teacher Account\nEmail: $_createdEmail\nTemporary Password: $_createdPassword';
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _messageFor(Object error) {
    String msg = error.toString().replaceFirst('Exception: ', '');
    if (msg.contains('details:')) {
      final match = RegExp(r'error:\s*([^,\}]+)').firstMatch(msg);
      if (match != null) {
        return match.group(1)?.trim() ?? msg;
      }
    }
    return msg;
  }

  InputDecoration _inputDecoration(
    ThemeData theme, {
    required String hintText,
    Widget? prefixIcon,
    bool isDark = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(1, 'Details', _step == TeacherCreationStep.details,
            _step != TeacherCreationStep.details, theme),
        Container(
          width: 32,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: _step == TeacherCreationStep.details
              ? Colors.grey.shade300
              : theme.colorScheme.primary,
        ),
        _buildStepDot(
            2,
            'Verify OTP',
            _step == TeacherCreationStep.otpVerification,
            _step == TeacherCreationStep.success,
            theme),
        Container(
          width: 32,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: _step == TeacherCreationStep.success
              ? theme.colorScheme.primary
              : Colors.grey.shade300,
        ),
        _buildStepDot(3, 'Ready', _step == TeacherCreationStep.success, false, theme),
      ],
    );
  }

  Widget _buildStepDot(
      int number, String label, bool isActive, bool isPassed, ThemeData theme) {
    final color = isActive || isPassed
        ? theme.colorScheme.primary
        : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isPassed ? color : (isActive ? color : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: isPassed
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : color,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? color : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // School Header
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      AssetPaths.schoolLogo,
                      height: 52,
                      width: 52,
                      errorBuilder: (_, __, ___) => const Icon(
                        LucideIcons.graduationCap,
                        size: 40,
                        color: Color(0xFF1A365D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Eduardo Barretto Sr. Integrated School',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _step == TeacherCreationStep.details
                          ? 'Create Teacher Account'
                          : _step == TeacherCreationStep.otpVerification
                              ? 'Verify Email OTP'
                              : 'Account Created Successfully',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Step Breadcrumb Indicator
              _buildStepIndicator(theme),
              const SizedBox(height: 18),

              // --- STEP 1: TEACHER DETAILS ---
              if (_step == TeacherCreationStep.details)
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _submitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('PERSONAL INFORMATION', theme),

                          // Names Row (First, Middle, Last)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('First Name*', theme),
                                    TextFormField(
                                      controller: _firstNameController,
                                      textCapitalization: TextCapitalization.words,
                                      inputFormatters: AppValidators.nameFormatters,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        theme,
                                        hintText: 'e.g. Karen',
                                        isDark: isDark,
                                      ),
                                      validator: (v) => AppValidators.validateName(
                                          v, 'First name'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Middle Name', theme),
                                    TextFormField(
                                      controller: _middleNameController,
                                      textCapitalization: TextCapitalization.words,
                                      inputFormatters: AppValidators.nameFormatters,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        theme,
                                        hintText: 'e.g. P.',
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Last Name*', theme),
                                    TextFormField(
                                      controller: _lastNameController,
                                      textCapitalization: TextCapitalization.words,
                                      inputFormatters: AppValidators.nameFormatters,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        theme,
                                        hintText: 'e.g. Gonzaga',
                                        isDark: isDark,
                                      ),
                                      validator: (v) => AppValidators.validateName(
                                          v, 'Last name'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 2: Gender & Birthdate
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Gender*', theme),
                                    DropdownButtonFormField<String>(
                                      initialValue: _gender,
                                      isExpanded: true,
                                      decoration: _inputDecoration(
                                        theme,
                                        hintText: 'Select Gender',
                                        isDark: isDark,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Male',
                                          child: Text('Male'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Female',
                                          child: Text('Female'),
                                        ),
                                      ],
                                      onChanged: (v) => setState(() => _gender = v),
                                      validator: (v) =>
                                          (v == null || v.isEmpty)
                                              ? 'Gender is required'
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: AppDatePickerField(
                                  label: 'Birthdate*',
                                  initialDate: _birthday,
                                  firstDate: BirthdayValidator.getMinDate(),
                                  lastDate: BirthdayValidator.getMaxDate('teacher'),
                                  onDateSelected: (date) {
                                    setState(() => _birthday = date);
                                  },
                                  validator: (v) => BirthdayValidator.validateBirthday(
                                      v, 'teacher'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildSectionHeader('ACCOUNT DETAILS', theme),

                          // Email Address
                          _buildFieldLabel('Email Address*', theme),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _sendOtpCode(),
                            decoration: _inputDecoration(
                              theme,
                              hintText: 'e.g. karen.gonzaga@gmail.com',
                              prefixIcon: Icon(
                                LucideIcons.mail,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              isDark: isDark,
                            ),
                            validator: AppValidators.validateEmail,
                          ),
                        ],
                      ),
                    ),
                  ),
                )

              // --- STEP 2: VERIFY OTP ---
              else if (_step == TeacherCreationStep.otpVerification)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.mailCheck,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verification code sent',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Check the 6-digit code sent to ${_emailController.text}.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildOtpDigitBoxes(theme, isDark),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ],
                )

              // --- STEP 3: SUCCESS & CREDENTIALS ---
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade300, width: 2),
                      ),
                      child: Icon(
                        LucideIcons.circleCheck,
                        color: Colors.green.shade700,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Teacher Account Created Successfully!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'An automated welcome email with these credentials has been sent to $_createdEmail.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Credentials Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TEACHER LOGIN CREDENTIALS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _copyCredentials,
                                icon: Icon(
                                  _copied ? LucideIcons.check : LucideIcons.copy,
                                  size: 14,
                                  color: _copied ? Colors.green : theme.colorScheme.primary,
                                ),
                                label: Text(_copied ? 'Copied!' : 'Copy'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 130,
                                child: Text('Full Name:',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                              ),
                              Expanded(
                                child: Text(
                                  _createdFullName ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 130,
                                child: Text('Email Address:',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                              ),
                              Expanded(
                                child: Text(
                                  _createdEmail ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 130,
                                child: Text('Temporary Password:',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _createdPassword ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.info, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Teacher will be prompted to set their new password upon first login.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              // Error banner if any (only on step 1 or step 3; step 2 displays it directly beneath the OTP boxes)
              if (_error != null && _step != TeacherCreationStep.otpVerification) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circleAlert,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // --- BUTTON ACTIONS ---
              if (_step == TeacherCreationStep.details)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _sendOtpCode,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? LoadingAnimationWidget.staggeredDotsWave(
                              color: Colors.white,
                              size: 20,
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.send, size: 16),
                                SizedBox(width: 8),
                                Text('Send OTP Code'),
                              ],
                            ),
                    ),
                  ],
                )
              else if (_step == TeacherCreationStep.otpVerification)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _step = TeacherCreationStep.details;
                                _error = null;
                                _successMessage = null;
                              });
                            },
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_isLoading ||
                                  _resendSecondsRemaining > 0 ||
                                  _isLockedOut)
                              ? null
                              : _resendOtpCode,
                          icon: const Icon(LucideIcons.refreshCw, size: 14),
                          label: Text(_resendSecondsRemaining > 0
                              ? 'Resend (${_resendSecondsRemaining}s)'
                              : 'Resend'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            foregroundColor: theme.colorScheme.onSurface,
                            disabledForegroundColor: theme.colorScheme.onSurface
                                .withValues(alpha: 0.38),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.6),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              (_isLoading || _isLockedOut) ? null : _verifyOtpAndCreate,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? LoadingAnimationWidget.staggeredDotsWave(
                                  color: Colors.white,
                                  size: 20,
                                )
                              : const Text('Verify Account'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                // Step 3: Done Button
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text('Done'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
