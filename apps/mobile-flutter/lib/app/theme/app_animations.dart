import 'package:flutter/material.dart';

/// Standard animation durations used throughout the app.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 350);
}

/// Standard animation curves.
abstract final class AppCurves {
  static const Curve emphasized = Curves.easeOutExpo;
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.easeOutCubic;
}

/// Custom page route with fade + slide up transition.
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AppDurations.pageTransition,
          reverseTransitionDuration: AppDurations.normal,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppCurves.emphasized,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
