import 'dart:async';
import 'dart:ui';

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
        final text = _passwordController.text;
        if (!_passwordController.selection.isValid ||
            _passwordController.selection.start == -1) {
          _passwordController.selection =
              TextSelection.collapsed(offset: text.length);
        }
      }
    });

    // Load Remember Me state and prefill saved email if remembered
    _rememberMe = LocalStorageService.isRememberMe;
    if (_rememberMe && LocalStorageService.savedEmail != null) {
      _emailController.text = LocalStorageService.savedEmail!;
    }

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
            _beginLockoutCountdown(Duration(seconds: accStatus.remainingSeconds));
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

      final cachedUser = await AuthRepository.instance.restoreSession();
      if (cachedUser != null && mounted) {
        _routeUser(cachedUser);
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

  void _handlePasswordChanged() {}

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
    if (_isRateLimited || _isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    // Instant UI feedback: set loading immediately with 0ms latency
    setState(() => _isLoading = true);

    final rawEmail = _emailController.text.trim();
    final emailInput = rawEmail.toLowerCase();

    // System Maintenance Gatekeeping (Edge Cases #1 & #5)
    try {
      final settings = await AdminRepository.instance.getSystemSettings();
      if (settings.isMaintenanceMode) {
        bool isAdmin = false;
        try {
          final userCheck = await Supabase.instance.client
              .from('users')
              .select('role')
              .eq('email', emailInput)
              .maybeSingle();
          if (userCheck != null && userCheck['role'] == 'admin') {
            isAdmin = true;
          }
        } catch (_) {}

        if (!isAdmin) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          TextInput.finishAutofillContext(shouldSave: false);
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
        TextInput.finishAutofillContext(shouldSave: true);
        await LocalStorageService.saveRememberMe(
          _rememberMe,
          email,
        );
        if (!mounted) return;
      }

      if (user == null) {
        setState(() => _isLoading = false);
        TextInput.finishAutofillContext(shouldSave: false);
        
        if (_isRateLimited) return;
        
        AppModals.showErrorDialog(
          context: context,
          title: 'Authentication Failed',
          message: 'Invalid email or password. Please check your credentials.',
          onConfirm: () {
            // Focus back to password without clearing it (User Friendly)
            final len = _passwordController.text.length;
            _passwordController.selection = TextSelection.collapsed(offset: len);
            _passwordFocusNode.requestFocus();
          }
        );
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
      TextInput.finishAutofillContext(shouldSave: false);
      
      if (e is LoginAttemptException) {
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
            onConfirm: () {
              final len = _passwordController.text.length;
              _passwordController.selection = TextSelection.collapsed(offset: len);
              _passwordFocusNode.requestFocus();
            }
          );
          return;
        }
      }
      AppModals.showErrorDialog(
        context: context,
        title: 'Login Error',
        message: e.toString().replaceAll('Exception: ', ''),
        onConfirm: () {
          final len = _passwordController.text.length;
          _passwordController.selection = TextSelection.collapsed(offset: len);
          _passwordFocusNode.requestFocus();
        }
      );
    }
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.build_circle_outlined, color: AppTheme.catRed, size: 28),
            SizedBox(width: 12),
            Text('System Maintenance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'The system is currently under maintenance. You cannot log into your account at this time. Please try again later.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _routeUser(UserModel user) {
    if (user.status == AccountStatus.pendingFirstLogin ||
        user.status == AccountStatus.pending) {
      // Must remain in default light theme for first-login and password setup
      AppTheme.themeModeNotifier.value = ThemeMode.light;
      if (user.role == UserRole.teacher) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.teacherFirstLogin,
          (route) => false,
        );
      } else if (user.role == UserRole.parent) {
        SyncCoordinator.instance.syncParentData(user.id);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.studentFirstLogin,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.studentFirstLogin,
          (route) => false,
        );
      }
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
    final isUserDark = LocalStorageService.isUserDarkMode(user.id, email: user.email);
    AppTheme.themeModeNotifier.value = isUserDark ? ThemeMode.dark : ThemeMode.light;

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
      onDisposeAction: AutofillContextAction.cancel,
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
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    inputFormatters: AppValidators.emailFormatters,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    enableSuggestions: false,
                    autocorrect: false,
                    onTap: () {
                      final text = _passwordController.text;
                      if (!_passwordController.selection.isValid ||
                          _passwordController.selection.start == -1) {
                        _passwordController.selection =
                            TextSelection.collapsed(offset: text.length);
                      }
                    },
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
                    inputFormatters: AppValidators.passwordFormatters,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Password is required';
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
                        onPressed: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                          final text = _passwordController.text;
                          _passwordController.selection =
                              TextSelection.collapsed(offset: text.length);
                        }),
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
                          Navigator.pushNamed(context, AppRoutes.forgotPassword);
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
                    onPressed: _isLoading || _isRateLimited ? null : _handleLogin,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Terms and Conditions / Privacy Policy footer
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'By logging in, you agree to our ',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                  ),
                ),
                InkWell(
                  onTap: _showTermsDialog,
                  child: const Text(
                    'Terms and Conditions',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF487898),
                    ),
                  ),
                ),
                const Text(
                  ' and ',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                  ),
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
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          'â€¢ Teachers: Responsible for accurate input of grades, assessments, and securing their authentication credentials.\n'
          'â€¢ Students: Must maintain academic integrity, provide accurate personal details, and ensure their RFID tags are only used by them.\n'
          'â€¢ Parents: Granted access strictly for monitoring their child\'s academic progress and attendance.',
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
      subtitle: 'RA 10173 - Data Privacy Act of 2012',
      content: [
        Text(
          'We protect your personal information in compliance with the Philippine Data Privacy Act of 2012 (RA 10173).',
          textAlign: TextAlign.justify,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        _buildSubSection(
          '1. Information We Collect',
          'â€¢ Personal Information: Names, Student IDs (LRN), Emails, Contact Numbers, Birthdays, and Gender.\n'
          'â€¢ Academic Data: Submissions, quiz/exam scores, calculated grades, and attendance records.\n'
          'â€¢ RFID & Hardware Data: Attendance scan records from RFID cards read by the ESP32 scanner.\n'
          'â€¢ Technical Data: Suspicious session events during assessments.',
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
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(dialogContext);
        final dialogWidth = (size.width - 40).clamp(320.0, 560.0);
        final dialogMaxHeight = size.height * 0.80;

        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(maxHeight: dialogMaxHeight),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F0F172A),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            tooltip: 'Close',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE2E8F0),
                    ),

                    // --- SCROLLABLE BODY ---
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: content,
                        ),
                      ),
                    ),

                    // --- SEPARATE FOOTER ACTION BAR ---
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE2E8F0),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSubSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
