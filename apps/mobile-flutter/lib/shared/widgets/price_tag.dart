import 'package:flutter/material.dart';
import 'package:lumin_studio_mobile/shared/format/money.dart';

/// Displays the current price with an optional struck-through compare-at price.
@immutable
class PriceTag extends StatelessWidget {
  const PriceTag({
    required this.amountCents,
    required this.currency,
    this.compareAtAmountCents,
    this.style,
    this.compareStyle,
    this.priceKey,
    super.key,
  });

  final int amountCents;
  final String currency;
  final int? compareAtAmountCents;
  final TextStyle? style;
  final TextStyle? compareStyle;
  final Key? priceKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compareAt = compareAtAmountCents;
    final hasCompare = compareAt != null && compareAt > amountCents;

    final priceStyle =
        style ??
        theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        );

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          formatMoney(amountCents, currency),
          key: priceKey,
          style: priceStyle,
        ),
        if (hasCompare)
          Text(
            formatMoney(compareAt, currency),
            style:
                compareStyle ??
                theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: theme.colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}
