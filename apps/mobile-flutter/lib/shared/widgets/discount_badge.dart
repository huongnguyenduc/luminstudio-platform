import 'package:flutter/material.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';

/// A vivid "-NN%" sale badge used to draw attention to marked-down products.
@immutable
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({required this.percent, this.compact = false, super.key});

  final int percent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: context.gradients.discount,
        borderRadius: BorderRadius.circular(LuminRadii.pill),
        boxShadow: LuminShadows.glow(LuminColors.ember),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: compact ? 12 : 14,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            '-$percent%',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
