import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/common/app_modals.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.student; // Default tab

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final user = MockDatabase.instance.authenticate(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user == null) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Authentication Failed',
          message: 'Invalid username or password. Please make sure you are using the correct credentials for the selected role.',
        );
        return;
      }

      // If they logged in with credentials that match a different role than selected,
      // we can gracefully route them anyway to make the demo smooth, but let's notify them or just proceed!
      if (user.status == AccountStatus.pending) {
        Navigator.pushNamed(context, AppRoutes.pendingAccount);
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
    });
  }

  void _fillDemoCredentials(UserRole role) {
    setState(() {
      _selectedRole = role;
    });
    switch (role) {
      case UserRole.admin:
        _usernameController.text = 'admin';
        _passwordController.text = 'admin123';
        break;
      case UserRole.teacher:
        _usernameController.text = 'teacher';
        _passwordController.text = 'teacher123';
        break;
      case UserRole.student:
        _usernameController.text = 'student';
        _passwordController.text = 'student123';
        break;
      case UserRole.parent:
        _usernameController.text = 'parent';
        _passwordController.text = 'parent123';
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Academic Watermark Layer
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A), // Dark Midnight Blue/Grey
                  Color(0xFF1E3A8A), // Deep Royal Blue
                  Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Glowing architectural background design lines/watermark (Simulating the logo overlay)
          Positioned(
            left: isDesktop ? -150 : -100,
            bottom: isDesktop ? -150 : -100,
            child: Opacity(
              opacity: 0.05,
              child: Icon(
                Icons.account_balance,
                size: isDesktop ? 600 : 400,
                color: Colors.white,
              ),
            ),
          ),

          Positioned(
            right: -100,
            top: -100,
            child: Opacity(
              opacity: 0.03,
              child: Icon(
                Icons.school,
                size: 500,
                color: Colors.white,
              ),
            ),
          ),

          // Main Responsive Content
          isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        ],
      ),
    );
  }

  // --- DESKTOP SPLIT LAYOUT ---
  Widget _buildDesktopLayout() {
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
                // Academic Shield / Logo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
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
                          'LAGUNA INSTITUTION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 1.5,
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
                  'Integrated Senior High School Attendance, Activity and Requirement Tracking, Teacher Lesson Planning, and Learning Materials Management System',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Integrity Towards Academic Excellence',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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
              child: _buildLoginCard(false),
            ),
          ),
        ),
      ],
    );
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileLayout() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CLASSREALM',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'LAGUNA INSTITUTION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Integrity Towards Academic Excellence',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildLoginCard(true),
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE LOGIN FORM CARD ---
  Widget _buildLoginCard(bool isMobile) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: EdgeInsets.all(isMobile ? 24 : 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile
            ? const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              )
            : BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Welcome to ClassRealm',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Laguna Institutional Portal Management System',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Role indicator tab (Matches the "COLLEGE STUDENT" layout in the screenshot)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1.5),
                ),
              ),
              child: Text(
                _selectedRole.name.toUpperCase() == 'ADMIN'
                    ? 'SYSTEM ADMINISTRATOR'
                    : _selectedRole.name.toUpperCase() == 'TEACHER'
                        ? 'FACULTY EDUCATOR'
                        : _selectedRole.name.toUpperCase() == 'PARENT'
                            ? 'PARENT / GUARDIAN'
                            : 'SENIOR HIGH STUDENT',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Username input
            TextFormField(
              controller: _usernameController,
              validator: (v) => v == null || v.isEmpty ? 'Username is required' : null,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFEFF6FF), // Soft light-blue/indigo tint
                prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                hintText: 'Enter username or student ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password input
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFEFF6FF), // Soft light-blue/indigo tint
                prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                hintText: 'Enter password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Login Button (Large solid theme color matching screenshot)
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'LOGIN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Demo Account Selection Row (Acts like the segment selection)
            const Text(
              'Select Realm Role to Auto-Fill:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRoleChip(UserRole.student, 'Student'),
                  const SizedBox(width: 6),
                  _buildRoleChip(UserRole.teacher, 'Teacher'),
                  const SizedBox(width: 6),
                  _buildRoleChip(UserRole.parent, 'Parent'),
                  const SizedBox(width: 6),
                  _buildRoleChip(UserRole.admin, 'Admin'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bottom Recovery links matching the image layout
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  child: const Text(
                    'Recover My Account',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                  child: const Text(
                    'Register Teacher?',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(UserRole role, String label) {
    final isSelected = _selectedRole == role;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (_) => _fillDemoCredentials(role),
    );
  }
}
