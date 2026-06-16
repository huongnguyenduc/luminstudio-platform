import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/product_detail_cubit.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailCubit, ProductDetailState>(
      builder: (context, state) {
        final title = state.detail?.name ?? 'Product detail';

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: switch (state.status) {
            ProductDetailStatus.initial ||
            ProductDetailStatus.loading => const _ProductDetailLoading(),
            ProductDetailStatus.failure => _ProductDetailFailure(
              message: state.message,
            ),
            ProductDetailStatus.ready => _ProductDetailReady(
              detail: state.detail!,
            ),
          },
        );
      },
    );
  }
}

class _ProductDetailLoading extends StatelessWidget {
  const _ProductDetailLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

class _ProductDetailFailure extends StatelessWidget {
  const _ProductDetailFailure({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 12),
            Text(
              message ?? 'Product detail is unavailable',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: context.read<ProductDetailCubit>().load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailReady extends StatelessWidget {
  const _ProductDetailReady({required this.detail});

  final CatalogProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Product detail for ${detail.name}',
      child: ListView(
        key: const PageStorageKey<String>('product-detail-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(detail.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(detail.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          _ModelAccessPanel(detail: detail),
          const SizedBox(height: 20),
          if (detail.informationSections.isNotEmpty) ...[
            Text('Information', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final section in detail.informationSections) ...[
              _InformationSection(section: section),
              const SizedBox(height: 10),
            ],
          ],
          if (detail.meshColorConfig.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Configurable colors', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final options in detail.meshColorConfig) ...[
              _MeshColorOptions(options: options),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _ModelAccessPanel extends StatelessWidget {
  const _ModelAccessPanel({required this.detail});

  final CatalogProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_in_ar, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                'Model tier: ${detail.modelTier.wireName}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (detail.modelUri != null)
            Text(
              'Model route: ${detail.modelUri!.path}?${detail.modelUri!.query}',
            )
          else
            const Text('Model route unavailable'),
          if (detail.spriteUri != null) ...[
            const SizedBox(height: 6),
            Text('Sprite route: ${detail.spriteUri!.path}'),
          ],
        ],
      ),
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({required this.section});

  final CatalogInformationSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(section.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MeshColorOptions extends StatelessWidget {
  const _MeshColorOptions({required this.options});

  final CatalogMeshColorOptions options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(options.meshId, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in options.allowedColors)
                _ColorSwatch(
                  color: color,
                  isDefault: color == options.defaultColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.isDefault});

  final String color;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = int.tryParse(color.substring(1), radix: 16);

    return Tooltip(
      message: isDefault ? '$color default' : color,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: parsed == null
              ? theme.colorScheme.surface
              : Color(0xFF000000 | parsed),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: isDefault
            ? Icon(Icons.check, size: 18, color: theme.colorScheme.onPrimary)
            : null,
      ),
    );
  }
}
