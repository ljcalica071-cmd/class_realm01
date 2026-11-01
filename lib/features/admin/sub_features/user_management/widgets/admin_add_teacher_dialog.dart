import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
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

class _AdminAddTeacherDialogState extends State<AdminAddTeacherDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  AnimationController? _cursorBlinkController;
  int _selectedIndex = 0;

  AnimationController get _effectiveCursorBlinkController {
    _cursorBlinkController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      )..repeat(reverse: true);
    return _cursorBlinkController!;
  }

  TeacherCreationStep _step = TeacherCreationStep.details;
  String? _gender;
  DateTime? _birthday;
  bool _isLoading = false;
  bool _isResending = false;
  bool _isVerifying = false;
  bool _submitted = false;
  String? _error;

  String? _createdEmail;

  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;
  DateTime? _lastSentAt;
  Timer? _otpExpiryTimer;
  int _otpSecondsRemaining = 300;
  int _failedAttempts = 0;
  String? _activeChallengeEmail;
  DateTime? _activeChallengeExpiresAt;

  bool get _isAnyBusy => _isLoading || _isResending || _isVerifying;
  bool get _isLockedOut => _failedAttempts >= 5;

  @override
  void initState() {
    super.initState();
    _cursorBlinkController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _otpFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _otpFocusNode.onKeyEvent = (node, event) {
      if (_otpSecondsRemaining <= 0) return KeyEventResult.handled;
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _handleBackspaceKey();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1).clamp(0, _otpController.text.length);
            _otpController.selection =
                TextSelection.collapsed(offset: _selectedIndex);
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() {
            _selectedIndex =
                (_selectedIndex + 1).clamp(0, _otpController.text.length);
            _otpController.selection =
                TextSelection.collapsed(offset: _selectedIndex);
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _cursorBlinkController?.dispose();
    _cursorBlinkController = null;
    _resendTimer?.cancel();
    _otpExpiryTimer?.cancel();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  String _formatOtpTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startOtpExpiryTimer([int seconds = 300]) {
    _otpExpiryTimer?.cancel();
    setState(() => _otpSecondsRemaining = seconds);
    if (seconds <= 0) {
      _expireOtp();
      return;
    }
    _otpExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpSecondsRemaining <= 1) {
        timer.cancel();
        _expireOtp();
      } else {
        setState(() => _otpSecondsRemaining--);
      }
    });
  }

  void _expireOtp() {
    if (!mounted) return;
    setState(() {
      _otpSecondsRemaining = 0;
      _otpController.clear();
      _selectedIndex = 0;
      _error =
          'The verification code has expired (5 minutes passed). Please click Resend.';
    });
    _otpFocusNode.unfocus();
  }

  void _startResendTimer([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = seconds);
    if (seconds <= 0) return;
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

    // Anti-spam: Reuse active challenge if still valid within its 5-minute expiry window
    if (_activeChallengeEmail == email &&
        _activeChallengeExpiresAt != null &&
        DateTime.now().isBefore(_activeChallengeExpiresAt!)) {
      final remainingOtp = _activeChallengeExpiresAt!
          .difference(DateTime.now())
          .inSeconds
          .clamp(0, 300);
      _startOtpExpiryTimer(remainingOtp);
      final remainingCooldown = _lastSentAt != null
          ? (60 - DateTime.now().difference(_lastSentAt!).inSeconds).clamp(0, 60)
          : 0;
      _startResendTimer(remainingCooldown);
      setState(() {
        _step = TeacherCreationStep.otpVerification;
        _error = null;
        _selectedIndex = _otpController.text.length.clamp(0, 5);
        _otpController.selection =
            TextSelection.collapsed(offset: _otpController.text.length);
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _otpFocusNode.requestFocus();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
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
      final expiresAtStr = res['expiresAt']?.toString();
      if (expiresAtStr != null) {
        _activeChallengeExpiresAt = DateTime.tryParse(expiresAtStr);
      } else {
        _activeChallengeExpiresAt =
            DateTime.now().add(const Duration(minutes: 5));
      }

      final remainingCooldown = res['reused'] == true
          ? ((res['remainingCooldownSeconds'] as num?)?.toInt() ?? 60)
          : 60;
      _lastSentAt = DateTime.now();
      _startResendTimer(remainingCooldown);

      final remainingOtp =
          (res['remainingOtpSeconds'] as num?)?.toInt() ?? 300;
      _startOtpExpiryTimer(remainingOtp);

      if (res['failedAttempts'] != null) {
        _failedAttempts = (res['failedAttempts'] as num).toInt();
      }

      if (mounted) {
        setState(() {
          _step = TeacherCreationStep.otpVerification;
          _error = null;
          _selectedIndex = _otpController.text.length.clamp(0, 5);
          _otpController.selection =
              TextSelection.collapsed(offset: _otpController.text.length);
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
    } catch (error) {
      if (!mounted) return;
      _activeChallengeEmail = null;
      _activeChallengeExpiresAt = null;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtpCode() async {
    if (_resendSecondsRemaining > 0 || _isAnyBusy || _isLockedOut) return;

    setState(() {
      _isResending = true;
      _error = null;
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
        final expiresAtStr = res['expiresAt']?.toString();
        if (expiresAtStr != null) {
          _activeChallengeExpiresAt = DateTime.tryParse(expiresAtStr);
        } else {
          _activeChallengeExpiresAt =
              DateTime.now().add(const Duration(minutes: 5));
        }

        _lastSentAt = DateTime.now();
        _startResendTimer(60);
        _startOtpExpiryTimer(300);
        if (res['failedAttempts'] != null) {
          _failedAttempts = (res['failedAttempts'] as num).toInt();
        }
        setState(() {
          _otpController.clear();
          _selectedIndex = 0;
          // Attempts are preserved across resends! Do not reset _failedAttempts to 0.
          _error = null;
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
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtpAndCreate() async {
    if (_isAnyBusy || _isLockedOut) return;

    if (_otpSecondsRemaining <= 0) {
      setState(() => _error =
          'The verification code has expired (5 minutes passed). Please click Resend.');
      return;
    }

    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit verification code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final res = await AuthRepository.instance.verifyAdminTeacherAndCreate(
        email: _emailController.text.trim(),
        code: code,
      );
      _resendTimer?.cancel();
      _otpExpiryTimer?.cancel();
      if (mounted) {
        setState(() {
          _step = TeacherCreationStep.success;
          _createdEmail = res['email']?.toString() ?? _emailController.text.trim();
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (error is AdminTeacherException) {
        if (error.failedAttempts != null) {
          _failedAttempts = error.failedAttempts!;
        }
        setState(() {
          _error = error.message;
        });
      } else {
        setState(() {
          _error = _messageFor(error);
        });
      }
      if (!_isLockedOut) {
        _selectedIndex = 5;
        _otpController.selection = TextSelection.collapsed(offset: 6);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            FocusScope.of(context).requestFocus(_otpFocusNode);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _handleBackspaceKey() {
    if (_isLockedOut || _isAnyBusy || _otpSecondsRemaining <= 0) return;
    final text = _otpController.text;
    if (text.isEmpty) {
      if (_error != null) setState(() => _error = null);
      return;
    }

    final sel = _otpController.selection;
    if (!sel.isCollapsed && sel.start >= 0 && sel.end <= text.length) {
      final newText = text.substring(0, sel.start) + text.substring(sel.end);
      final nextIndex = sel.start.clamp(0, newText.length);
      _otpController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: nextIndex),
      );
      setState(() {
        _selectedIndex = nextIndex;
        _error = null;
      });
      return;
    }

    int deletePos = _selectedIndex;
    if (deletePos > 0 && deletePos <= text.length) {
      final newText =
          text.substring(0, deletePos - 1) + text.substring(deletePos);
      final nextIndex = (deletePos - 1).clamp(0, newText.length);
      _otpController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: nextIndex),
      );
      setState(() {
        _selectedIndex = nextIndex;
        _error = null;
      });
    } else if (deletePos == 0 && text.isNotEmpty) {
      final newText = text.substring(1);
      _otpController.value = TextEditingValue(
        text: newText,
        selection: const TextSelection.collapsed(offset: 0),
      );
      setState(() {
        _selectedIndex = 0;
        _error = null;
      });
    } else {
      final newText = text.substring(0, text.length - 1);
      final nextIndex = newText.length;
      _otpController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: nextIndex),
      );
      setState(() {
        _selectedIndex = nextIndex;
        _error = null;
      });
    }
  }

  void _onDigitBoxTapped(int index) {
    if (_isLockedOut || _isAnyBusy || _otpSecondsRemaining <= 0) return;
    _otpFocusNode.requestFocus();
    final text = _otpController.text;
    setState(() {
      _error = null;
      if (index < text.length) {
        _selectedIndex = index;
        _otpController.selection = TextSelection(
          baseOffset: index,
          extentOffset: index + 1,
        );
      } else {
        _selectedIndex = text.length.clamp(0, 5);
        _otpController.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
    });
  }

  Widget _buildOtpDigitBoxes(ThemeData theme, bool isDark) {
    final hasError = _error != null;
    final currentLength = _otpController.text.length;
    final isFocused = _otpFocusNode.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Invisible input field that catches keyboard text and system paste
            Positioned.fill(
              child: Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  autofocus: true,
                  enabled: !_isLockedOut &&
                      !_isAnyBusy &&
                      _otpSecondsRemaining > 0,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (!_isLockedOut) _error = null;
                      _selectedIndex = val.length.clamp(0, 5);
                    });
                    if (val.length == 6 &&
                        !_isLockedOut &&
                        !_isAnyBusy &&
                        _otpSecondsRemaining > 0) {
                      _verifyOtpAndCreate();
                    }
                  },
                ),
              ),
            ),

            // Visual 6 separated digit boxes with proper focus, cursor & selection indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < currentLength;
                final digit = isFilled ? _otpController.text[index] : '';

                final isSelected = isFocused && (_selectedIndex == index);
                final isNextEmpty = isFocused &&
                    (index == currentLength && currentLength < 6) &&
                    (_selectedIndex >= currentLength);
                final isActive = (isSelected || isNextEmpty) &&
                    !_isLockedOut &&
                    _otpSecondsRemaining > 0;

                Color borderColor;
                double borderWidth = 1.0;
                Color boxBg;
                List<BoxShadow>? shadows;

                if (hasError) {
                  borderColor = Colors.red.shade500;
                  borderWidth = isActive ? 2.0 : 1.6;
                  boxBg = Colors.red.withValues(alpha: isDark ? 0.12 : 0.04);
                  if (isActive) {
                    shadows = [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.18),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ];
                  }
                } else if (isActive) {
                  borderColor = theme.colorScheme.primary;
                  borderWidth = 2.2;
                  boxBg = theme.colorScheme.primary
                      .withValues(alpha: isDark ? 0.14 : 0.06);
                  shadows = [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ];
                } else if (isFilled) {
                  borderColor =
                      isDark ? Colors.white38 : const Color(0xFF94A3B8);
                  borderWidth = 1.4;
                  boxBg = isDark ? const Color(0xFF1E293B) : Colors.white;
                } else {
                  borderColor =
                      isDark ? Colors.white12 : const Color(0xFFCBD5E1);
                  borderWidth = 1.0;
                  boxBg = isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                      : const Color(0xFFF8FAFC);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onDigitBoxTapped(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 48,
                    height: 58,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: boxBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                      boxShadow: shadows,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (digit.isNotEmpty)
                          Text(
                            digit,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: hasError
                                  ? Colors.red.shade600
                                  : theme.colorScheme.onSurface,
                            ),
                          )
                        else if (isActive)
                          FadeTransition(
                            opacity: _effectiveCursorBlinkController,
                            child: Container(
                              width: 2.2,
                              height: 24,
                              decoration: BoxDecoration(
                                color: hasError
                                    ? Colors.red.shade600
                                    : theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),

                        if (isFilled && isActive && !hasError)
                          Positioned(
                            bottom: 6,
                            child: Container(
                              width: 18,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),

        // Clear code action button
        if (_otpController.text.isNotEmpty &&
            !_isLockedOut &&
            !_isAnyBusy &&
            _otpSecondsRemaining > 0) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _otpController.clear();
                  _selectedIndex = 0;
                  _error = null;
                });
                _otpFocusNode.requestFocus();
              },
              icon: Icon(
                LucideIcons.x,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              label: Text(
                'Clear code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _messageFor(Object error) {
    if (error is AdminTeacherException) {
      return error.message;
    }
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

    return PopScope(
      canPop: !_isAnyBusy,
      child: Dialog(
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
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: SingleChildScrollView(
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
                        errorBuilder: (_, _, _) => const Icon(
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
                  Form(
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
                                    _buildFieldLabel('Middle Initial (Optional)', theme),
                                    TextFormField(
                                      controller: _middleNameController,
                                      textCapitalization: TextCapitalization.characters,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        theme,
                                        hintText: 'e.g. H.',
                                        isDark: isDark,
                                      ),
                                      validator:
                                          AppValidators.validateMiddleInitial,
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
                            inputFormatters: AppValidators.emailFormatters,
                            autovalidateMode: _submitted
                                ? AutovalidateMode.onUserInteraction
                                : AutovalidateMode.onUserInteraction,
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
                    )

              // --- STEP 2: VERIFY OTP ---
              else if (_step == TeacherCreationStep.otpVerification)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Verification code sent banner (without timer)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
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
                                const SizedBox(height: 3),
                                Text(
                                  'Check the 6-digit code sent to ${_emailController.text.trim()}. (Valid for 5 minutes)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Timer badge placed directly above the 6-digit input boxes
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _otpSecondsRemaining <= 60
                            ? Colors.red.withValues(alpha: isDark ? 0.15 : 0.08)
                            : theme.colorScheme.primary
                                .withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _otpSecondsRemaining <= 60
                              ? Colors.red.shade400
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 14,
                            color: _otpSecondsRemaining <= 60
                                ? Colors.red.shade600
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _otpSecondsRemaining > 0
                                ? 'Code expires in ${_formatOtpTimer(_otpSecondsRemaining)}'
                                : 'Code expired (5 minutes passed)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: _otpSecondsRemaining <= 60
                                  ? (isDark
                                      ? Colors.red.shade300
                                      : Colors.red.shade700)
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. 6-digit OTP input boxes with active cursor & selection indicators
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

              // --- STEP 3: SUCCESS CONFIRMATION ---
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Lottie.asset(
                              'assets/animations/success_check.json',
                              repeat: false,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Teacher Account Created Successfully!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'The new teacher account has been successfully created and registered. An automated welcome email has been sent to ${_createdEmail ?? _emailController.text.trim()}.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.shieldCheck,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Teacher will be prompted to set their new password upon first login.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      onPressed: _isAnyBusy ? null : () => Navigator.pop(context),
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
                      onPressed: _isAnyBusy ? null : _sendOtpCode,
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
                      onPressed: _isAnyBusy
                          ? null
                          : () {
                              setState(() {
                                _step = TeacherCreationStep.details;
                                _error = null;
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
                        OutlinedButton(
                          onPressed: (_isAnyBusy ||
                                  _resendSecondsRemaining > 0 ||
                                  _isLockedOut)
                              ? null
                              : _resendOtpCode,
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
                          child: _isResending
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LoadingAnimationWidget.staggeredDotsWave(
                                      color: theme.colorScheme.primary,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Resending...'),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.refreshCw, size: 14),
                                    const SizedBox(width: 6),
                                    Text(_resendSecondsRemaining > 0
                                        ? 'Resend (${_resendSecondsRemaining}s)'
                                        : 'Resend'),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: (_isAnyBusy ||
                                  _isLockedOut ||
                                  _otpSecondsRemaining <= 0)
                              ? null
                              : _verifyOtpAndCreate,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isVerifying
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
                Center(
                  child: SizedBox(
                    width: 180,
                    child: FilledButton.icon(
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
