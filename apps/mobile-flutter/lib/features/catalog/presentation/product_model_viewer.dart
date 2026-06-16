import 'package:flutter/material.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

typedef ProductModelViewerBuilder =
    Widget Function(BuildContext context, CatalogProductDetail detail);

Widget defaultProductModelViewerBuilder(
  BuildContext context,
  CatalogProductDetail detail,
) {
  return ProductModelViewer(detail: detail);
}

class ProductModelViewer extends StatelessWidget {
  const ProductModelViewer({super.key, required this.detail});

  final CatalogProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final modelUri = detail.modelUri;
    if (modelUri == null) {
      return const _ProductModelUnavailable();
    }

    final theme = Theme.of(context);

    return Semantics(
      label: 'Interactive 3D viewer for ${detail.name}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: ModelViewer(
            key: ValueKey<String>('model-viewer-${detail.id}'),
            src: modelUri.toString(),
            alt: 'Interactive 3D model of ${detail.name}',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            cameraControls: true,
            disableZoom: false,
            autoRotate: false,
            ar: false,
            debugLogging: false,
          ),
        ),
      ),
    );
  }
}

class _ProductModelUnavailable extends StatelessWidget {
  const _ProductModelUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '3D model unavailable',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
