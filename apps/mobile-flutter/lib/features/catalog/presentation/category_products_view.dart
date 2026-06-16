import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/get_catalog_product_detail.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/category_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/product_detail_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_detail_view.dart';

class CategoryProductsView extends StatefulWidget {
  const CategoryProductsView({required this.scrollKey, super.key});

  final PageStorageKey<String> scrollKey;

  @override
  State<CategoryProductsView> createState() => _CategoryProductsViewState();
}

class _CategoryProductsViewState extends State<CategoryProductsView> {
  late final ScrollController _scrollController;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      context.read<CategoryCubit>().loadMoreProducts();
    }

    final shouldShow = position.pixels > 360;
    if (_showScrollToTop != shouldShow) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryCubit, CategoryState>(
      builder: (context, state) {
        return Semantics(
          label: 'Category tab content',
          child: Stack(
            children: [
              _CategoryContent(
                scrollKey: widget.scrollKey,
                scrollController: _scrollController,
                state: state,
              ),
              if (_showScrollToTop)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'category-scroll-to-top',
                    tooltip: 'Scroll categories to top',
                    onPressed: _scrollToTop,
                    child: const Icon(Icons.keyboard_arrow_up),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryContent extends StatelessWidget {
  const _CategoryContent({
    required this.scrollKey,
    required this.scrollController,
    required this.state,
  });

  final PageStorageKey<String> scrollKey;
  final ScrollController scrollController;
  final CategoryState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: scrollKey,
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        switch (state.status) {
          CategoryStatus.initial ||
          CategoryStatus.loading => const _CategoryLoading(),
          CategoryStatus.empty => const _CategoryEmpty(),
          CategoryStatus.failure => _CategoryFailure(message: state.message),
          CategoryStatus.ready => _CategoryReady(state: state),
        },
      ],
    );
  }
}

class _CategoryReady extends StatelessWidget {
  const _CategoryReady({required this.state});

  final CategoryState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedCategory;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategorySelector(
          categories: state.categories,
          selectedCategory: selected,
        ),
        const SizedBox(height: 14),
        _CategorySortControl(sort: state.sort),
        const SizedBox(height: 18),
        if (selected != null) ...[
          Text(
            selected.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sorted by ${state.sort.label}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        switch (state.productsStatus) {
          CategoryProductsStatus.idle ||
          CategoryProductsStatus.loading => const _CategoryLoading(),
          CategoryProductsStatus.empty => const _CategoryProductsEmpty(),
          CategoryProductsStatus.failure => _CategoryProductsFailure(
            message: state.productsMessage,
          ),
          CategoryProductsStatus.ready => _CategoryProductList(state: state),
        },
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedCategory,
  });

  final List<CatalogCategory> categories;
  final CatalogCategory? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in categories) ...[
            ChoiceChip(
              label: Text(category.name),
              selected: selectedCategory?.slug == category.slug,
              showCheckmark: false,
              avatar: selectedCategory?.slug == category.slug
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    )
                  : null,
              onSelected: (_) {
                context.read<CategoryCubit>().selectCategory(category);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CategorySortControl extends StatelessWidget {
  const _CategorySortControl({required this.sort});

  final CategoryProductSort sort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Sort products',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort products',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in CategoryProductSort.values) ...[
                  ChoiceChip(
                    label: Text(value.label),
                    selected: value == sort,
                    showCheckmark: false,
                    onSelected: (_) {
                      context.read<CategoryCubit>().changeSort(value);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryProductList extends StatelessWidget {
  const _CategoryProductList({required this.state});

  final CategoryState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final product in state.products) ...[
          _CategoryProductTile(product: product),
          const SizedBox(height: 12),
        ],
        _CategoryPaginationFooter(state: state),
      ],
    );
  }
}

class _CategoryPaginationFooter extends StatelessWidget {
  const _CategoryPaginationFooter({required this.state});

  final CategoryState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (state.loadMoreMessage != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.error),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.loadMoreMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: context.read<CategoryCubit>().loadMoreProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.canLoadMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'All category products loaded',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Center(
      child: TextButton.icon(
        onPressed: context.read<CategoryCubit>().loadMoreProducts,
        icon: const Icon(Icons.expand_more),
        label: const Text('Load more'),
      ),
    );
  }
}

class _CategoryProductTile extends StatelessWidget {
  const _CategoryProductTile({required this.product});

  final CatalogProduct product;

  void _openProductDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlocProvider(
          create: (context) => ProductDetailCubit(
            productId: product.id,
            getCatalogProductDetail: GetCatalogProductDetail(
              context.read<CatalogRepository>(),
            ),
            deviceTierResolver: context.read<DeviceTierResolver>(),
          )..load(),
          child: const ProductDetailPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = product.processingStatus.replaceAll('_', ' ');
    final categoryLabel = product.categories.isEmpty
        ? 'Category'
        : product.categories.first.name;

    return Semantics(
      button: true,
      label: 'Category product ${product.name}',
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openProductDetail(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 128),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 78,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: product.hasPreview
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              categoryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _CategoryStatusPill(
                              label: product.hasPreview
                                  ? '360 preview ready'
                                  : statusLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                        _formatPrice(product.price),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(CatalogPrice price) {
    return '${price.currency} ${(price.amountCents / 100).toStringAsFixed(2)}';
  }
}

class _CategoryStatusPill extends StatelessWidget {
  const _CategoryStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _CategoryLoading extends StatelessWidget {
  const _CategoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _CategoryEmpty extends StatelessWidget {
  const _CategoryEmpty();

  @override
  Widget build(BuildContext context) {
    return const _CategoryMessageCard(text: 'No categories yet');
  }
}

class _CategoryProductsEmpty extends StatelessWidget {
  const _CategoryProductsEmpty();

  @override
  Widget build(BuildContext context) {
    return const _CategoryMessageCard(text: 'No products in this category');
  }
}

class _CategoryFailure extends StatelessWidget {
  const _CategoryFailure({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return _CategoryErrorCard(
      message: message ?? 'Categories are unavailable',
      onRetry: context.read<CategoryCubit>().loadCategories,
    );
  }
}

class _CategoryProductsFailure extends StatelessWidget {
  const _CategoryProductsFailure({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return _CategoryErrorCard(
      message: message ?? 'Category products are unavailable',
      onRetry: context.read<CategoryCubit>().retryProducts,
    );
  }
}

class _CategoryMessageCard extends StatelessWidget {
  const _CategoryMessageCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 168),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
  }
}

class _CategoryErrorCard extends StatelessWidget {
  const _CategoryErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
