import 'dart:async';

import 'package:flutter/material.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';

/// Premium Branded onCreate() Progress Loading Screen.
///
/// Features:
/// 1. Dual Branding: School Crest ([AssetPaths.schoolLogo]) + App Emblem ([AssetPaths.appLogo])
///    encapsulated in an ultra-modern glowing composition with breathing ambient lighting.
/// 2. UI Slow-to-Fast Progress Pacing (0% -> 30% -> 65% -> 100%):
///    - Phase 1 (0% -> 30%): Smooth ease-in curve while local storage & Firebase initialize.
///    - Phase 2 (30% -> 65%): Steady progression while Supabase connects.
///    - Phase 3 (65% -> 100%): Rapid burst over 220ms with [Curves.easeOutExpo] the instant real init completes.
/// 3. High-tech glowing progress bar with traveling shimmer sweep beam and monospace percentage counter.
/// 4. Synchronized exit dissolve into onStart() and destination screen.
class AppLifecycleLoadingScreen extends StatefulWidget {
  final Future<UserModel?> Function() initializationTask;
  final void Function(BuildContext context, UserModel? user) onComplete;

  const AppLifecycleLoadingScreen({
    super.key,
    required this.initializationTask,
    required this.onComplete,
  });

  @override
  State<AppLifecycleLoadingScreen> createState() =>
      _AppLifecycleLoadingScreenState();
}

