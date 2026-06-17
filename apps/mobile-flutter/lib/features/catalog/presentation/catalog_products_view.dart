import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/get_catalog_product_detail.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/catalog_sprite_preview.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/product_detail_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_detail_view.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _previewActivationDelay = Duration(seconds: 3);
const _previewVisibilityThreshold = 0.8;

class CatalogProductsView extends StatefulWidget {
  const CatalogProductsView({required this.scrollKey, super.key});

  final PageStorageKey<String> scrollKey;

  @override
  State<CatalogProductsView> createState() => _CatalogProductsViewState();
}

class _CatalogProductsViewState extends State<CatalogProductsView> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final ValueNotifier<bool> _isScrolling;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_loadMoreNearEnd);
    _isScrolling = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    _isScrolling.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _setScrolling(true);
    } else if (notification is ScrollEndNotification ||
        notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
      _setScrolling(false);
    }
    return false;
  }

  void _setScrolling(bool value) {
    if (_isScrolling.value != value) {
      _isScrolling.value = value;
    }
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
        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Semantics(
            label: 'Home catalog products',
            child: switch (state.status) {
              CatalogStatus.initial ||
              CatalogStatus.loading => _CatalogScaffold(
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
                isScrolling: _isScrolling,
                state: state,
              ),
            },
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
    required this.isScrolling,
    required this.state,
  });

  final PageStorageKey<String> scrollKey;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueListenable<bool> isScrolling;
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final products = state.products;
    final theme = Theme.of(context);

    return ListView.separated(
      key: scrollKey,
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CatalogSearchField(controller: searchController),
              const SizedBox(height: 12),
              Text(
                state.isSearching
                    ? '${products.length} matching products'
                    : 'Browse ${products.length} products',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
        if (index == products.length + 1) {
          return _CatalogPaginationFooter(state: state);
        }
        return _CatalogProductTile(
          product: products[index - 1],
          isScrolling: isScrolling,
        );
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

class _CatalogProductTile extends StatefulWidget {
  const _CatalogProductTile({required this.product, required this.isScrolling});

  final CatalogProduct product;
  final ValueListenable<bool> isScrolling;

  @override
  State<_CatalogProductTile> createState() => _CatalogProductTileState();
}

class _CatalogProductTileState extends State<_CatalogProductTile> {
  Timer? _activationTimer;
  double _visibleFraction = 0;
  bool _previewActive = false;

  @override
  void initState() {
    super.initState();
    widget.isScrolling.addListener(_handleScrollStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshMeasuredVisibility();
    });
  }

  @override
  void didUpdateWidget(_CatalogProductTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isScrolling != widget.isScrolling) {
      oldWidget.isScrolling.removeListener(_handleScrollStateChanged);
      widget.isScrolling.addListener(_handleScrollStateChanged);
    }
    if (oldWidget.product.id != widget.product.id) {
      _cancelPreview();
      _visibleFraction = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshMeasuredVisibility();
      });
    }
  }

  @override
  void dispose() {
    widget.isScrolling.removeListener(_handleScrollStateChanged);
    _activationTimer?.cancel();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) {
      return;
    }

    final measuredFraction = _measureVisibleFraction();
    _visibleFraction = measuredFraction == null
        ? info.visibleFraction
        : measuredFraction > info.visibleFraction
        ? measuredFraction
        : info.visibleFraction;
    _syncPreviewActivation();
  }

  void _refreshMeasuredVisibility() {
    if (!mounted) {
      return;
    }

    final fraction = _measureVisibleFraction();
    if (fraction != null) {
      _visibleFraction = fraction;
    }
    _syncPreviewActivation();
  }

  double? _measureVisibleFraction() {
    final renderObject = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final viewportObject = scrollable?.context.findRenderObject();

    if (renderObject is! RenderBox ||
        viewportObject is! RenderBox ||
        !renderObject.hasSize ||
        !viewportObject.hasSize) {
      return null;
    }

    final itemRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final viewportRect =
        viewportObject.localToGlobal(Offset.zero) & viewportObject.size;
    final visibleRect = itemRect.intersect(viewportRect);
    if (visibleRect.isEmpty || itemRect.width == 0 || itemRect.height == 0) {
      return 0;
    }

    return (visibleRect.width * visibleRect.height) /
        (itemRect.width * itemRect.height);
  }

  void _syncPreviewActivation() {
    if (widget.isScrolling.value) {
      _cancelPreview();
      return;
    }

    final canActivate =
        widget.product.spritePreviewUri != null &&
        _visibleFraction >= _previewVisibilityThreshold;

    if (!canActivate) {
      _cancelPreview();
      return;
    }

    if (_previewActive || _activationTimer?.isActive == true) {
      return;
    }

    _activationTimer = Timer(_previewActivationDelay, () {
      if (!mounted ||
          widget.product.spritePreviewUri == null ||
          _visibleFraction < _previewVisibilityThreshold ||
          widget.isScrolling.value) {
        return;
      }
      setState(() {
        _previewActive = true;
      });
    });
  }

  void _cancelPreview() {
    _activationTimer?.cancel();
    _activationTimer = null;
    if (_previewActive && mounted) {
      setState(() {
        _previewActive = false;
      });
    }
  }

  void _handleScrollStateChanged() {
    if (widget.isScrolling.value) {
      _cancelPreview();
      return;
    }
    _refreshMeasuredVisibility();
  }

  void _openProductDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlocProvider(
          create: (context) => ProductDetailCubit(
            productId: widget.product.id,
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
    final product = widget.product;
    final statusLabel = product.processingStatus.replaceAll('_', ' ');
    final previewUri = product.spritePreviewUri;
    final categoryLabel = product.categories.isEmpty
        ? 'Catalog'
        : product.categories.first.name;

    return VisibilityDetector(
      key: ValueKey<String>('catalog-product-visibility-${product.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Semantics(
        button: true,
        label: 'Catalog product ${product.name}',
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _openProductDetail,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 156),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductMediaTile(
                    product: product,
                    previewActive: _previewActive,
                    previewUri: previewUri,
                  ),
                  const SizedBox(width: 16),
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
                              child: _ProductStatusPill(
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
                            fontWeight: FontWeight.w800,
                            height: 1.08,
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _formatMoney(
                                product.price.amountCents,
                                product.price.currency,
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'View details',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductMediaTile extends StatelessWidget {
  const _ProductMediaTile({
    required this.product,
    required this.previewActive,
    required this.previewUri,
  });

  final CatalogProduct product;
  final bool previewActive;
  final Uri? previewUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 96,
      height: 112,
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: product.hasPreview
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.74)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: 0.40),
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: product.hasPreview && previewUri != null
                  ? SizedBox.square(
                      key: ValueKey<String>(
                        previewActive
                            ? 'subtle-preview-${product.id}'
                            : 'sprite-frame-${product.id}',
                      ),
                      dimension: 86,
                      child: previewActive
                          ? CatalogSubtleSpritePreview(
                              uri: previewUri!,
                              productName: product.name,
                            )
                          : CatalogSpriteFrame(
                              uri: previewUri!,
                              productName: product.name,
                            ),
                    )
                  : Icon(
                      key: ValueKey<String>('product-icon-${product.id}'),
                      product.hasPreview
                          ? Icons.view_in_ar
                          : Icons.view_in_ar_outlined,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          if (product.hasPreview)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
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

class _ProductStatusPill extends StatelessWidget {
  const _ProductStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

String _formatMoney(int cents, String currency) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$currency $whole.$fraction';
}
