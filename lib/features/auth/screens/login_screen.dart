import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/auth/services/login_attempt_limiter.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';

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
  final LoginAttemptLimiter _loginAttemptLimiter = LoginAttemptLimiter();
  Timer? _lockoutTimer;
  Duration? _lockoutRemaining;
  bool _wasMockLoginEmail = false;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool get _isMockLoginEmail {
    final email = _emailController.text.trim().toLowerCase();
    return email == 'student' || email == 'parent' || email == 'teacher';
  }

  bool get _isRateLimited => _lockoutRemaining != null && !_isMockLoginEmail;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleEmailChanged);
    
    // Load Remember Me state
    _rememberMe = LocalStorageService.isRememberMe;
    if (_rememberMe) {
      _emailController.text = LocalStorageService.savedEmail ?? '';
    }

    // Fast Login / Cache Check & Route User
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cachedUser = await AuthRepository.instance.restoreSession();
      if (cachedUser != null && mounted) {
        _routeUser(cachedUser);
      }
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleEmailChanged);
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleEmailChanged() {
    final isMockLoginEmail = _isMockLoginEmail;
    if (isMockLoginEmail == _wasMockLoginEmail) return;
    _wasMockLoginEmail = isMockLoginEmail;
    if (mounted) setState(() {});
  }

  void _recordFailedAttempt() {
    if (_isMockLoginEmail) return;
    final remaining = _loginAttemptLimiter.recordFailure(DateTime.now());
    if (remaining != null) _beginLockoutCountdown(remaining);
  }

  void _beginLockoutCountdown(Duration remaining) {
    _lockoutTimer?.cancel();
    setState(() => _lockoutRemaining = remaining);
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentRemaining = _loginAttemptLimiter.remainingAt(DateTime.now());
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (currentRemaining == null) {
        timer.cancel();
        setState(() => _lockoutRemaining = null);
        return;
      }
      setState(() => _lockoutRemaining = currentRemaining);
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

    if (_isMockLoginEmail) {
      setState(() => _isLoading = true);
      final email = _emailController.text.trim().toLowerCase();
      final user = await AuthRepository.instance.authenticate(email, 'mockpassword');
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (email == 'student') {
        if (user != null) {
          final isUserDark = LocalStorageService.isUserDarkMode(user.id, email: user.email);
          AppTheme.themeModeNotifier.value = isUserDark ? ThemeMode.dark : ThemeMode.light;
        }
        Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
      } else if (email == 'parent') {
        if (user != null) {
          final isUserDark = LocalStorageService.isUserDarkMode(user.id, email: user.email);
          AppTheme.themeModeNotifier.value = isUserDark ? ThemeMode.dark : ThemeMode.light;
        }
        Navigator.pushReplacementNamed(context, AppRoutes.parentHome);
      } else if (email == 'teacher') {
        if (user != null) {
          final isUserDark = LocalStorageService.isUserDarkMode(user.id, email: user.email);
          AppTheme.themeModeNotifier.value = isUserDark ? ThemeMode.dark : ThemeMode.light;
        }
        Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthRepository.instance.authenticate(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Save Remember Me state upon successful login
      if (user != null) {
        TextInput.finishAutofillContext();
        await LocalStorageService.saveRememberMe(_rememberMe, _emailController.text.trim());
        if (!mounted) return;
      }

      if (user == null) {
        setState(() => _isLoading = false);
        _recordFailedAttempt();
        if (_isRateLimited) return;
        AppModals.showErrorDialog(
          context: context,
          title: 'Authentication Failed',
          message:
              'Invalid email or password. Please check your credentials.',
        );
        return;
      }

      _loginAttemptLimiter.reset();
      _lockoutTimer?.cancel();
      _lockoutRemaining = null;

      _routeUser(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e is LoginAttemptException) {
        if (e.providerRateLimited) {
          _beginLockoutCountdown(
            _loginAttemptLimiter.startLockout(DateTime.now()),
          );
          return;
        }
        if (e.invalidCredentials) {
          _recordFailedAttempt();
          if (_isRateLimited) return;
          AppModals.showErrorDialog(
            context: context,
            title: 'Authentication Failed',
            message: e.message,
          );
          return;
        }
      }
      AppModals.showErrorDialog(
        context: context,
        title: 'Login Error',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void _routeUser(UserModel user) {
    if (user.status == AccountStatus.pendingFirstLogin ||
        user.status == AccountStatus.pending) {
      // Must remain in default light theme for first-login and password setup
      AppTheme.themeModeNotifier.value = ThemeMode.light;
      if (user.role == UserRole.teacher) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.teacherFirstLogin,
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.studentFirstLogin,
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

    switch (user.role) {
      case UserRole.admin:
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
        break;
      case UserRole.teacher:
        SyncCoordinator.instance.syncTeacherData(user.id);
        Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
        break;
      case UserRole.student:
        SyncCoordinator.instance.syncStudentData(user.id);
        Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        break;
      case UserRole.parent:
        SyncCoordinator.instance.syncParentData(user.id);
        Navigator.pushReplacementNamed(context, AppRoutes.parentHome);
        break;
    }
  }

  // Developer Quick Login removed based on user request.
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final size = MediaQuery.of(context).size;
          final isDesktop = size.width >= 900;
          final theme = Theme.of(context);

          return Scaffold(
            body: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/auth/school.jpg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black45,
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: isDesktop
                      ? _buildDesktopLayout(theme)
                      : _buildMobileLayout(theme),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- DESKTOP SPLIT LAYOUT ---
  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      children: [
        // Left Branding Column
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/branding/school_logo.png',
                      width: 64,
                      height: 64,
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLASSREALM',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'CALAMBA CITY, LAGUNA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  'One Realm for Every Learning Journey.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Integrated Senior High School Attendance, Activity and Requirement Tracking, Teacher Lesson Planning, and Learning Materials Management System.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Form Card Column
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildLoginCard(theme, false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileLayout(ThemeData theme) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/branding/school_logo.png',
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'CLASSREALM',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'One Realm for Every Learning Journey.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildLoginCard(theme, true),
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE LOGIN FORM CARD ---
  Widget _buildLoginCard(ThemeData theme, bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 24 : 36),
          child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome to ClassRealm',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Eduardo Barretto Senior Integrated School',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 24),

              // Email input
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                },
                validator: (v) =>
                    v == null || v.isEmpty ? 'Email is required' : null,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: Icon(
                    LucideIcons.mail,
                    color: theme.colorScheme.primary,
                  ),
                  hintText: 'Email',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password input
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isLoading && !_isRateLimited) {
                    _handleLogin();
                  }
                },
                obscureText: _obscurePassword,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: Icon(
                    LucideIcons.lock,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                      color: const Color(0xFF64748B),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  hintText: 'Password',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Remember Me & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (val) =>
                              setState(() => _rememberMe = val ?? false),
                          activeColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember me',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
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
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isRateLimited && _lockoutRemaining != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Too many failed attempts. Try again after 15 minutes.',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Login Button — full width within the card
              AppPrimaryButton(
                onPressed: _isLoading || _isRateLimited ? null : _handleLogin,
                isLoading: _isLoading,
                label: _isLoading
                    ? 'Authenticating...'
                    : (_isRateLimited && _lockoutRemaining != null
                          ? 'TRY AGAIN IN ${_formatLockoutRemaining(_lockoutRemaining!)}'
                          : 'LOGIN'),
                width: double.infinity,
                height: 48,
              ),

              const SizedBox.shrink(),

              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'By logging in, you agree to our ',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showTermsDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Terms and Conditions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    ' and ',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showPrivacyDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          '• Personal Information: Names, Student IDs (LRN), Emails, Contact Numbers, Birthdays, and Gender.\n'
          '• Academic Data: Submissions, quiz/exam scores, calculated grades, and attendance records.\n'
          '• RFID & Hardware Data: Attendance scan records from RFID cards read by the ESP32 scanner.\n'
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
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
