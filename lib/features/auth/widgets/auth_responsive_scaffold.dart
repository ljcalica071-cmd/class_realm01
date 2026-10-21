import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/features/auth/widgets/login_aesthetic_decorations.dart';

/// Unified, highly responsive auth layout scaffold shared across:
/// - LoginScreen
/// - ForgotPasswordScreen
/// - FirstLoginScreen
///
/// Features:
/// 1. School background with royal blue sky gradient overlay.
/// 2. Botanical lush leaves framing bottom corners.
/// 3. Floating 3D educational elements (Open Book with animated page-flipping,
///    Pencil, Closed Book, Graduation Cap with Cyan Glow Aura, fluttering papers)
///    anchored directly around the frosted glass card on both Web and Mobile.
/// 4. Adaptive desktop 2-column split, tablet, and mobile layouts.
class AuthResponsiveScaffold extends StatelessWidget {
  final String cardTitle;
  final String cardSubtitle;
  final Widget formChild;
  final Widget? cardTopLogo;
  final double cardMaxWidth;

  const AuthResponsiveScaffold({
    super.key,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.formChild,
    this.cardTopLogo,
    this.cardMaxWidth = 420,
  });

  /// Standard clean input decoration for auth forms
  static InputDecoration inputDecoration({
    required String hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? focusedBorderColor,
    Color? enabledBorderColor,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      hintText: hintText,
      labelText: labelText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: enabledBorderColor ?? const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: focusedBorderColor ?? const Color(0xFF487898),
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 1.4,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 1.8,
        ),
      ),
    );
  }

  /// Standard steel blue primary button matching the brand theme
  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    double height = 48,
  }) {
    final bool isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF487898),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: Colors.white,
          elevation: isEnabled ? 2 : 0,
          shadowColor: const Color(0xFF487898).withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? LoadingAnimationWidget.threeArchedCircle(
                color: Colors.white,
                size: 22,
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  /// Clean white sub-container for secondary items like checklists and info panels
  static Widget frostedSection({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }

  /// Clean circular logo with glowing aura matching brand aesthetics
  Widget _buildGlowingLogo({double size = 64}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
            blurRadius: 22,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.50),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(1.0),
          child: Image.asset(
            AssetPaths.schoolLogo,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final size = MediaQuery.sizeOf(context);
          final isDesktop = size.width >= 960;
          final isTablet = size.width >= 640 && size.width < 960;

          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                // 1. School Photo Base
                Image.asset(
                  AssetPaths.landingBackground,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),

                // 2. Royal Blue Sky Gradient Overlay (Softened so school photo is clearly visible)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF034A7F).withValues(alpha: 0.68),
                          const Color(0xFF0267A3).withValues(alpha: 0.38),
                          const Color(0xFF0284C7).withValues(alpha: 0.14),
                          const Color(0xFF0284C7).withValues(alpha: 0.03),
                        ],
                        stops: const [0.0, 0.35, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Lush Green Corner Leaves Framing the Bottom
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: LushCornerLeavesPainter(isDesktop: isDesktop),
                    ),
                  ),
                ),

                // 4. (Atmospheric Sky Flying Papers removed)

                // 5. Main Responsive Scrollable Layout
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 960) {
                        return _buildDesktopLayout(context, constraints);
                      } else if (constraints.maxWidth >= 640) {
                        return _buildTabletLayout(context, constraints);
                      } else {
                        return _buildMobileLayout(context, constraints);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- DESKTOP 2-COLUMN SPLIT (>= 960px) ---
  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    final titleFontSize = (constraints.maxWidth * 0.026).clamp(32.0, 42.0);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1420),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Branding Column (closer to the left edge)
                Expanded(
                  flex: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _buildGlowingLogo(size: 86),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'CLASSREALM',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'CALAMBA CITY, LAGUNA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF59E0B),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 38),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          children: const [
                            TextSpan(
                              text: 'One Realm ',
                              style: TextStyle(color: Color(0xFFF59E0B)),
                            ),
                            TextSpan(
                              text: 'for Every\n',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'Learning Journey.',
                              style: TextStyle(color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Text(
                          'Integrated Senior High School Attendance, Activity and Requirement Tracking, Teacher Lesson Planning, and Learning Materials Management System.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.55,
                            fontWeight: FontWeight.w400,
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 32),

                // Right Decorated Card Column
                Expanded(
                  flex: 9,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      child: _buildDecoratedCard(isMobile: false, isTablet: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TABLET LAYOUT (640px - 959px) ---
  Widget _buildTabletLayout(BuildContext context, BoxConstraints constraints) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardMaxWidth + 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGlowingLogo(size: 80),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CLASSREALM',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          'CALAMBA CITY, LAGUNA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                      shadows: [
                        Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 5),
                      ],
                    ),
                    children: [
                      TextSpan(text: 'One Realm ', style: TextStyle(color: Color(0xFFF59E0B))),
                      TextSpan(text: 'for Every\n', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Learning Journey.', style: TextStyle(color: Color(0xFF38BDF8))),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildDecoratedCard(isMobile: false, isTablet: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MOBILE LAYOUT (< 640px) ---
  Widget _buildMobileLayout(BuildContext context, BoxConstraints constraints) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Centered Crest Logo
            _buildGlowingLogo(size: 88),
            const SizedBox(height: 10),

            // CLASSREALM
            const Text(
              'CLASSREALM',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 3),

            // CALAMBA CITY, LAGUNA
            const Text(
              'CALAMBA CITY, LAGUNA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF59E0B),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Hero Tagline in 3 colors
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  shadows: [
                    Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
                  ],
                ),
                children: [
                  TextSpan(text: 'One Realm ', style: TextStyle(color: Color(0xFFF59E0B))),
                  TextSpan(text: 'for Every\n', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Learning Journey.', style: TextStyle(color: Color(0xFF38BDF8))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Center Frosted Glass Login Card with all 3D decorations anchored
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardMaxWidth.clamp(320.0, 390.0)),
              child: _buildDecoratedCard(isMobile: true, isTablet: false),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- CARD WITH ALL 3D ELEMENTS ANCHORED (BOTH WEB & MOBILE) ---
  Widget _buildDecoratedCard({required bool isMobile, required bool isTablet}) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 1. Frosted Glass Container
        _buildFrostedCard(isMobile, isTablet),

        // 2. Top-Right: 3D Graduation Cap with Cyan Glow Aura
        Positioned(
          top: isMobile ? -30 : -38,
          right: isMobile ? -18 : -28,
          child: IgnorePointer(
            child: GraduationCapWidget(size: isMobile ? 82 : 100),
          ),
        ),

        // 3. Bottom-Left: 3D Closed Blue Book with Ribbon Bookmark
        Positioned(
          bottom: isMobile ? -20 : 12,
          left: isMobile ? -28 : -58,
          child: IgnorePointer(
            child: ClosedBook3DWidget(size: isMobile ? 64 : 82),
          ),
        ),
      ],
    );
  }

  // --- REUSABLE SOLID WHITE CARD CONTAINER (NO MORPHISM) ---
  Widget _buildFrostedCard(bool isMobile, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 32,
        vertical: isMobile ? 26 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cardTopLogo != null) ...[
            Center(child: cardTopLogo!),
            const SizedBox(height: 12),
          ],
          Text(
            cardTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isMobile ? 22 : 24,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cardSubtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          formChild,
        ],
      ),
    );
  }
}
