import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _previewActivationDelay = Duration(seconds: 3);
const _previewVisibilityThreshold = 0.8;
const _spriteFrameCount = 24;
const _spriteColumns = 6;
const _spriteRows = 4;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final statusLabel = product.processingStatus.replaceAll('_', ' ');
    final previewUri = product.spritePreviewUri;

    return VisibilityDetector(
      key: ValueKey<String>('catalog-product-visibility-${product.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Semantics(
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
                width: 64,
                height: 64,
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: product.hasPreview
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _previewActive && previewUri != null
                      ? _SpriteSheetPreview(
                          key: ValueKey<String>('preview-${product.id}'),
                          uri: previewUri,
                          productName: product.name,
                        )
                      : Icon(
                          product.hasPreview
                              ? Icons.view_in_ar
                              : Icons.view_in_ar_outlined,
                          color: theme.colorScheme.primary,
                        ),
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
      ),
    );
  }
}

class _SpriteSheetPreview extends StatefulWidget {
  const _SpriteSheetPreview({
    required this.uri,
    required this.productName,
    super.key,
  });

  final Uri uri;
  final String productName;

  @override
  State<_SpriteSheetPreview> createState() => _SpriteSheetPreviewState();
}

class _SpriteSheetPreviewState extends State<_SpriteSheetPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      image: true,
      label: '360 preview active for ${widget.productName}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              child: Image.network(
                widget.uri.toString(),
                width: width * _spriteColumns,
                height: height * _spriteRows,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              builder: (context, child) {
                final frame =
                    (_controller.value * _spriteFrameCount).floor() %
                    _spriteFrameCount;
                final column = frame % _spriteColumns;
                final row = frame ~/ _spriteColumns;

                return Transform.translate(
                  offset: Offset(-width * column, -height * row),
                  child: child,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
