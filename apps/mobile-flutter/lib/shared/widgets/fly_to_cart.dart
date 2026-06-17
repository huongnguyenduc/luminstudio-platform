import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Returns the global on-screen rectangle of the widget behind [key], or null
/// if it is not currently laid out.
Rect? globalRectOf(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) {
    return null;
  }
  final box = ctx.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Animates [child] flying along an arc from [startRect] to [endRect],
/// shrinking and fading as it "drops into the cart". Self-contained: it inserts
/// and removes its own [OverlayEntry] and invokes [onArrived] on completion.
void flyToCart({
  required BuildContext context,
  required Rect startRect,
  required Rect endRect,
  required Widget child,
  Duration duration = const Duration(milliseconds: 700),
  VoidCallback? onArrived,
}) {
  final overlayState = Overlay.of(context, rootOverlay: false);
  final overlayBox = overlayState.context.findRenderObject();
  final origin = overlayBox is RenderBox
      ? overlayBox.globalToLocal(Offset.zero)
      : Offset.zero;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingItem(
      start: startRect.shift(origin),
      end: endRect.shift(origin),
      duration: duration,
      onDone: () {
        entry.remove();
        onArrived?.call();
      },
      child: child,
    ),
  );
  overlayState.insert(entry);
}

class _FlyingItem extends StatefulWidget {
  const _FlyingItem({
    required this.start,
    required this.end,
    required this.duration,
    required this.onDone,
    required this.child,
  });

  final Rect start;
  final Rect end;
  final Duration duration;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_FlyingItem> createState() => _FlyingItemState();
}

class _FlyingItemState extends State<_FlyingItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDone();
        }
      })
      ..forward();
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _bezier(Offset p0, Offset control, Offset p1, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * p0.dx + 2 * mt * t * control.dx + t * t * p1.dx,
      mt * mt * p0.dy + 2 * mt * t * control.dy + t * t * p1.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final t = _t.value;
        final p0 = widget.start.center;
        final p1 = widget.end.center;
        final control = Offset(
          (p0.dx + p1.dx) / 2,
          math.min(p0.dy, p1.dy) - 130,
        );
        final pos = _bezier(p0, control, p1, t);
        final scale = 1.0 + (0.32 - 1.0) * t;
        final opacity = t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18);
        final size = 56.0 * scale;
        return Positioned(
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          width: size,
          height: size,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: widget.child,
          ),
        );
      },
    );
  }
}
