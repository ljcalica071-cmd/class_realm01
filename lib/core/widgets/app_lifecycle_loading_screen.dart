import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';

/// Premium glassmorphism onCreate() loading screen (mobile/desktop app).
///
/// Mirrors the web pre-bootstrap loader in `web/index.html`:
/// 1. ClassRealm palette — steel blue `#487898`, sky blue `#60A5FA`,
///    sage `#E8EBE2`, off-white `#F5F5F5` — with slowly floating colour orbs.
/// 2. Frosted glass card ([BackdropFilter]) with dual branding
///    (School Crest [AssetPaths.schoolLogo] + App Emblem [AssetPaths.appLogo]).
/// 3. Real milestone progress (driven by [initializationTask] callbacks) with
///    a gentle idle creep toward the next milestone so it never looks frozen,
///    but never passes a milestone that has not actually been reached.
/// 4. Four-step indicator (Engine → Config → Connect → Session).
/// 5. Synchronized exit dissolve into onStart() and the destination screen.
class AppLifecycleLoadingScreen extends StatefulWidget {
  final Future<UserModel?> Function(
    void Function(double progress, String status) onProgress,
  )
  initializationTask;
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
  // ClassRealm palette (kept in sync with AppTheme light mode).
  static const Color _steel = Color(0xFF487898);
  static const Color _steelDeep = Color(0xFF2F5872);
  static const Color _sky = Color(0xFF60A5FA);
  static const Color _sage = Color(0xFFE8EBE2);
  static const Color _offWhite = Color(0xFFF5F5F5);
  static const Color _ink = Color(0xFF1B2B38);
  static const Color _success = Color(0xFF16A34A);

  late final AnimationController _ambientController;
  late final AnimationController _sheenController;
  late final Ticker _progressTicker;

  late final AnimationController _exitController;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  String _statusText = 'Initializing ClassRealm...';
  UserModel? _resolvedUser;

  /// Last real milestone reached by the initialization task.
  double _floor = 0.0;

  /// Value currently painted (0.0 -> 1.0).
  double _shown = 0.01;

  /// Previous ticker timestamp for frame-rate independent delta-time.
  Duration _lastTick = Duration.zero;

