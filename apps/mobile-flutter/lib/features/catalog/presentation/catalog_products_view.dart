import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/get_catalog_product_detail.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/product_detail_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_detail_view.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/shared/widgets/product_card.dart';
import 'package:lumin_studio_mobile/shared/widgets/product_media_tile.dart';
import 'package:lumin_studio_mobile/shared/widgets/shimmer_box.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _previewActivationDelay = Duration(seconds: 2);
const _previewVisibilityThreshold = 0.8;

/// Wraps a list tile in a one-shot fade/slide entrance. Returns the child
/// unchanged once entrance animations have been latched off (see
/// [_CatalogProductsViewState._entranceAnimated]) so rebuilds don't re-stutter.
Widget _maybeAnimateEntrance({
  required int index,
  required bool animate,
  required Widget child,
}) {
  if (!animate) {
    return child;
  }
  final delay = (40 * index.clamp(0, 8)).ms;
  return child
      .animate()
      .fadeIn(delay: delay, duration: 280.ms)
      .slideY(
        begin: 0.12,
        end: 0,
        delay: delay,
        duration: 280.ms,
        curve: Curves.easeOutCubic,
      );
}

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

  /// Product IDs whose entrance (fade/slide) animation has already played. A
  /// tile animates once, when it first appears; on later rebuilds (search
  /// keystrokes, pagination, scroll, cart changes) the same IDs are skipped so
  /// the list doesn't visibly re-stutter — while genuinely new results (a fresh
  /// search, the next page) still animate in.
  final Set<String> _animatedIds = <String>{};

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
        if (state.status == CatalogStatus.ready) {
          final ids = [for (final product in state.products) product.id];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animatedIds.addAll(ids);
          });
        }
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
                child: const ShimmerProductList(itemCount: 4),
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
                animatedIds: _animatedIds,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const _HomeHero(),
        const SizedBox(height: 18),
        _CatalogSearchField(controller: searchController),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        gradient: context.gradients.hero,
        borderRadius: BorderRadius.circular(LuminRadii.xl),
        boxShadow: LuminShadows.glow(theme.colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'WELCOME TO LUMIN',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Discover premium\n3D assets',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Spin, customize and collect studio-grade models.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip(icon: Icons.threesixty, label: '360° preview'),
              _HeroChip(icon: Icons.palette_outlined, label: 'Customizable'),
              _HeroChip(icon: Icons.bolt, label: 'New drops'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(LuminRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 220),
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
            isSearching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 52,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ).animate().scale(
            delay: 120.ms,
            duration: 360.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'No matching products' : 'No catalog products yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (isSearching) ...[
            const SizedBox(height: 6),
            Text(
              'Try a different search term.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
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
    required this.animatedIds,
  });

  final PageStorageKey<String> scrollKey;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueListenable<bool> isScrolling;
  final CatalogState state;
  final Set<String> animatedIds;

  @override
  Widget build(BuildContext context) {
    final products = state.products;
    final theme = Theme.of(context);

    return ListView(
      key: scrollKey,
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HomeHero(),
            const SizedBox(height: 18),
            _CatalogSearchField(controller: searchController),
            const SizedBox(height: 16),
            Text(
              state.isSearching
                  ? '${products.length} matching products'
                  : 'Browse ${products.length} products',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < products.length; i++) ...[
              _maybeAnimateEntrance(
                index: i,
                animate: !animatedIds.contains(products[i].id),
                child: _CatalogProductTile(
                  product: products[i],
                  isScrolling: isScrolling,
                ),
              ),
              const SizedBox(height: 14),
            ],
            _CatalogPaginationFooter(state: state),
          ],
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 16),
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

    // Warm the sprite sheet during the dwell window so the 360 swing starts
    // instantly instead of flashing an empty tile while it decodes for the
    // first time — at rest only the description image is mounted, so the sprite
    // is otherwise fetched only at swap time.
    final previewUri = widget.product.spritePreviewUri;
    if (previewUri != null) {
      // Best-effort cache warm; the sprite widget has its own errorBuilder and
      // an unhandled image error would otherwise surface as a test failure.
      precacheImage(
        NetworkImage(previewUri.toString()),
        context,
        onError: (_, __) {},
      );
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
        ? 'Catalog'
        : product.categories.first.name;

    return VisibilityDetector(
      key: ValueKey<String>('catalog-product-visibility-${product.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Semantics(
        button: true,
        label: 'Catalog product ${product.name}',
        child: ProductCard(
          media: ProductMediaTile(
            product: product,
            previewActive: _previewActive,
            spriteFrameKey: ValueKey<String>('sprite-frame-${product.id}'),
            subtlePreviewKey: ValueKey<String>('subtle-preview-${product.id}'),
            descriptionImageKey: ValueKey<String>(
              'description-image-${product.id}',
            ),
            iconKey: ValueKey<String>('product-icon-${product.id}'),
          ),
          categoryLabel: categoryLabel,
          statusLabel: product.hasPreview ? null : statusLabel,
          name: product.name,
          description: product.description,
          price: product.price,
          onTap: _openProductDetail,
          onQuickAdd: _quickAdd,
        ),
      ),
    );
  }
}
