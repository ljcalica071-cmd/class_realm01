import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/features/auth/services/login_attempt_limiter.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

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

    // Ensure theme is reset to light mode when logging out / viewing login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppTheme.themeModeNotifier.value = ThemeMode.light;
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

  void _handleLogin() {
    if (_isRateLimited || _isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_isMockLoginEmail) {
      setState(() => _isLoading = true);
      Future.delayed(const Duration(milliseconds: 1500), () async {
        if (!mounted) return;
        
        final email = _emailController.text.trim().toLowerCase();
        await AuthRepository.instance.authenticate(email, 'mockpassword');
        
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        if (email == 'student') {
          Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        } else if (email == 'parent') {
          Navigator.pushReplacementNamed(context, AppRoutes.parentHome);
        } else if (email == 'teacher') {
          Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
        }
      });
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;

      try {
        final user = await AuthRepository.instance.authenticate(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        // Save Remember Me state upon successful login
        if (user != null) {
          await LocalStorageService.saveRememberMe(_rememberMe, _emailController.text.trim());
        }

        if (user == null) {
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

        if (user.status == AccountStatus.pending) {
          AppModals.showErrorDialog(
            context: context,
            title: 'Account Pending',
            message: 'Your account registration is currently being processed and is waiting for the administrator\'s approval. Please check your email later for updates.',
          );
          return;
        }

        if (user.status == AccountStatus.deactivated ||
            user.status == AccountStatus.archived) {
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
          AppModals.showErrorDialog(
            context: context,
            title: 'Account Rejected',
            message: 'Your account registration was declined by the administrator. Please create a new account or contact the school office.',
          );
          return;
        }

        if (user.status == AccountStatus.pendingFirstLogin) {
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

        switch (user.role) {
          case UserRole.admin:
            Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
            break;
          case UserRole.teacher:
            Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
            break;
          case UserRole.student:
            Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
            break;
          case UserRole.parent:
            Navigator.pushReplacementNamed(context, AppRoutes.parentHome);
            break;
        }
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
    });
  }

  Widget _buildDemoQuickLogin() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'DEVELOPER QUICK LOGIN',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                label: const Text('Admin'),
                avatar: const Icon(LucideIcons.shield, size: 14),
                onPressed: () {
                  _emailController.text = 'ljcalica071@gmail.com';
                  _passwordController.text = 'Admin123';
                  _handleLogin();
                },
              ),
              ActionChip(
                label: const Text('Teacher'),
                avatar: const Icon(LucideIcons.graduationCap, size: 14),
                onPressed: () {
                  _emailController.text = 'ljcalica317@gmail.com';
                  _passwordController.text = 'Uzumaki123';
                  _handleLogin();
                },
              ),
              ActionChip(
                label: const Text('Student (Mock)'),
                avatar: const Icon(LucideIcons.user, size: 14),
                onPressed: () {
                  _emailController.text = 'student';
                  _passwordController.text = 'password';
                  _handleLogin();
                },
              ),
              ActionChip(
                label: const Text('Parent (Mock)'),
                avatar: const Icon(LucideIcons.users, size: 14),
                onPressed: () {
                  _emailController.text = 'parent';
                  _passwordController.text = 'password';
                  _handleLogin();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/auth/school.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.black87 : Colors.black54,
                  BlendMode.darken,
                ),
              ),
            ),
            child: isDesktop
                ? _buildDesktopLayout(theme)
                : _buildMobileLayout(theme),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingAnimationWidget.staggeredDotsWave(
                      color: theme.colorScheme.primary,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Authenticating...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to ClassRealm',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Eduardo Barretto Senior Integrated School',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Email input
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                },
                validator: (v) =>
                    v == null || v.isEmpty ? 'Email is required' : null,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  prefixIcon: Icon(
                    LucideIcons.mail,
                    color: theme.colorScheme.primary,
                  ),
                  hintText: 'Email',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isLoading && !_isRateLimited) {
                    _handleLogin();
                  }
                },
                obscureText: _obscurePassword,
                style: TextStyle(color: theme.colorScheme.onSurface),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  prefixIcon: Icon(
                    LucideIcons.lock,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  hintText: 'Password',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                      // Navigate to forgot password
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

              _buildDemoQuickLogin(),

              if (!isMobile) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'New teacher in the system? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Register here',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