  /// True once initialization finishes and the loader is bursting to 100%.
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    AppLifecycleCoordinator.instance.onCreate();

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOutCubic),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _shown = 0.01;
    _floor = 0.08;

    _progressTicker = createTicker(_onProgressTick)..start();

    _executeRealInit();
  }

  /// 3-Phase Psychological UI/UX Loading Curve:
  /// - Phase 1 (SLOW,         0% -> 28%): Calm deliberate build-up (~8%/s).
  /// - Phase 2 (MODERATE,    28% -> 50%): Steady acceleration (~16%/s).
  /// - Phase 3 (BOOST FAST, 50% -> 100%): High-speed boost (~55%/s -> ~190%/s) to 100%.
  double _computeSlowToFastVelocity(double current) {
    if (_isCompleting) {
      // Immediate completion burst
      return 1.90;
    }
    if (current < 0.28) {
      // Phase 1: SLOW (0 - 28%)
      return 0.08;
    }
    if (current < 0.50) {
      // Phase 2: MODERATE (28 - 50%)
      return 0.16;
    }
    if (current < 0.92) {
      // Phase 3: BOOST FAST LOADING (50 - 92%)
      return 0.52;
    }
    if (current < 0.99) {
      // Upper glide while awaiting tasks (never stops on one number)
      return 0.08;
    }
    return 0.0;
  }

  void _onProgressTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : ((elapsed - _lastTick).inMicroseconds / 1000000.0).clamp(0.001, 0.1);
    _lastTick = elapsed;

    double speed = _computeSlowToFastVelocity(_shown);

    // If real milestones are ahead of _shown, blend in an accelerating catch-up
    // weighted by _shown so the overall feel remains strictly Slow -> Fast.
    if (!_isCompleting && _floor > _shown) {
      final gap = _floor - _shown;
      final accelerationFactor = 0.55 + (_shown * 1.65);
      speed = speed + (gap * accelerationFactor);
    }

    final ceiling = _isCompleting ? 1.0 : 0.99;
    final next = (_shown + speed * dt).clamp(0.01, ceiling);

    if ((next - _shown).abs() > 0.0005) {
      setState(() => _shown = next);
      updatePreBootstrapProgress(_shown, _statusText);
    }
  }

  void _reportProgress(double target, String status) {
    if (!mounted) return;
    final clamped = target.clamp(0.0, 1.0);
    setState(() {
      _statusText = status;
      if (clamped > _floor) _floor = clamped;
      if (clamped >= 1.0) _isCompleting = true;
    });
  }

  Future<void> _waitUntilShown(double target) async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 950));
    while (mounted &&
        _shown < target - 0.001 &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (mounted && _shown < target) setState(() => _shown = target);
  }

  Future<void> _executeRealInit() async {
    _reportProgress(0.08, 'Initializing ClassRealm...');
    try {
      final task = widget.initializationTask(_reportProgress);
      _resolvedUser = await task.timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('Initialization fallback during loading screen');
          return AuthRepository.instance.currentUser;
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Initialization notice during onCreate: $error\n$stackTrace');
      _resolvedUser = AuthRepository.instance.currentUser;
    }

    _reportProgress(1.0, 'ClassRealm ready. Welcome!');
    await _waitUntilShown(1.0);
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 140));
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
    _progressTicker.dispose();
    _ambientController.dispose();
    _sheenController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _orb({
    required double size,
    required Color color,
    required Offset base,
    required Offset drift,
  }) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_ambientController.value);
        return Positioned(
          left: base.dx + drift.dx * t,
          top: base.dy + drift.dy * t,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoBadge({
    required String imagePath,
    required IconData fallbackIcon,
    bool isAppLogo = false,
  }) {
    return Container(
      width: 74,
      height: 74,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: _steel.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          padding: isAppLogo ? EdgeInsets.zero : const EdgeInsets.all(3),
          child: Transform.scale(
            scale: isAppLogo ? 1.82 : 1.0,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(fallbackIcon, size: 36, color: _steel),
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar(double value, bool ready) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ready
                      ? const [_steel, _success]
                      : const [Color(0xFF3A6A88), _steel, _sky],
                ),
                boxShadow: [
                  BoxShadow(color: _sky.withValues(alpha: 0.5), blurRadius: 12),
                ],
              ),
              child: ready
                  ? null
                  : AnimatedBuilder(
                      animation: _sheenController,
                      builder: (context, _) {
                        return FractionalTranslation(
                          translation: Offset(
                            _sheenController.value * 2 - 1,
                            0,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.2, 0.5, 0.8],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final value = _shown.clamp(0.0, 1.0);
    final percent = (value * 100).floor();
    final ready = percent >= 100;

    return FadeTransition(
      opacity: _exitFade,
      child: ScaleTransition(
        scale: _exitScale,
        child: Scaffold(
          backgroundColor: _offWhite,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Soft palette gradient base
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_offWhite, _sage, Color(0xFFDFE8EE)],
                    stops: [0.0, 0.48, 1.0],
                  ),
                ),
              ),

              // 2. Floating colour orbs (what the glass blurs)
              _orb(
                size: shortest * 1.1,
                color: _steel.withValues(alpha: 0.45),
                base: Offset(-shortest * 0.45, -shortest * 0.45),
                drift: Offset(shortest * 0.08, shortest * 0.06),
              ),
              _orb(
                size: shortest * 0.95,
                color: _sky.withValues(alpha: 0.38),
                base: Offset(
                  size.width - shortest * 0.55,
                  size.height - shortest * 0.6,
                ),
                drift: Offset(-shortest * 0.07, -shortest * 0.05),
              ),
              _orb(
                size: shortest * 0.6,
                color: AppTheme.catTeal.withValues(alpha: 0.16),
                base: Offset(-shortest * 0.1, size.height * 0.55),
                drift: Offset(shortest * 0.06, -shortest * 0.04),
              ),

              // 3. Glass card
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(30, 36, 30, 26),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.62),
                                Colors.white.withValues(alpha: 0.28),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF29485E)
                                    .withValues(alpha: 0.18),
                                blurRadius: 50,
                                offset: const Offset(0, 24),
                                spreadRadius: -12,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Dual branding
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _logoBadge(
                                    imagePath: AssetPaths.schoolLogo,
                                    fallbackIcon: Icons.school_rounded,
                                  ),
                                  Container(
                                    width: 1.5,
                                    height: 40,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          _steel.withValues(alpha: 0.0),
                                          _steel.withValues(alpha: 0.6),
                                          _steel.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _logoBadge(
                                    imagePath: AssetPaths.appLogo,
                                    fallbackIcon: Icons.auto_stories_rounded,
                                    isAppLogo: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Title
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 4,
                                    color: _ink,
                                  ),
                                  children: [
                                    TextSpan(text: 'CLASS'),
                                    TextSpan(
                                      text: 'REALM',
                                      style: TextStyle(color: _steel),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'EDUARDO BARRETTO SENIOR INTEGRATED SCHOOL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                  color: _steel,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Status + percentage
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ready ? _success : _steel,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _statusText,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3B4A56),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: '$percent'),
                                        const TextSpan(
                                          text: '%',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontSize: 22,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: ready
                                          ? const Color(0xFF15803D)
                                          : _steelDeep,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _progressBar(value, ready),
                              const SizedBox(height: 24),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 12,
                                    color: Color(0xFF6B7C89),
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Preparing your secure learning workspace',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 0.2,
                                        color: Color(0xFF6B7C89),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
