import 'package:flutter/material.dart';

/// An animated number counter that slides the old value up while the new
/// value slides in from below, with a simultaneous fade transition.
@immutable
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    required this.count,
    this.style,
    super.key,
  });

  final int count;
  final TextStyle? style;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> {
  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _duration,
      switchInCurve: _curve,
      switchOutCurve: _curve,
      transitionBuilder: (child, animation) {
        // Determine direction: entering children slide up from below,
        // exiting children slide up and out.
        final isIncoming =
            child.key == ValueKey<int>(widget.count);

        final slideOffset = Tween<Offset>(
          begin: Offset(0, isIncoming ? 0.5 : -0.5),
          end: Offset.zero,
        ).animate(animation);

        return SlideTransition(
          position: slideOffset,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Text(
        '${widget.count}',
        key: ValueKey<int>(widget.count),
        style: widget.style,
      ),
    );
  }
}
