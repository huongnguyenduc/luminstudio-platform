import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/product_detail_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_model_viewer.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:lumin_studio_mobile/shared/format/money.dart';
import 'package:lumin_studio_mobile/shared/widgets/animated_counter.dart';
import 'package:lumin_studio_mobile/shared/widgets/cart_badge_icon.dart';
import 'package:lumin_studio_mobile/shared/widgets/discount_badge.dart';
import 'package:lumin_studio_mobile/shared/widgets/fly_to_cart.dart';
import 'package:lumin_studio_mobile/shared/widgets/price_tag.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final GlobalKey _cartIconKey = GlobalKey();

  void _openCart() {
    context.read<ShellCubit>().selectTab(CustomerTab.cart);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartCubit, CartState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(state.message ?? 'Cart updated')),
          );
      },
      child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          final title = state.detail?.name ?? 'Product detail';

          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _DetailCartAction(
                    badgeKey: _cartIconKey,
                    onTap: _openCart,
                  ),
                ),
              ],
            ),
            body: switch (state.status) {
              ProductDetailStatus.initial ||
              ProductDetailStatus.loading => const _ProductDetailLoading(),
              ProductDetailStatus.failure => _ProductDetailFailure(
                message: state.message,
              ),
              ProductDetailStatus.ready => _ProductDetailReady(
                detail: state.detail!,
                selectedMeshColors: state.selectedMeshColors,
              ),
            },
            bottomNavigationBar: state.status == ProductDetailStatus.ready
                ? _ProductDetailBottomBar(
                    detail: state.detail!,
                    selectedMeshColors: state.selectedMeshColors,
                    cartIconKey: _cartIconKey,
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _DetailCartAction extends StatelessWidget {
  const _DetailCartAction({required this.badgeKey, required this.onTap});

  final GlobalKey badgeKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartCubit, int>(
      (cubit) => cubit.state.totalQuantity,
    );
    return IconButton(
      tooltip: 'View cart',
      onPressed: onTap,
      icon: CartBadgeIcon(
        icon: Icons.shopping_bag_outlined,
        count: count,
        badgeKey: badgeKey,
      ),
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
  const _ProductDetailReady({
    required this.detail,
    required this.selectedMeshColors,
  });

  final CatalogProductDetail detail;
  final Map<String, String> selectedMeshColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = discountPercent(
      detail.price.amountCents,
      detail.price.compareAtAmountCents,
    );

    return Semantics(
      label: 'Product detail for ${detail.name}',
      child: ListView(
        key: const PageStorageKey<String>('product-detail-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
        children: [
          _InteractiveModelPanel(detail: detail)
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 14),
          _ProductModelMetadata(detail: detail),
          const SizedBox(height: 16),
          Text(detail.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PriceTag(
                amountCents: detail.price.amountCents,
                currency: detail.price.currency,
                compareAtAmountCents: detail.price.compareAtAmountCents,
                priceKey: const ValueKey<String>('product-detail-price'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (percent != null) DiscountBadge(percent: percent),
            ],
          ),
          if (detail.meshColorConfig.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Customize color', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a finish before adding this item to your cart.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final options in detail.meshColorConfig) ...[
              _MeshColorOptions(
                options: options,
                selectedColor:
                    selectedMeshColors[options.meshId] ?? options.defaultColor,
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 18),
          Text(detail.description, style: theme.textTheme.bodyLarge),
          if (detail.informationSections.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Product information', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final section in detail.informationSections) ...[
              _InformationSection(section: section),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _InteractiveModelPanel extends StatelessWidget {
  const _InteractiveModelPanel({required this.detail});

  final CatalogProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelViewerBuilder = context.read<ProductModelViewerBuilder>();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final panelHeight = (screenHeight * 0.32).clamp(200.0, 360.0);

    return Container(
      decoration: BoxDecoration(
        gradient: context.gradients.mediaBackdrop,
        borderRadius: BorderRadius.circular(LuminRadii.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: LuminShadows.card(theme.brightness),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              key: ValueKey<String>('product-model-panel-${detail.id}'),
              height: panelHeight,
              width: double.infinity,
              child: modelViewerBuilder(context, detail),
            ),
          ),
          if (detail.spriteUri != null)
            Positioned(
              top: 14,
              left: 14,
              child: _GlassPill(
                icon: Icons.threesixty,
                label: '360°',
              ),
            ),
          if (detail.modelUri != null)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Center(
                child: _GlassPill(
                  icon: Icons.touch_app_outlined,
                  label: 'Drag to rotate',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(LuminRadii.pill),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductModelMetadata extends StatelessWidget {
  const _ProductModelMetadata({required this.detail});

  final CatalogProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <String>[
      '${detail.modelTier.wireName.toUpperCase()} model',
      if (detail.spriteUri != null) '360 ready',
      if (detail.categories.isNotEmpty) detail.categories.first.name,
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.view_in_ar, size: 16, color: theme.colorScheme.primary),
        for (var index = 0; index < items.length; index++) ...[
          Text(
            items[index],
            key: index == 0
                ? const ValueKey<String>('product-detail-model-tier')
                : null,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (index != items.length - 1)
            Text(
              '/',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ],
    );
  }
}

class _ProductDetailBottomBar extends StatefulWidget {
  const _ProductDetailBottomBar({
    required this.detail,
    required this.selectedMeshColors,
    required this.cartIconKey,
  });

  final CatalogProductDetail detail;
  final Map<String, String> selectedMeshColors;
  final GlobalKey cartIconKey;

  @override
  State<_ProductDetailBottomBar> createState() =>
      _ProductDetailBottomBarState();
}

class _ProductDetailBottomBarState extends State<_ProductDetailBottomBar> {
  final GlobalKey _addButtonKey = GlobalKey();
  int _quantity = 1;

  void _setQuantity(int value) {
    final next = value < 1 ? 1 : value;
    if (next != _quantity) {
      HapticFeedback.selectionClick();
      setState(() => _quantity = next);
    }
  }

  void _addToCart() {
    HapticFeedback.mediumImpact();
    context.read<CartCubit>().addProduct(
      widget.detail,
      widget.selectedMeshColors,
      quantity: _quantity,
    );
    _runFlyToCart();
    setState(() => _quantity = 1);
  }

  void _runFlyToCart() {
    final start = globalRectOf(_addButtonKey);
    final end = globalRectOf(widget.cartIconKey);
    if (start == null || end == null) {
      return;
    }
    flyToCart(
      context: context,
      startRect: start,
      endRect: end,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: context.gradients.brand,
          shape: BoxShape.circle,
          boxShadow: LuminShadows.glow(Theme.of(context).colorScheme.primary),
        ),
        child: const Icon(
          Icons.view_in_ar,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = _selectedChoiceLabels(
      widget.detail,
      widget.selectedMeshColors,
    ).join(' · ');
    final lineTotal = widget.detail.price.amountCents * _quantity;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: LuminShadows.card(theme.brightness),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PriceTag(
                          amountCents: lineTotal,
                          currency: widget.detail.price.currency,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          selectedLabel.isEmpty
                              ? 'Ready to add'
                              : 'Selected $selectedLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _QuantityStepper(
                    quantity: _quantity,
                    onChanged: _setQuantity,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: BlocBuilder<CartCubit, CartState>(
                  builder: (context, cartState) {
                    return FilledButton.icon(
                      key: const ValueKey<String>(
                        'add-selected-product-to-cart',
                      ),
                      onPressed: cartState.isMutating ? null : _addToCart,
                      icon: Icon(Icons.add_shopping_cart, key: _addButtonKey),
                      label: const Text('Add to cart'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.7,
        ),
        borderRadius: BorderRadius.circular(LuminRadii.pill),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 40,
            child: Center(
              child: AnimatedCounter(
                count: quantity,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add),
          ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(LuminRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            section.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _selectedChoiceLabels(
  CatalogProductDetail detail,
  Map<String, String> selectedMeshColors,
) {
  return [
    for (final options in detail.meshColorConfig)
      _selectedChoiceLabel(
        options,
        selectedMeshColors[options.meshId] ?? options.defaultColor,
      ),
  ];
}

String _selectedChoiceLabel(CatalogMeshColorOptions options, String color) {
  return '${_friendlyMeshName(options.meshId)} ${_finishNameForOptions(options, color)}';
}

String _finishNameForOptions(CatalogMeshColorOptions options, String color) {
  return options.labelForColor(color) ?? _finishNameForColor(color);
}

String _friendlyMeshName(String meshId) {
  final normalized = meshId
      .replaceFirst(RegExp('^mesh_'), '')
      .replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return meshId;
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

class _MeshColorOptions extends StatelessWidget {
  const _MeshColorOptions({required this.options, required this.selectedColor});

  final CatalogMeshColorOptions options;
  final String selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(LuminRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _friendlyMeshName(options.meshId),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _selectedChoiceLabel(options, selectedColor),
            key: ValueKey<String>('selected-finish-${options.meshId}'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in options.allowedColors)
                _ColorSwatch(
                  options: options,
                  meshId: options.meshId,
                  color: color,
                  isDefault: color == options.defaultColor,
                  isSelected: color == selectedColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.options,
    required this.meshId,
    required this.color,
    required this.isDefault,
    required this.isSelected,
  });

  final CatalogMeshColorOptions options;
  final String meshId;
  final String color;
  final bool isDefault;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parseHexColor(color);
    final swatchColor = parsed == null
        ? theme.colorScheme.surface
        : Color(0xFF000000 | parsed);
    final iconColor = _iconColorFor(swatchColor);
    final meshName = _friendlyMeshName(meshId);
    final finishName = _finishNameForOptions(options, color);
    final label =
        '$meshName $finishName${isDefault ? ' default' : ''}${isSelected ? ' selected' : ''}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: ValueKey<String>('mesh-color-$meshId-$color'),
          borderRadius: BorderRadius.circular(LuminRadii.sm),
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<ProductDetailCubit>().selectMeshColor(meshId, color);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: swatchColor,
              borderRadius: BorderRadius.circular(LuminRadii.sm),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? LuminShadows.glow(theme.colorScheme.primary)
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check, size: 20, color: iconColor)
                : null,
          ),
        ),
      ),
    );
  }

  int? _parseHexColor(String value) {
    final normalized = value.startsWith('#') ? value.substring(1) : value;
    if (normalized.length != 6) {
      return null;
    }
    return int.tryParse(normalized, radix: 16);
  }

  Color _iconColorFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

String _finishNameForColor(String value) {
  switch (value.toUpperCase()) {
    case '#FFFFFF':
      return 'Porcelain white';
    case '#F8FAFC':
      return 'Soft white';
    case '#E5E7EB':
      return 'Mist grey';
    case '#CBD5E1':
      return 'Cloud grey';
    case '#94A3B8':
      return 'Slate grey';
    case '#64748B':
      return 'Storm grey';
    case '#475569':
      return 'Smoke grey';
    case '#334155':
      return 'Charcoal slate';
    case '#1F2937':
      return 'Graphite';
    case '#0F172A':
      return 'Midnight navy';
    case '#111827':
      return 'Ink black';
    case '#000000':
      return 'Black';
    case '#F5E6D3':
      return 'Warm linen';
    case '#D6B98C':
      return 'Natural oak';
    case '#B45309':
      return 'Cognac';
    case '#92400E':
      return 'Saddle brown';
    case '#78350F':
      return 'Walnut';
    case '#F59E0B':
      return 'Amber';
    case '#D97706':
      return 'Burnished brass';
    case '#16A34A':
      return 'Garden green';
    case '#0F766E':
      return 'Deep teal';
    case '#2563EB':
      return 'Cobalt blue';
    case '#7C3AED':
      return 'Violet';
    case '#DC2626':
      return 'Signal red';
    default:
      return 'Custom finish';
  }
}
