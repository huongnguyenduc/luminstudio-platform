import 'package:flutter/material.dart';

/// An icon with a live item-count badge that gives a one-shot bounce whenever
/// the count increases — the visual "something landed in your cart" cue.
@immutable
class CartBadgeIcon extends StatefulWidget {
  const CartBadgeIcon({
    required this.icon,
    required this.count,
    this.badgeKey,
    this.color,
    super.key,
  });

  final IconData icon;
  final int count;

  /// Optional key placed on the badge wrapper so it can be used as a
  /// fly-to-cart animation target.
  final Key? badgeKey;
  final Color? color;

  @override
  State<CartBadgeIcon> createState() => _CartBadgeIconState();
}

class _CartBadgeIconState extends State<CartBadgeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.45).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.45, end: 1).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(CartBadgeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Badge(
        key: widget.badgeKey,
        isLabelVisible: widget.count > 0,
        label: Text('${widget.count}'),
        child: Icon(widget.icon, color: widget.color),
      ),
    );
  }
}
