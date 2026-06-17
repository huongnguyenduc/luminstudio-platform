import 'package:flutter/material.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/shared/format/money.dart';
import 'package:lumin_studio_mobile/shared/widgets/discount_badge.dart';
import 'package:lumin_studio_mobile/shared/widgets/price_tag.dart';
import 'package:lumin_studio_mobile/shared/widgets/scale_tap.dart';

/// Bold, vibrant product list card shared by the Home and Category tabs.
///
/// The [media] widget (sprite preview / icon) is supplied by the caller so each
/// surface keeps its own preview keys and animation, while this widget owns the
/// premium framing, discount badge, pricing and quick-add affordance.
@immutable
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.media,
    required this.categoryLabel,
    required this.statusLabel,
    required this.name,
    required this.description,
    required this.price,
    required this.onTap,
    this.onQuickAdd,
    this.quickAddKey,
    super.key,
  });

  final Widget media;
  final String categoryLabel;
  final String statusLabel;
  final String name;
  final String description;
  final CatalogPrice price;
  final VoidCallback onTap;
  final VoidCallback? onQuickAdd;
  final Key? quickAddKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = discountPercent(
      price.amountCents,
      price.compareAtAmountCents,
    );

    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(LuminRadii.lg),
          boxShadow: LuminShadows.card(theme.brightness),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                media,
                if (percent != null)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: DiscountBadge(percent: percent, compact: true),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryLabel.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: _StatusPill(label: statusLabel)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: PriceTag(
                          amountCents: price.amountCents,
                          currency: price.currency,
                          compareAtAmountCents: price.compareAtAmountCents,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onQuickAdd != null)
                        _QuickAddButton(
                          key: quickAddKey,
                          onTap: onQuickAdd!,
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LuminRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Quick add to cart',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            decoration: BoxDecoration(
              gradient: context.gradients.brand,
              shape: BoxShape.circle,
              boxShadow: LuminShadows.glow(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.add_shopping_cart_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
