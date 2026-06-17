import 'package:flutter/material.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/catalog_sprite_preview.dart';

/// Shared product thumbnail used by the Home and Category cards.
///
/// Shows the 360 sprite frame (or an animated subtle preview when
/// [previewActive]) and falls back to a 3D icon. The keys are injected by the
/// caller so each surface keeps its own preview-detection contract.
@immutable
class ProductMediaTile extends StatelessWidget {
  const ProductMediaTile({
    required this.product,
    required this.previewActive,
    required this.spriteFrameKey,
    required this.subtlePreviewKey,
    required this.iconKey,
    super.key,
  });

  final CatalogProduct product;
  final bool previewActive;
  final Key spriteFrameKey;
  final Key subtlePreviewKey;
  final Key iconKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUri = product.spritePreviewUri;

    return Container(
      width: 108,
      height: 124,
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: context.gradients.mediaBackdrop,
        borderRadius: BorderRadius.circular(LuminRadii.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: product.hasPreview && previewUri != null
                  ? SizedBox.square(
                      key: previewActive ? subtlePreviewKey : spriteFrameKey,
                      dimension: 96,
                      child: previewActive
                          ? CatalogSubtleSpritePreview(
                              uri: previewUri,
                              productName: product.name,
                            )
                          : CatalogSpriteFrame(
                              uri: previewUri,
                              productName: product.name,
                            ),
                    )
                  : Icon(
                      key: iconKey,
                      product.hasPreview
                          ? Icons.view_in_ar
                          : Icons.view_in_ar_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          if (product.hasPreview)
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(LuminRadii.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.threesixty,
                        size: 13,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '360',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
