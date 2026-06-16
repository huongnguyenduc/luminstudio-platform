import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';

class CatalogProductsView extends StatelessWidget {
  const CatalogProductsView({required this.scrollKey, super.key});

  final PageStorageKey<String> scrollKey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, state) {
        return Semantics(
          label: 'Home catalog products',
          child: switch (state.status) {
            CatalogStatus.initial ||
            CatalogStatus.loading => const _CatalogLoading(),
            CatalogStatus.empty => const _CatalogEmpty(),
            CatalogStatus.failure => _CatalogFailure(message: state.message),
            CatalogStatus.ready => _CatalogList(
              scrollKey: scrollKey,
              products: state.products,
            ),
          },
        );
      },
    );
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

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

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      key: const PageStorageKey<String>('home-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 168),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'No catalog products yet',
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _CatalogFailure extends StatelessWidget {
  const _CatalogFailure({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      key: const PageStorageKey<String>('home-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 168),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.error),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message ?? 'Catalog is unavailable',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  context.read<CatalogCubit>().loadProducts();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.scrollKey, required this.products});

  final PageStorageKey<String> scrollKey;
  final List<CatalogProduct> products;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: scrollKey,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemBuilder: (context, index) {
        return _CatalogProductTile(product: products[index]);
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemCount: products.length,
    );
  }
}

class _CatalogProductTile extends StatelessWidget {
  const _CatalogProductTile({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = product.processingStatus.replaceAll('_', ' ');

    return Semantics(
      button: false,
      label: 'Catalog product ${product.name}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: product.hasPreview
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Icon(
                product.hasPreview
                    ? Icons.view_in_ar
                    : Icons.view_in_ar_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.hasPreview ? '360 preview ready' : statusLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
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
