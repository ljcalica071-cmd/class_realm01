import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// ClassRealm mobile swipe-down pull-to-refresh wrapper using the signature
/// `LoadingAnimationWidget.staggeredDotsWave` button indicator inside a sleek
/// primary pill capsule.
///
/// Unmounts the repeating animation completely when idle so battery/CPU usage
/// is zero at rest and `WidgetTester.pumpAndSettle` settles cleanly.
class AppPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final double triggerDistance;
  final double restingTop;
  final Color? capsuleColor;
  final Color? indicatorColor;

  const AppPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 56.0,
    this.restingTop = 14.0,
    this.capsuleColor,
    this.indicatorColor,
  });

  /// Wraps a non-scrollable empty or error state inside an always-scrollable
  /// viewport-filling box so mobile users can still swipe down to refresh.
  static Widget scrollableState({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 280.0;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: padding,
              child: Center(child: child),
            ),
          ),
        );
      },
    );
  }

  @override
  State<AppPullToRefresh> createState() => _AppPullToRefreshState();
}

class _AppPullToRefreshState extends State<AppPullToRefresh>
    with SingleTickerProviderStateMixin {
  static const double _maxPullDistance = 108.0;
  static const double _holdDistance = 52.0;

  double _pullDistance = 0.0;
  bool _isDraggingFromTop = false;
  bool _isRefreshing = false;
  late final AnimationController _exitController;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (widget.onRefresh == null) return false;
    // Support direct scrollables (depth 0) and vertical scrollables inside
    // horizontal tab/page views (depth 1).
    if (notification.depth > 1) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_isRefreshing) return false;

    if (notification is ScrollStartNotification) {
      _isDraggingFromTop =
          notification.dragDetails != null &&
          notification.metrics.extentBefore <= 0.5;
    } else if (notification is OverscrollNotification) {
      if ((notification.dragDetails != null ||
              _isDraggingFromTop ||
              _pullDistance > 0) &&
          notification.overscroll < 0 &&
          notification.metrics.extentBefore <= 0.5) {
        _isDraggingFromTop = true;
        setState(() {
          _pullDistance = (_pullDistance - notification.overscroll * 0.72)
              .clamp(0.0, _maxPullDistance);
        });
      } else if (_pullDistance > 0 && notification.overscroll > 0) {
        setState(() {
          _pullDistance = (_pullDistance - notification.overscroll).clamp(
            0.0,
            _maxPullDistance,
          );
        });
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0 &&
          (notification.dragDetails != null ||
              _isDraggingFromTop ||
              _pullDistance > 0)) {
        _isDraggingFromTop = true;
        setState(() {
          _pullDistance = (-notification.metrics.pixels * 0.72).clamp(
            0.0,
            _maxPullDistance,
          );
        });
      } else if (_pullDistance > 0 &&
          notification.scrollDelta != null &&
          notification.scrollDelta! > 0) {
        setState(() {
          _pullDistance = (_pullDistance - notification.scrollDelta!).clamp(
            0.0,
            _maxPullDistance,
          );
        });
      }
    } else if (notification is ScrollEndNotification) {
      _isDraggingFromTop = false;
      if (_pullDistance >= widget.triggerDistance) {
        _startRefresh();
      } else if (_pullDistance > 0) {
        setState(() => _pullDistance = 0.0);
      }
    }
    return false;
  }

  Future<void> _startRefresh() async {
    if (_isRefreshing || widget.onRefresh == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isRefreshing = true;
      _pullDistance = _holdDistance;
    });

    try {
      await widget.onRefresh!();
    } finally {
      if (mounted) {
        // Smooth fade-out and slide upward before unmounting
        await _exitController.forward();
        if (mounted) {
          _exitController.reset();
          setState(() {
            _isRefreshing = false;
            _pullDistance = 0.0;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onRefresh == null) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final bg = widget.capsuleColor ?? theme.colorScheme.primary;
    final fg = widget.indicatorColor ?? Colors.white;
    final showCapsule =
        _isRefreshing || _pullDistance > 2.0 || _exitController.isAnimating;
    final progress = (_pullDistance / widget.triggerDistance).clamp(0.0, 1.0);
    final enterCurve = Curves.easeOutCubic.transform(progress);

    final restingTop = widget.restingTop;
    const startTop = -44.0;
    final pullTop = startTop + (enterCurve * (restingTop - startTop));

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          widget.child,
          if (showCapsule)
            AnimatedBuilder(
              animation: _exitController,
              builder: (context, _) {
                final exitProgress =
                    Curves.easeInOut.transform(_exitController.value);
                final currentTop = _isRefreshing
                    ? (restingTop - (exitProgress * 12.0))
                    : pullTop;
                final currentOpacity = _isRefreshing
                    ? (1.0 - exitProgress).clamp(0.0, 1.0)
                    : enterCurve.clamp(0.0, 1.0);
                final currentScale = _isRefreshing
                    ? (1.0 - (exitProgress * 0.06))
                    : (0.84 + (0.16 * enterCurve));

                return Positioned(
                  top: currentTop,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: currentOpacity,
                      child: Transform.scale(
                        scale: currentScale,
                        child: Container(
                          key: const Key('app_pull_to_refresh_capsule'),
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: bg.withValues(alpha: 0.34),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: _isRefreshing
                              ? SizedBox(
                                  width: 28,
                                  height: 22,
                                  child: Center(
                                    child:
                                        LoadingAnimationWidget.staggeredDotsWave(
                                      color: fg,
                                      size: 24,
                                    ),
                                  ),
                                )
                              : _PullWavePreviewDots(
                                  progress: progress,
                                  color: fg,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Thumb-responsive 5-dot staggered wave preview matching `staggeredDotsWave`
/// while the user is actively pulling down before releasing.
class _PullWavePreviewDots extends StatelessWidget {
  final double progress;
  final Color color;

  const _PullWavePreviewDots({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    const targetHeights = <double>[5.0, 7.0, 9.5, 14.0, 15.5];
    return SizedBox(
      width: 28,
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(targetHeights.length, (i) {
          final h = 4.5 + ((targetHeights[i] - 4.5) * progress);
          return Container(
            width: 3.6,
            height: h,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: (0.55 + (0.45 * progress)).clamp(0.4, 1.0),
              ),
              borderRadius: BorderRadius.circular(99),
            ),
          );
        }),
      ),
    );
  }
}
