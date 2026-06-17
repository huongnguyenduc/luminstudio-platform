import 'package:flutter/material.dart';

/// Renders a product's description image scaled to cover its slot, showing
/// [fallback] when it fails to load (e.g. the product has no image).
///
/// Shared by the product list card (resting state, before the 360 sprite
/// preview activates) and the cart line items so both lead with the same
/// representative still.
class ProductThumbnailImage extends StatelessWidget {
  const ProductThumbnailImage({
    required this.uri,
    required this.productName,
    required this.fallback,
    super.key,
  });

  final Uri uri;
  final String productName;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      image: true,
      label: 'Product image for $productName',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
        ),
        child: Image.network(
          uri.toString(),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          // Hold the subtle backdrop while the image streams in so the tile
          // never flashes empty, then cross-fade the decoded image.
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return const SizedBox.expand();
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}
