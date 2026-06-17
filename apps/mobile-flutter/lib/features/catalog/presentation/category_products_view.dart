import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/get_catalog_product_detail.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/category_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/product_detail_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_detail_view.dart';
import 'package:lumin_studio_mobile/shared/widgets/product_card.dart';
import 'package:lumin_studio_mobile/shared/widgets/product_media_tile.dart';
import 'package:lumin_studio_mobile/shared/widgets/shimmer_box.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _categoryPreviewActivationDelay = Duration(seconds: 3);
const _categoryPreviewVisibilityThreshold = 0.8;

class CategoryProductsView extends StatefulWidget {
  const CategoryProductsView({required this.scrollKey, super.key});

  final PageStorageKey<String> scrollKey;

  @override
  State<CategoryProductsView> createState() => _CategoryProductsViewState();
}

class _CategoryProductsViewState extends State<CategoryProductsView> {
  late final ScrollController _scrollController;
  late final ValueNotifier<bool> _isScrolling;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _isScrolling = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _isScrolling.dispose();
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
              NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: _CategoryContent(
                  scrollKey: widget.scrollKey,
                  scrollController: _scrollController,
                  isScrolling: _isScrolling,
                  state: state,
                ),
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
    required this.isScrolling,
    required this.state,
  });

  final PageStorageKey<String> scrollKey;
  final ScrollController scrollController;
  final ValueListenable<bool> isScrolling;
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
          CategoryStatus.loading => const ShimmerProductList(itemCount: 4),
          CategoryStatus.empty => const _CategoryEmpty(),
          CategoryStatus.failure => _CategoryFailure(message: state.message),
          CategoryStatus.ready => _CategoryReady(
            isScrolling: isScrolling,
            state: state,
          ),
        },
      ],
    );
  }
}

class _CategoryReady extends StatelessWidget {
  const _CategoryReady({required this.isScrolling, required this.state});

  final ValueListenable<bool> isScrolling;
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
        const SizedBox(height: 16),
        _CategorySortControl(sort: state.sort),
        const SizedBox(height: 18),
        if (selected != null) ...[
          Text(
            selected.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
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
        const SizedBox(height: 14),
        switch (state.productsStatus) {
          CategoryProductsStatus.idle ||
          CategoryProductsStatus.loading => const ShimmerProductList(
            itemCount: 3,
          ),
          CategoryProductsStatus.empty => const _CategoryProductsEmpty(),
          CategoryProductsStatus.failure => _CategoryProductsFailure(
            message: state.productsMessage,
          ),
          CategoryProductsStatus.ready => _CategoryProductList(
            isScrolling: isScrolling,
            state: state,
          ),
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
                      color: theme.colorScheme.primary,
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
          Row(
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Sort products',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
  const _CategoryProductList({required this.isScrolling, required this.state});

  final ValueListenable<bool> isScrolling;
  final CategoryState state;

  @override
  Widget build(BuildContext context) {
    final products = state.products;
    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          _CategoryProductTile(
            product: products[i],
            isScrolling: isScrolling,
          ).animate().fadeIn(
            delay: (40 * i.clamp(0, 8)).ms,
            duration: 280.ms,
          ).slideY(
            begin: 0.12,
            end: 0,
            delay: (40 * i.clamp(0, 8)).ms,
            duration: 280.ms,
            curve: Curves.easeOutCubic,
          ),
          const SizedBox(height: 14),
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
        padding: EdgeInsets.symmetric(vertical: 16),
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
          borderRadius: BorderRadius.circular(LuminRadii.md),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
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

class _CategoryProductTile extends StatefulWidget {
  const _CategoryProductTile({
    required this.product,
    required this.isScrolling,
  });

  final CatalogProduct product;
  final ValueListenable<bool> isScrolling;

  @override
  State<_CategoryProductTile> createState() => _CategoryProductTileState();
}

class _CategoryProductTileState extends State<_CategoryProductTile> {
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
  void didUpdateWidget(_CategoryProductTile oldWidget) {
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
        _visibleFraction >= _categoryPreviewVisibilityThreshold;

    if (!canActivate) {
      _cancelPreview();
      return;
    }

    if (_previewActive || _activationTimer?.isActive == true) {
      return;
    }

    _activationTimer = Timer(_categoryPreviewActivationDelay, () {
      if (!mounted ||
          widget.product.spritePreviewUri == null ||
          _visibleFraction < _categoryPreviewVisibilityThreshold ||
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

  void _openProductDetail(BuildContext context) {
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

  void _quickAdd() {
    HapticFeedback.mediumImpact();
    context.read<CartCubit>().addCatalogProduct(widget.product);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${widget.product.name} added to cart'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final statusLabel = product.processingStatus.replaceAll('_', ' ');
    final categoryLabel = product.categories.isEmpty
        ? 'Category'
        : product.categories.first.name;

    return VisibilityDetector(
      key: ValueKey<String>('category-product-visibility-${product.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Semantics(
        button: true,
        label: 'Category product ${product.name}',
        child: ProductCard(
          media: ProductMediaTile(
            product: product,
            previewActive: _previewActive,
            spriteFrameKey: ValueKey<String>(
              'category-sprite-frame-${product.id}',
            ),
            subtlePreviewKey: ValueKey<String>(
              'category-subtle-preview-${product.id}',
            ),
            iconKey: ValueKey<String>('category-product-icon-${product.id}'),
          ),
          categoryLabel: categoryLabel,
          statusLabel: product.hasPreview ? '360 preview ready' : statusLabel,
          name: product.name,
          description: product.description,
          price: product.price,
          onTap: () => _openProductDetail(context),
          onQuickAdd: _quickAdd,
        ),
      ),
    );
  }
}

class _CategoryEmpty extends StatelessWidget {
  const _CategoryEmpty();

  @override
  Widget build(BuildContext context) {
    return const _CategoryMessageCard(
      icon: Icons.grid_view_outlined,
      text: 'No categories yet',
    );
  }
}

class _CategoryProductsEmpty extends StatelessWidget {
  const _CategoryProductsEmpty();

  @override
  Widget build(BuildContext context) {
    return const _CategoryMessageCard(
      icon: Icons.inventory_2_outlined,
      text: 'No products in this category',
    );
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
  const _CategoryMessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(LuminRadii.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 52,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ).animate().scale(
            delay: 120.ms,
            duration: 360.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        ],
      ),
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
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.error),
        borderRadius: BorderRadius.circular(LuminRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error),
          const SizedBox(height: 12),
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
