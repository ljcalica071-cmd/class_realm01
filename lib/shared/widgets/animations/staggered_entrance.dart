import 'dart:async';
import 'package:flutter/material.dart';
import 'package:class_realm/core/services/app_lifecycle_coordinator.dart';

/// Reusable Staggered Entrance Animation Widget.
///
/// Combines a subtle vertical slide (`Offset(0, 0.08)` -> `Offset.zero`)
/// with a smooth fade (`0.0 -> 1.0`) over [duration] using [Curves.easeOutCubic].
///
/// Staggers items sequentially based on either:
/// - [index] with [delayStep] (default: 60ms per index increment)
/// - or explicit [delay].
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration? delay;
  final Duration delayStep;
  final Duration duration;
  final Curve curve;
  final Offset initialOffset;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
    this.delayStep = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.initialOffset = const Offset(0.0, 0.08),
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: widget.initialOffset,
      end: Offset.zero,
    ).animate(curved);

    // If app is already started/resumed (warm boot or past loading), trigger immediately.
    // Otherwise, listen for onStart() so elements don't animate invisibly behind the loading screen.
    final coordinator = AppLifecycleCoordinator.instance;
    if (coordinator.currentState != AppActivityLifecycleState.created) {
      _scheduleEntrance();
    } else {
      coordinator.stateNotifier.addListener(_onLifecycleChanged);
    }
  }

  void _onLifecycleChanged() {
    if (AppLifecycleCoordinator.instance.currentState != AppActivityLifecycleState.created) {
      AppLifecycleCoordinator.instance.stateNotifier.removeListener(_onLifecycleChanged);
      if (mounted) {
        _scheduleEntrance();
      }
    }
  }

  void _scheduleEntrance() {
    final effectiveDelay = widget.delay ?? (widget.delayStep * widget.index);
    if (effectiveDelay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(effectiveDelay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    AppLifecycleCoordinator.instance.stateNotifier.removeListener(_onLifecycleChanged);
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
