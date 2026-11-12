import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/core/services/rate_limit_service.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/features/auth/widgets/auth_responsive_scaffold.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _hasSubmitted = false;
  bool _hasShownMaintenanceDialogOnLoad = false;
  Timer? _lockoutTimer;
  Duration? _lockoutRemaining;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool get _isRateLimited => _lockoutRemaining != null;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleEmailChanged);
    _passwordController.addListener(_handlePasswordChanged);

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _healPasswordSelection();
      }
    });

    // Load Remember Me state and prefill saved email if remembered
    _rememberMe = LocalStorageService.isRememberMe;
    if (_rememberMe && LocalStorageService.savedEmail != null) {
      _emailController.text = LocalStorageService.savedEmail!;
    }

    // Always synchronize browser URL to /login when rendering LoginScreen
    updateBrowserUrl(AppRoutes.login);
    LocalStorageService.saveLastActiveRoute(AppRoutes.login);

    // Fast Login / Cache Check & Route User + Rate Limit Status Check
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final devStatus = await RateLimitService.instance.checkStatus(
          feature: 'login_device',
          targetIdentifier: 'device_only',
          maxAttempts: 10,
        );
        if (devStatus.isLocked && mounted) {
          _beginLockoutCountdown(Duration(seconds: devStatus.remainingSeconds));
          AppModals.showErrorDialog(
            context: context,
            title: 'Device Locked',
            message:
                'Device temporarily locked due to multiple failed login attempts. Try again in ${devStatus.formattedCountdown}.',
          );
          return;
        }

        final savedEmail = _emailController.text.trim().toLowerCase();
        if (savedEmail.isNotEmpty) {
          final accStatus = await RateLimitService.instance.checkStatus(
            feature: 'login_account',
            targetIdentifier: savedEmail,
            maxAttempts: 5,
          );
          if (accStatus.isLocked && mounted) {
            _beginLockoutCountdown(
              Duration(seconds: accStatus.remainingSeconds),
            );
            AppModals.showErrorDialog(
              context: context,
              title: 'Account Locked',
              message:
                  'Account temporarily locked due to multiple failed login attempts. Try again in ${accStatus.formattedCountdown}.',
            );
            return;
          }
        }
      } catch (_) {}

      if (!mounted) return;

      // 1. Check if user arrived via forced maintenance logout
      final args = ModalRoute.of(context)?.settings.arguments;
      final argReason = args is Map ? args['logout_reason']?.toString() : null;
      final wasForcedLogout =
          argReason == 'maintenance_forced' ||
          LocalStorageService.isMaintenanceForcedLogout;

      if (wasForcedLogout) {
        await LocalStorageService.saveMaintenanceForcedLogout(false);
        if (mounted) {
          _showMaintenanceDialog(isForcedLogout: true);
        }
        return;
      }

      if (argReason == 'inactivity') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AppTopToast.show(
              context,
              message:
                  'You were automatically logged out due to 30 minutes of inactivity.',
              type: AppToastType.warning,
              duration: const Duration(seconds: 4),
            );
          }
        });
      }

      // 2. Sync latest maintenance state into local cache on LoginScreen mount
      bool isMaintenance = LocalStorageService.isMaintenanceMode;
      try {
        final settings = await AdminRepository.instance.getSystemSettings();
        isMaintenance = settings.isMaintenanceMode;
      } catch (_) {}

      final cachedUser = await AuthRepository.instance.restoreSession();
      if (cachedUser != null && mounted) {
        // Guard against race conditions: If the user has already submitted a login or typed
        // a different email, do NOT hijack the screen with the background auto-restored session.
        if (_hasSubmitted || _isLoading) return;
        final currentEnteredEmail = _emailController.text.trim().toLowerCase();
        if (currentEnteredEmail.isNotEmpty &&
            cachedUser.email.trim().toLowerCase() != currentEnteredEmail) {
          return;
        }

        if (cachedUser.role != UserRole.admin && isMaintenance) {
          await AuthRepository.instance.logout('maintenance_forced');
          if (mounted) {
            _showMaintenanceDialog(isForcedLogout: true);
          }
          return;
        }
        _routeUser(cachedUser);
        return;
      }

      // 3. If no active session, and maintenance is active, pop up modal on arrival
      if (isMaintenance && mounted && !_hasShownMaintenanceDialogOnLoad) {
        _hasShownMaintenanceDialogOnLoad = true;
        _showMaintenanceDialog(isForcedLogout: false);
      }
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleEmailChanged);
    _passwordController.removeListener(_handlePasswordChanged);
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleEmailChanged() {}

  void _healPasswordSelection() {
    final text = _passwordController.text;
    final sel = _passwordController.selection;
    if (!sel.isValid ||
        sel.start < 0 ||
        sel.end < 0 ||
        sel.start > text.length ||
        sel.end > text.length) {
      _passwordController.selection =
          TextSelection.collapsed(offset: text.length);
    }
  }

  void _restorePasswordFocusAfterDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _passwordFocusNode.requestFocus();
      final len = _passwordController.text.length;
      _passwordController.selection = TextSelection.collapsed(offset: len);
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _passwordFocusNode.hasFocus) {
          final curLen = _passwordController.text.length;
          final sel = _passwordController.selection;
          if (sel.isValid && sel.start != sel.end) {
            _passwordController.selection =
                TextSelection.collapsed(offset: curLen);
          }
        }
      });
    });
  }

  void _handlePasswordFieldTap() {
    _healPasswordSelection();
    if (!_passwordFocusNode.hasFocus) {
      _passwordFocusNode.requestFocus();
    } else {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  void _handlePasswordChanged() {
    if (_passwordFocusNode.hasFocus) {
      _healPasswordSelection();
    }
  }

  void _beginLockoutCountdown(Duration remaining) {
    _lockoutTimer?.cancel();
    final endTime = DateTime.now().add(remaining);
    setState(() => _lockoutRemaining = remaining);
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      if (now.isAfter(endTime)) {
        timer.cancel();
        setState(() => _lockoutRemaining = null);
        return;
      }
      setState(() => _lockoutRemaining = endTime.difference(now));
    });
  }

  String _formatLockoutRemaining(Duration remaining) {
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleLogin() async {
    setState(() => _hasSubmitted = true);
    if (_isRateLimited || _isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    // Instant UI feedback: set loading immediately with 0ms latency
    setState(() => _isLoading = true);

    final rawEmail = _emailController.text.trim();
    final emailInput = rawEmail.toLowerCase();

    // System Maintenance Gatekeeping — PRIORITY #1 VALIDATION (Online & Offline)
    try {
      final settings = await AdminRepository.instance.getSystemSettings();
      final isMaintActive =
          settings.isMaintenanceMode || LocalStorageService.isMaintenanceMode;
      if (isMaintActive) {
        bool isAdmin = false;
        try {
          final userCheck = await Supabase.instance.client
              .from('users')
              .select('role')
              .ilike('email', emailInput)
              .maybeSingle()
              .timeout(const Duration(seconds: 3));
          if (userCheck != null && userCheck['role'] == 'admin') {
            isAdmin = true;
          }
        } catch (_) {
          final cached = LocalStorageService.getCachedUser();
          if (cached != null &&
              cached.email.toLowerCase() == emailInput &&
              cached.role == UserRole.admin) {
            isAdmin = true;
          }
        }

        if (!isAdmin) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _passwordController.clear();
          _passwordFocusNode.unfocus();
          _showMaintenanceDialog();
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    try {
      final user = await AuthRepository.instance.authenticate(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Save Remember Me state (email only, never plaintext password) and trigger browser autofill
      if (user != null) {
        final email = _emailController.text.trim();
        final isFirstLogin =
            user.status == AccountStatus.pendingFirstLogin ||
            user.status == AccountStatus.pending;
        // Only commit the autofill context on a successful normal login
        // (screen is about to be replaced, so no DOM input is left detached).
        if (!isFirstLogin) {
          TextInput.finishAutofillContext(shouldSave: true);
        }
        await LocalStorageService.saveRememberMe(_rememberMe, email);
        if (!mounted) return;
      }

      if (user == null) {
        setState(() => _isLoading = false);

        if (_isRateLimited) return;

        AppModals.showErrorDialog(
          context: context,
          title: 'Authentication Failed',
          message: 'Invalid email or password. Please check your credentials.',
          onConfirm: _restorePasswordFocusAfterDialog,
        ).whenComplete(_restorePasswordFocusAfterDialog);
        return;
      }

      await RateLimitService.instance.clearRateLimit(
        feature: 'login_account',
        targetIdentifier: emailInput,
      );
      await RateLimitService.instance.clearRateLimit(
        feature: 'login_device',
        targetIdentifier: 'device_only',
      );
      _lockoutTimer?.cancel();
      _lockoutRemaining = null;

      _routeUser(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (e is LoginAttemptException) {
        if (e.isMaintenanceBlocked) {
          _passwordController.clear();
          _passwordFocusNode.unfocus();
          _showMaintenanceDialog();
          return;
        }
        if (e.providerRateLimited) {
          final seconds = e.retryAfterSeconds ?? 300;
          _beginLockoutCountdown(Duration(seconds: seconds));
          AppModals.showErrorDialog(
            context: context,
            title: 'Too Many Attempts',
            message: e.message,
          );
          return;
        }
        if (e.invalidCredentials) {
          if (_isRateLimited) return;
          AppModals.showErrorDialog(
            context: context,
            title: 'Authentication Failed',
            message: e.message,
            onConfirm: _restorePasswordFocusAfterDialog,
          ).whenComplete(_restorePasswordFocusAfterDialog);
          return;
        }
      }
      AppModals.showErrorDialog(
        context: context,
        title: 'Login Error',
        message: e.toString().replaceAll('Exception: ', ''),
        onConfirm: _restorePasswordFocusAfterDialog,
      ).whenComplete(_restorePasswordFocusAfterDialog);
    }
  }

  void _showMaintenanceDialog({
    String? customMessage,
    bool isForcedLogout = false,
  }) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.wrench,
                      color: Color(0xFFD97706),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'MAINTENANCE ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'System Under Maintenance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  customMessage ??
                      (isForcedLogout
                          ? 'The system has entered scheduled maintenance mode. You have been safely logged out of your session.\n\nTeacher, Student, and Parent accounts cannot log in to their accounts at this time. Please try again later.'
                          : 'ClassRealm is currently undergoing scheduled system maintenance.\n\nTeacher, Student, and Parent accounts cannot log in to their accounts at this time. Please try again later.'),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Understood',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _routeUser(UserModel user) {
    if (user.role != UserRole.admin && LocalStorageService.isMaintenanceMode) {
      unawaited(AuthRepository.instance.logout());
      setState(() => _isLoading = false);
      _showMaintenanceDialog();
      return;
    }

    if (user.status == AccountStatus.pendingFirstLogin ||
        user.status == AccountStatus.pending) {
      // Must remain in default light theme for first-login and password setup
      AppTheme.themeModeNotifier.value = ThemeMode.light;
      if (user.role == UserRole.parent) {
        SyncCoordinator.instance.syncParentData(user.id);
      }
      final firstLoginRoute = AppRoutes.getFirstLoginRouteForRole(user.role);
      updateBrowserUrl(firstLoginRoute);
      Navigator.pushNamedAndRemoveUntil(
        context,
        firstLoginRoute,
        (route) => false,
      );
      return;
    }

    if (user.status == AccountStatus.deactivated ||
        user.status == AccountStatus.archived) {
      setState(() => _isLoading = false);
      AppModals.showErrorDialog(
        context: context,
        title: user.status == AccountStatus.archived
            ? 'Account Archived'
            : 'Account Deactivated',
        message: user.status == AccountStatus.archived
            ? 'Your account has been deactivated by ClassRealm Admin.'
            : 'Your account has been deactivated.',
      );
      return;
    }

    if (user.status == AccountStatus.rejected) {
      unawaited(AuthRepository.instance.logout());
      setState(() => _isLoading = false);
      AppModals.showErrorDialog(
        context: context,
        title: 'Account Unavailable',
        message: 'This account cannot access ClassRealm. Please contact the school administrator.',
      );
      return;
    }

    // Now that the user enters their authenticated dashboard, apply their theme preference
    final isUserDark = LocalStorageService.isUserDarkMode(
      user.id,
      email: user.email,
    );
    AppTheme.themeModeNotifier.value = isUserDark
        ? ThemeMode.dark
        : ThemeMode.light;

    // Mark session warm and persist UserModel snapshot for instant zero-logout F5 reload
    markWarmSession();
    LocalStorageService.saveUser(user);

    // Fresh login: Always direct user to their primary role Dashboard (Tab 0)
    LocalStorageService.saveActiveDashboardTab('admin', 0);
    LocalStorageService.saveActiveDashboardTab('teacher', 0);
    LocalStorageService.saveActiveDashboardTab('student', 0);
    LocalStorageService.saveActiveDashboardTab('parent', 0);
    final dashboardRoute = AppRoutes.getDashboardRouteForRole(user.role);
    LocalStorageService.saveLastActiveRoute(dashboardRoute);
    updateBrowserUrl(dashboardRoute);

    switch (user.role) {
      case UserRole.admin:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.adminDashboard,
          (route) => false,
        );
        break;
      case UserRole.teacher:
        SyncCoordinator.instance.syncTeacherData(user.id);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.teacherDashboard,
          (route) => false,
        );
        break;
      case UserRole.student:
        SyncCoordinator.instance.syncStudentData(user.id);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.studentHome,
          (route) => false,
        );
        break;
      case UserRole.parent:
        SyncCoordinator.instance.syncParentData(user.id);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.parentHome,
          (route) => false,
        );
        break;
    }
  }

  // Developer Quick Login removed based on user request.
  @override
  Widget build(BuildContext context) {
    return AuthResponsiveScaffold(
      cardTitle: 'Welcome to ClassRealm',
      cardSubtitle: 'Eduardo Barretto Senior Integrated School',
      formChild: _buildLoginForm(context),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.commit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section 1 (120ms): Email & Password fields
            StaggeredEntrance(
              index: 2,
              delay: const Duration(milliseconds: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    inputFormatters: AppValidators.emailFormatters,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: _hasSubmitted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                    validator: AppValidators.validateEmail,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: AuthResponsiveScaffold.inputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(
                        LucideIcons.mail,
                        color: Color(0xFF475569),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                        return KeyEventResult.ignored;
                      }
                      final text = _passwordController.text;
                      final sel = _passwordController.selection;
                      final bool hasRange = sel.isValid &&
                          sel.start >= 0 &&
                          sel.end <= text.length &&
                          sel.start != sel.end;
                      final int offset =
                          (sel.isValid && sel.end >= 0 && sel.end <= text.length)
                              ? sel.end
                              : text.length;

                      // Support Ctrl+A / Cmd+A to highlight all text
                      if ((HardwareKeyboard.instance.isControlPressed ||
                              HardwareKeyboard.instance.isMetaPressed) &&
                          event.logicalKey == LogicalKeyboardKey.keyA) {
                        _passwordController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: text.length,
                        );
                        return KeyEventResult.handled;
                      }

                      if (event.logicalKey == LogicalKeyboardKey.backspace) {
                        if (hasRange) {
                          final newText = text.substring(0, sel.start) +
                              text.substring(sel.end);
                          _passwordController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: sel.start,
                            ),
                          );
                        } else if (text.isNotEmpty && offset > 0) {
                          final newText = text.substring(0, offset - 1) +
                              text.substring(offset);
                          final newOffset = offset - 1;
                          _passwordController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: newOffset,
                            ),
                          );
                        }
                        return KeyEventResult.handled;
                      }

                      if (event.logicalKey == LogicalKeyboardKey.delete) {
                        if (hasRange) {
                          final newText = text.substring(0, sel.start) +
                              text.substring(sel.end);
                          _passwordController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: sel.start,
                            ),
                          );
                        } else if (text.isNotEmpty && offset < text.length) {
                          final newText = text.substring(0, offset) +
                              text.substring(offset + 1);
                          _passwordController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: offset,
                            ),
                          );
                        }
                        return KeyEventResult.handled;
                      }

                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        final newOffset = hasRange
                            ? sel.start
                            : (offset - 1).clamp(0, text.length);
                        _passwordController.selection =
                            TextSelection.collapsed(offset: newOffset);
                        return KeyEventResult.handled;
                      }

                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        final newOffset = hasRange
                            ? sel.end
                            : (offset + 1).clamp(0, text.length);
                        _passwordController.selection =
                            TextSelection.collapsed(offset: newOffset);
                        return KeyEventResult.handled;
                      }

                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                        if (event is KeyDownEvent &&
                            !_isLoading &&
                            !_isRateLimited) {
                          _handleLogin();
                        }
                        return KeyEventResult.handled;
                      }

                      final isModifierPressed =
                          HardwareKeyboard.instance.isControlPressed ||
                          HardwareKeyboard.instance.isMetaPressed ||
                          HardwareKeyboard.instance.isAltPressed;
                      final char = event.character;
                      if (!isModifierPressed &&
                          char != null &&
                          char.isNotEmpty &&
                          event.logicalKey != LogicalKeyboardKey.tab &&
                          event.logicalKey != LogicalKeyboardKey.escape &&
                          char.codeUnitAt(0) >= 32 &&
                          char.codeUnitAt(0) != 127) {
                        if (hasRange) {
                          final newText = text.substring(0, sel.start) +
                              char +
                              text.substring(sel.end);
                          final newOffset = sel.start + char.length;
                          _passwordController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: newOffset,
                            ),
                          );
                        } else if (text.length < 100) {
                          final newText = text.substring(0, offset) +
                              char +
                              text.substring(offset);
                          final newOffset = offset + char.length;
                          _passwordController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: newOffset,
                            ),
                          );
                        }
                        return KeyEventResult.handled;
                      }

                      return KeyEventResult.ignored;
                    },
                    child: TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      autofillHints: const [AutofillHints.password],
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      enableSuggestions: false,
                      autocorrect: false,
                      onTap: _handlePasswordFieldTap,
                      onFieldSubmitted: (_) {
                        if (!_isLoading && !_isRateLimited) {
                          _handleLogin();
                        }
                      },
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(100),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                      decoration: AuthResponsiveScaffold.inputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(
                          LucideIcons.lock,
                          color: Color(0xFF475569),
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            color: const Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              _passwordFocusNode.requestFocus();
                              final len = _passwordController.text.length;
                              _passwordController.selection =
                                  TextSelection.collapsed(offset: len);
                              SystemChannels.textInput.invokeMethod<void>(
                                'TextInput.show',
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section 2 (180ms): Remember Me, Forgot Password, LOGIN Button
            StaggeredEntrance(
              index: 3,
              delay: const Duration(milliseconds: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (val) =>
                                  setState(() => _rememberMe = val ?? false),
                              activeColor: const Color(0xFF487898),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: const BorderSide(
                                color: Color(0xFF334155),
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember me',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.forgotPassword,
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF487898),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  AuthResponsiveScaffold.primaryButton(
                    label: _isRateLimited && _lockoutRemaining != null
                        ? 'TRY AGAIN IN ${_formatLockoutRemaining(_lockoutRemaining!)}'
                        : 'LOGIN',
                    onPressed: _isLoading || _isRateLimited
                        ? null
                        : _handleLogin,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Terms of Service / Privacy Policy footer
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'By logging in, you agree to our ',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
                InkWell(
                  onTap: _showTermsDialog,
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF487898),
                    ),
                  ),
                ),
                const Text(
                  ' and ',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
                InkWell(
                  onTap: _showPrivacyDialog,
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF487898),
                    ),
                  ),
                ),
                const Text(
                  '.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTermsDialog() {
    return LegalDocumentsModal.showTermsOfService(context);
  }

  Future<void> _showPrivacyDialog() {
    return LegalDocumentsModal.showPrivacyPolicy(context);
  }
}
