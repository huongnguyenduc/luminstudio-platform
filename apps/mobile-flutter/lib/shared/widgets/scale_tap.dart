import 'package:flutter/material.dart';

/// A wrapper widget that applies a subtle press-down scale effect to its child.
///
/// When the user presses down, the child scales to [scaleFactor] (default 0.97).
/// On release or cancel the child animates back to 1.0.
@immutable
class ScaleTap extends StatefulWidget {
  const ScaleTap({
    required this.child,
    this.onTap,
    this.scaleFactor = 0.97,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _isPressed = false;

  static const _duration = Duration(milliseconds: 120);

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleFactor : 1.0,
        duration: _duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