class _AppLifecycleLoadingScreenState extends State<AppLifecycleLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  late final AnimationController _shimmerController;

  late final AnimationController _progressController;
  late Animation<double> _progressAnimation;

  late final AnimationController _exitController;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  String _statusText = 'Initializing ClassRealm workspace...';
  UserModel? _resolvedUser;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    AppLifecycleCoordinator.instance.onCreate();

    // Immediately remove static HTML pre-loader if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removePreBootstrapLoader();
    });

    // Exit transition controller (320ms dissolve + slight scale)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOutCubic),
    );

    // Subtle breathing pulse for dual badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Continuous shimmer sweep controller for progress bar
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Continue from the web pre-loader so the visible percentage never resets.
    final initialProgress = getPreBootstrapProgress();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _progressAnimation = AlwaysStoppedAnimation<double>(initialProgress);
    _progressController.addListener(() {
      updatePreBootstrapProgress(_progressAnimation.value, _statusText);
    });

    _executeRealInit();
  }

  Future<void> _animateTo(double target, Duration duration, Curve curve) async {
    final currentVal = _progressAnimation.value;
    _progressController.stop();
    _progressController.duration = duration;
    _progressAnimation = Tween<double>(
      begin: currentVal,
      end: target,
    ).animate(CurvedAnimation(parent: _progressController, curve: curve));
    _progressController.reset();
    try {
      await _progressController.forward().orCancel;
    } on TickerCanceled {
      return;
    }
  }

  Future<void> _executeRealInit() async {
    // Kick off real initialization concurrently with a safety fallback
    final initialization = Future<UserModel?>.sync(widget.initializationTask)
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            debugPrint('Initialization fallback during loading screen');
            return AuthRepository.instance.currentUser;
          },
        )
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'Initialization notice during onCreate: $error\n$stackTrace',
          );
          return null;
        });

    // Phase 1: 0% -> 30% (smooth ease out)
    if (_progressAnimation.value < 0.30) {
      await _animateTo(
        0.30,
        const Duration(milliseconds: 450),
        Curves.easeOutQuad,
      );
      if (!mounted) return;
    }

    // Phase 2: 30% -> 65% (smooth continuous progression - NO pausing!)
    if (mounted) {
      setState(() {
        _statusText = 'Connecting secure database & services...';
      });
      updatePreBootstrapProgress(_progressAnimation.value, _statusText);
    }
    if (_progressAnimation.value < 0.65) {
      await _animateTo(
        0.65,
        const Duration(milliseconds: 550),
        Curves.easeInOutCubic,
      );
      if (!mounted) return;
    }

    // Phase 3: 65% -> 100% (straight continuous progression to completion - DERETSO LANG!)
    if (mounted) {
      setState(() {
        _statusText = 'ClassRealm Ready! Welcome.';
      });
      updatePreBootstrapProgress(_progressAnimation.value, _statusText);
    }
    await _animateTo(
      1.0,
      const Duration(milliseconds: 450),
      Curves.easeOutExpo,
    );
    if (!mounted) return;
    updatePreBootstrapProgress(1.0, _statusText);

    // Concurrently await real init result if not yet done (fast cap so we NEVER freeze at 100%)
    try {
      _resolvedUser = await initialization.timeout(
        const Duration(milliseconds: 200),
      );
    } catch (_) {
      _resolvedUser = AuthRepository.instance.currentUser;
    }
    if (!mounted) return;

    // Brief 120ms visual confirmation of 100% "Ready", then dissolve smoothly into destination
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    AppLifecycleCoordinator.instance.onStart();
    await _exitController.forward();
    if (!mounted) return;
    markWarmSession();
    AppLifecycleCoordinator.instance.onResume();
    widget.onComplete(context, _resolvedUser);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _progressController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Widget _buildLogoBadge({
    required String imagePath,
    required IconData fallbackIcon,
    required Color borderColor,
    bool isAppLogo = false,
  }) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E293B),
        // Manipis na white outer line sa logo
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          padding: isAppLogo ? EdgeInsets.zero : const EdgeInsets.all(3),
          child: isAppLogo
              ? Transform.scale(
                  scale: 1.82,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(fallbackIcon, size: 40, color: AppTheme.catBlue),
                  ),
                )
              : Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(fallbackIcon, size: 40, color: AppTheme.catBlue),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _exitFade,
      child: ScaleTransition(
        scale: _exitScale,
        child: Scaffold(
          backgroundColor: const Color(0xFF090E17),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Deep Space Radial Glow Background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 1.25,
                      colors: [
                        Color(
                          0xFF13203C,
                        ), // soft rich midnight blue ambient core
                        Color(0xFF0B1120), // deep navy
                        Color(0xFF060911), // dark obsidian edges
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // 2. Soft Ambient Cyan & Gold Light Spheres
              Positioned(
                top: -80,
                left: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Main Center Loading Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 40,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF334155)
                              .withValues(alpha: 0.65),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: const Color(0xFF38BDF8)
                                .withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dual Branding Badges (School Logo + App Logo)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLogoBadge(
                                imagePath: AssetPaths.schoolLogo,
                                fallbackIcon: Icons.school_rounded,
                                borderColor: const Color(0xFF38BDF8),
                                isAppLogo: false,
                              ),
                              const SizedBox(width: 16),
                              // Golden/Cyan Gradient Bridge
                              Container(
                                width: 2,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF38BDF8),
                                      Color(0xFFF59E0B),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildLogoBadge(
                                imagePath: AssetPaths.appLogo,
                                fallbackIcon: Icons.auto_stories_rounded,
                                borderColor: const Color(0xFFF59E0B),
                                isAppLogo: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),

                          // App Title & School Name
                          Text(
                            'CLASSREALM',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.5,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'EDUARDO BARRETTO SENIOR INTEGRATED SCHOOL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Dynamic Progress Bar & Percentage
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _progressAnimation,
                              _shimmerController,
                            ]),
                            builder: (context, _) {
                              final val = _progressAnimation.value.clamp(
                                0.0,
                                1.0,
                              );
                              final percent = (val * 100).toInt();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Top Row: Status chip + Bold Percentage
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Status Pill Chip
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 11,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B)
                                                .withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: val >= 1.0
                                                  ? const Color(0xFF10B981)
                                                        .withValues(alpha: 0.6)
                                                  : const Color(
                                                      0xFF38BDF8,
                                                    ).withValues(alpha: 0.35),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: val >= 1.0
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFF38BDF8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          (val >= 1.0
                                                                  ? const Color(
                                                                      0xFF10B981,
                                                                    )
                                                                  : const Color(
                                                                      0xFF38BDF8,
                                                                    ))
                                                              .withValues(
                                                                alpha: 0.8,
                                                              ),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  _statusText,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: val >= 1.0
                                                        ? const Color(
                                                            0xFF6EE7B7,
                                                          )
                                                        : const Color(
                                                            0xFFCBD5E1,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Monospace Percentage
                                      Text(
                                        '$percent%',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                          color: val >= 1.0
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF38BDF8),
                                          shadows: [
                                            Shadow(
                                              color:
                                                  (val >= 1.0
                                                          ? const Color(
                                                              0xFF10B981,
                                                            )
                                                          : const Color(
                                                              0xFF38BDF8,
                                                            ))
                                                      .withValues(alpha: 0.5),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Glowing High-Tech Progress Track
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B1120),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        width: 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black54,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: Stack(
                                        children: [
                                          // Filled Gradient Bar
                                          FractionallySizedBox(
                                            widthFactor: val,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF0284C7),
                                                    Color(0xFF2563EB),
                                                    Color(0xFF38BDF8),
                                                    Color(0xFFF59E0B),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF38BDF8,
                                                    ).withValues(alpha: 0.6),
                                                    blurRadius: 10,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Animated Shimmer Light Sweep Beam
                                          if (val > 0.05 && val < 1.0)
                                            Positioned.fill(
                                              child: FractionallySizedBox(
                                                widthFactor: val,
                                                alignment: Alignment.centerLeft,
                                                child: Transform.translate(
                                                  offset: Offset(
                                                    (_shimmerController.value *
                                                            350) -
                                                        80,
                                                    0,
                                                  ),
                                                  child: Container(
                                                    width: 60,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.white
                                                              .withValues(
                                                                alpha: 0.0,
                                                              ),
                                                          Colors.white
                                                              .withValues(
                                                                alpha: 0.65,
                                                              ),
                                                          Colors.white
                                                              .withValues(
                                                                alpha: 0.0,
                                                              ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Bottom Security Tag
                                  Center(
                                    child: Text(
                                      'Preparing your secure learning workspace',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
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
