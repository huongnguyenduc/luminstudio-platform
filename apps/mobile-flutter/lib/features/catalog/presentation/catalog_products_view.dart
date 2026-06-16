import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';

class CatalogProductsView extends StatefulWidget {
  const CatalogProductsView({required this.scrollKey, super.key});

  final PageStorageKey<String> scrollKey;

  @override
  State<CatalogProductsView> createState() => _CatalogProductsViewState();
}

class _CatalogProductsViewState extends State<CatalogProductsView> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      context.read<CatalogCubit>().loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogCubit, CatalogState>(
      listener: (context, state) {
        if (_searchController.text != state.query) {
          _searchController.value = TextEditingValue(
            text: state.query,
            selection: TextSelection.collapsed(offset: state.query.length),
          );
        }
      },
      builder: (context, state) {
        return Semantics(
          label: 'Home catalog products',
          child: switch (state.status) {
            CatalogStatus.initial || CatalogStatus.loading => _CatalogScaffold(
              scrollKey: widget.scrollKey,
              scrollController: _scrollController,
              searchController: _searchController,
              child: const _CatalogLoading(),
            ),
            CatalogStatus.empty => _CatalogScaffold(
              scrollKey: widget.scrollKey,
              scrollController: _scrollController,
              searchController: _searchController,
              child: _CatalogEmpty(isSearching: state.isSearching),
            ),
            CatalogStatus.failure => _CatalogScaffold(
              scrollKey: widget.scrollKey,
              scrollController: _scrollController,
              searchController: _searchController,
              child: _CatalogFailure(
                message: state.message,
                isSearching: state.isSearching,
              ),
            ),
            CatalogStatus.ready => _CatalogList(
              scrollKey: widget.scrollKey,
              scrollController: _scrollController,
              searchController: _searchController,
              state: state,
            ),
          },
        );
      },
    );
  }
}

class _CatalogScaffold extends StatelessWidget {
  const _CatalogScaffold({
    required this.scrollKey,
    required this.scrollController,
    required this.searchController,
    required this.child,
  });

  final PageStorageKey<String> scrollKey;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: scrollKey,
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _CatalogSearchField(controller: searchController),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _CatalogSearchField extends StatelessWidget {
  const _CatalogSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CatalogCubit>();
    final isSearching = context.select<CatalogCubit, bool>(
      (cubit) => cubit.state.isSearching,
    );

    return SearchBar(
      controller: controller,
      leading: const Icon(Icons.search),
      hintText: 'Search products',
      constraints: const BoxConstraints(minHeight: 56),
      textInputAction: TextInputAction.search,
      onSubmitted: cubit.searchProducts,
      trailing: [
        if (isSearching)
          IconButton(
            tooltip: 'Clear search',
            onPressed: cubit.clearSearch,
            icon: const Icon(Icons.close),
          ),
      ],
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
  const _CatalogEmpty({required this.isSearching});

  final bool isSearching;

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
      child: Text(
        isSearching ? 'No matching products' : 'No catalog products yet',
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}

class _CatalogFailure extends StatelessWidget {
  const _CatalogFailure({required this.message, required this.isSearching});

  final String? message;
  final bool isSearching;

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
            message ?? 'Catalog is unavailable',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              final cubit = context.read<CatalogCubit>();
              if (isSearching) {
                cubit.searchProducts(cubit.state.query);
              } else {
                cubit.loadProducts();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({
    required this.scrollKey,
    required this.scrollController,
    required this.searchController,
    required this.state,
  });

  final PageStorageKey<String> scrollKey;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final products = state.products;

    return ListView.separated(
      key: scrollKey,
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CatalogSearchField(controller: searchController);
        }
        if (index == products.length + 1) {
          return _CatalogPaginationFooter(state: state);
        }
        return _CatalogProductTile(product: products[index - 1]);
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemCount: products.length + 2,
    );
  }
}

class _CatalogPaginationFooter extends StatelessWidget {
  const _CatalogPaginationFooter({required this.state});

  final CatalogState state;

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
                onPressed: context.read<CatalogCubit>().loadMoreProducts,
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
            state.isSearching
                ? 'All search results loaded'
                : 'All products loaded',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Center(
      child: TextButton.icon(
        onPressed: context.read<CatalogCubit>().loadMoreProducts,
        icon: const Icon(Icons.expand_more),
        label: const Text('Load more'),
      ),
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
