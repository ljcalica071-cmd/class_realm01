import 'dart:async';
import 'package:flutter/material.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/models/user_model.dart';

/// Branded onCreate() Progress Loading Screen.
///
/// Features:
/// 1. Dual Branding: School Crest ([AssetPaths.schoolLogo]) + App Emblem ([AssetPaths.appLogo])
///    with subtle breathing scale animation and soft gold/blue glow.
/// 2. Non-blocking UI Progress Pacing:
///    - Phase 1 (0% -> 30%): Smooth ease-in while local storage & Firebase initialize.
///    - Phase 2 (30% -> 65%): Steady build while Supabase connects.
///    - Phase 3 (Fast burst 65% -> 100% over 180ms): The millisecond real init completes,
///      immediately accelerates to 100%, shows "Ready", and transitions to onStart().
class AppLifecycleLoadingScreen extends StatefulWidget {
  final Future<UserModel?> Function() initializationTask;
  final void Function(BuildContext context, UserModel? user) onComplete;

  const AppLifecycleLoadingScreen({
    super.key,
    required this.initializationTask,
    required this.onComplete,
  });

  @override
  State<AppLifecycleLoadingScreen> createState() => _AppLifecycleLoadingScreenState();
}

class _AppLifecycleLoadingScreenState extends State<AppLifecycleLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  late final AnimationController _progressController;
  late Animation<double> _progressAnimation;

  String _statusText = 'Initializing ClassRealm workspace...';
  UserModel? _resolvedUser;
  bool _taskCompleted = false;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    AppLifecycleCoordinator.instance.onCreate();

    // Subtle breathing pulse for dual badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Dynamic progress controller
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 0.30).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutQuad),
    );

    _progressController.forward();

    // Start Phase 2 steady build toward 65% after 350ms if task is still running
    _phaseTimer = Timer(const Duration(milliseconds: 350), () {
      if (!_taskCompleted && mounted) {
        setState(() {
          _statusText = 'Connecting secure database & session...';
        });
        _animateTo(0.65, const Duration(milliseconds: 700), Curves.easeInOut);
      }
    });

    _executeRealInit();
  }

  void _animateTo(double target, Duration duration, Curve curve) {
    final currentVal = _progressAnimation.value;
    _progressController.stop();
    _progressController.duration = duration;
    _progressAnimation = Tween<double>(begin: currentVal, end: target).animate(
      CurvedAnimation(parent: _progressController, curve: curve),
    );
    _progressController.reset();
    _progressController.forward();
  }

  Future<void> _executeRealInit() async {
    try {
      final user = await widget.initializationTask();
      _resolvedUser = user;
    } catch (e) {
      debugPrint('Initialization error caught during onCreate: $e');
    } finally {
      _taskCompleted = true;
      _phaseTimer?.cancel();

      if (mounted) {
        setState(() {
          _statusText = 'Ready!';
        });

        // Fast burst UI curve to 100% over 180ms with Curves.easeOutExpo
        _animateTo(1.0, const Duration(milliseconds: 180), Curves.easeOutExpo);

        Future.delayed(const Duration(milliseconds: 240), () {
          if (mounted) {
            markWarmSession();
            AppLifecycleCoordinator.instance.onStart();
            AppLifecycleCoordinator.instance.onResume();
            widget.onComplete(context, _resolvedUser);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ScaleTransition(
            scale: _pulseScale,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dual Branding Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // School Crest
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          AssetPaths.schoolLogo,
                          height: 64,
                          width: 64,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school_rounded,
                            size: 56,
                            color: AppTheme.catBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Soft separator
                      Container(
                        width: 1.5,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark ? Colors.white30 : Colors.black26),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // App Emblem
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          AssetPaths.appLogo,
                          height: 64,
                          width: 64,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.auto_stories_rounded,
                            size: 56,
                            color: AppTheme.catBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // App Title & School Name
                  const Text(
                    'ClassRealm',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.catBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Eduardo Barretto Senior Integrated School',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Animated Progress Bar & Percentage
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, _) {
                      final val = _progressAnimation.value.clamp(0.0, 1.0);
                      final percent = (val * 100).toInt();

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.catBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Gradient Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  width: double.infinity,
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                                ),
                                FractionallySizedBox(
                                  widthFactor: val,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF0284C7),
                                          Color(0xFF0369A1),
                                          Color(0xFFD97706),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
    );
  }
}
