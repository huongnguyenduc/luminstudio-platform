import 'package:flutter/material.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/catalog_sprite_preview.dart';
import 'package:lumin_studio_mobile/shared/widgets/product_thumbnail_image.dart';

/// Shared product thumbnail used by the Home and Category cards.
///
/// At rest the tile shows the product's description image (a single clean
/// studio still). Once the tile has been dwelled on ([previewActive]) it
/// switches to the 360 sprite swinging left/right. When the product has no
/// description image it leads with the static sprite frame, and falls back to a
/// 3D icon when it has neither. The render fills the rounded tile so the product
/// reads as one photo instead of a framed thumbnail in a grey box. The keys are
/// injected by the caller so each surface keeps its own preview-detection
/// contract.
@immutable
class ProductMediaTile extends StatelessWidget {
  const ProductMediaTile({
    required this.product,
    required this.previewActive,
    required this.spriteFrameKey,
    required this.subtlePreviewKey,
    required this.descriptionImageKey,
    required this.iconKey,
    super.key,
  });

  final CatalogProduct product;
  final bool previewActive;
  final Key spriteFrameKey;
  final Key subtlePreviewKey;
  final Key descriptionImageKey;
  final Key iconKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUri = product.spritePreviewUri;
    final hasPreview = product.hasPreview && previewUri != null;
    final descriptionImageUri = product.descriptionImageUri;

    return SizedBox(
      width: 112,
      height: 124,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuminRadii.md),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildMedia(
            theme,
            previewUri: previewUri,
            hasPreview: hasPreview,
            descriptionImageUri: descriptionImageUri,
          ),
        ),
      ),
    );
  }

  Widget _buildMedia(
    ThemeData theme, {
    required Uri? previewUri,
    required bool hasPreview,
    required Uri? descriptionImageUri,
  }) {
    // The 360 preview takes over once the tile has been dwelled on. Activation
    // is gated on the sprite existing (see the views), so this only triggers
    // when [hasPreview] is true.
    if (previewActive && hasPreview) {
      return SizedBox.expand(
        key: subtlePreviewKey,
        child: CatalogSubtleSpritePreview(
          uri: previewUri!,
          productName: product.name,
        ),
      );
    }

    // Resting state: lead with the description image when the product has one,
    // falling back to the sprite frame (then a 3D icon) if it fails to load.
    if (descriptionImageUri != null) {
      return SizedBox.expand(
        key: descriptionImageKey,
        child: ProductThumbnailImage(
          uri: descriptionImageUri,
          productName: product.name,
          fallback: hasPreview
              ? CatalogSpriteFrame(uri: previewUri!, productName: product.name)
              : _iconPlaceholder(theme),
        ),
      );
    }

    if (hasPreview) {
      return SizedBox.expand(
        key: spriteFrameKey,
        child: CatalogSpriteFrame(uri: previewUri!, productName: product.name),
      );
    }

    return _iconPlaceholder(theme);
  }

  Widget _iconPlaceholder(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
      ),
      child: Center(
        child: Icon(
          key: iconKey,
          product.hasPreview ? Icons.view_in_ar : Icons.view_in_ar_outlined,
          size: 40,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
