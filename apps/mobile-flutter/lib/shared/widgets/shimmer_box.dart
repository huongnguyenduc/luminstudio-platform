import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A single shimmer placeholder rectangle.
@immutable
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 12,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surfaceContainer,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A shimmer placeholder that matches the product tile layout in the catalog.
///
/// Layout: Row with a 96×112 image box on the left and a right column
/// containing three text-line placeholders.
@immutable
class ShimmerProductTile extends StatelessWidget {
  const ShimmerProductTile({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Left image placeholder
          const ShimmerBox(width: 96, height: 112, borderRadius: 12),
          const SizedBox(width: 12),
          // Right column with three text lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                ShimmerBox(width: double.infinity, height: 16, borderRadius: 8),
                SizedBox(height: 8),
                ShimmerBox(width: 140, height: 14, borderRadius: 8),
                SizedBox(height: 8),
                ShimmerBox(width: 100, height: 14, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical list of [ShimmerProductTile] widgets separated by 12px gaps.
@immutable
class ShimmerProductList extends StatelessWidget {
  const ShimmerProductList({
    this.itemCount = 3,
    super.key,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < itemCount; i++) ...[
          const ShimmerProductTile(),
          if (i < itemCount - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
