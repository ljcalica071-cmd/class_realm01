import 'package:flutter/material.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';

/// Global Top Loading Bar (Linear Progress / Shimmer).
///
/// Displayed across the very top of the window during warm browser refresh (F5)
/// and background session revalidation / silent delta syncs.
/// Allows the user to remain seamlessly on their active screen & sub-tab on Frame 1,
/// with an elegant non-blocking top progress bar indicating background activity.
class GlobalTopLoadingBar extends StatefulWidget {
  final double height;

  const GlobalTopLoadingBar({
    super.key,
    this.height = 3.5,
  });

  @override
  State<GlobalTopLoadingBar> createState() => _GlobalTopLoadingBarState();
}

class _GlobalTopLoadingBarState extends State<GlobalTopLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLifecycleCoordinator.instance.isSyncingNotifier,
      builder: (context, isSyncing, _) {
        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: isSyncing ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                boxShadow: isSyncing
                    ? [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 1.5),
                        ),
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedBuilder(
                animation: _sweepController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(double.infinity, widget.height),
                    painter: _TopBarSweepPainter(
                      progress: _sweepController.value,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBarSweepPainter extends CustomPainter {
  final double progress;

  _TopBarSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle glowing base track
    final basePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF0284C7),
          Color(0xFF2563EB),
          Color(0xFF38BDF8),
          Color(0xFFF59E0B),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // 2. High-intensity traveling shimmer beam
    final beamWidth = size.width * 0.40;
    final beamX = (progress * (size.width + beamWidth * 2)) - beamWidth;

    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(beamX, 0, beamWidth, size.height));

    canvas.drawRect(Rect.fromLTWH(beamX, 0, beamWidth, size.height), beamPaint);
  }

  @override
  bool shouldRepaint(covariant _TopBarSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
