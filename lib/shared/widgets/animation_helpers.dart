import 'package:flutter/material.dart';

/// A reusable widget that wraps its child in a staggered fade + slide-up
/// animation based on its index in a list.
///
/// Use this to animate list items, cards, or any repeating UI elements
/// with a cascading entrance effect.
class StaggeredListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final Duration staggerDelay;
  final double slideOffset;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDuration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 80),
    this.slideOffset = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs =
        baseDuration.inMilliseconds + (index * staggerDelay.inMilliseconds);
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: totalMs),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A widget that fades and slides in its child from the specified direction.
/// Useful for page entrance animations.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.05),
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds + delay.inMilliseconds;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: totalMs),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * MediaQuery.of(context).size.width * (1 - value),
              beginOffset.dy * MediaQuery.of(context).size.height * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A subtle scale-in animation for cards and containers.
class ScaleIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginScale;

  const ScaleIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.beginScale = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds + delay.inMilliseconds;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: totalMs),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final scale = beginScale + (1.0 - beginScale) * value;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}
