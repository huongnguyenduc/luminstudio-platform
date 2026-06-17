import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/catalog_sprite_preview.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:lumin_studio_mobile/shared/api/product_image_endpoints.dart';
import 'package:lumin_studio_mobile/shared/format/color_finish.dart';
import 'package:lumin_studio_mobile/shared/format/money.dart';
import 'package:lumin_studio_mobile/shared/widgets/animated_counter.dart';
import 'package:lumin_studio_mobile/shared/widgets/product_thumbnail_image.dart';
import 'package:lumin_studio_mobile/shared/widgets/shimmer_box.dart';

class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        return switch (state.status) {
          CartStatus.initial || CartStatus.loading => const _CartLoading(),
          CartStatus.failure => const _CartFailure(),
          CartStatus.ready =>
            state.items.isEmpty ? const _EmptyCart() : _CartReady(state: state),
        };
      },
    );
  }
}

class _CartLoading extends StatelessWidget {
  const _CartLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const ShimmerBox(width: double.infinity, height: 132, borderRadius: 20),
        const SizedBox(height: 14),
        for (var i = 0; i < 2; i++) ...[
          Container(
            height: 168,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(LuminRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 180, height: 20, borderRadius: 6),
                SizedBox(height: 10),
                ShimmerBox(width: 90, height: 16, borderRadius: 6),
                Spacer(),
                ShimmerBox(width: 130, height: 36, borderRadius: 18),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _CartFailure extends StatelessWidget {
  const _CartFailure();

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
              'Cart is unavailable',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: context.read<CartCubit>().load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Cart empty state',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: context.gradients.mediaBackdrop,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
              ).animate().scale(
                duration: 380.ms,
                curve: Curves.easeOutBack,
              ),
              const SizedBox(height: 22),
              Text(
                'Your cart is empty',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Browse the catalog to find studio-grade 3D assets for your next project.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () {
                  context.read<ShellCubit>().selectTab(CustomerTab.home);
                },
                icon: const Icon(Icons.storefront),
                label: const Text('Start shopping'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ),
      ),
    );
  }
}

class _CartReady extends StatelessWidget {
  const _CartReady({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cart with ${state.totalQuantity} items',
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              key: const PageStorageKey<String>('cart-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _DismissibleCartItem(
                  item: item,
                  itemIndex: index,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemCount: state.items.length,
            ),
          ),
          // Summary + checkout stay pinned so totals remain visible while the
          // item list scrolls, and cart mutations no longer reflow the items.
          _CartCheckoutBar(state: state),
        ],
      ),
    );
  }
}

/// Removes [item] (at [index]) from the cart and offers an undo.
void _removeCartItemWithUndo(BuildContext context, CartItem item, int index) {
  HapticFeedback.mediumImpact();
  final cubit = context.read<CartCubit>();
  cubit.removeProduct(item.productId);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${item.productName} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => cubit.restoreItem(item, index),
        ),
      ),
    );
}

/// Pinned bottom bar showing the selected totals and a checkout action so the
/// summary stays visible while the cart item list scrolls.
class _CartCheckoutBar extends StatelessWidget {
  const _CartCheckoutBar({required this.state});

  final CartState state;

  void _checkout(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Checkout is coming soon')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = state.selectedTotals;
    final hasSelection = state.selectedQuantity > 0;

    return Container(
      key: const ValueKey<String>('cart-summary'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: LuminShadows.card(theme.brightness),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delayed sync strip in a fixed-height slot: it only appears when a
            // save genuinely lags, so the common fast (optimistic) save never
            // flickers the bar on every tap.
            _CartSyncStrip(isMutating: state.isMutating),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtotal · ${state.selectedQuantity} selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (totals != null) ...[
                          Text(
                            formatMoney(totals.subtotalCents, totals.currency),
                            key: const ValueKey<String>('cart-subtotal'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (totals.savingsCents > 0)
                            Text(
                              'Save ${formatMoney(totals.savingsCents, totals.currency)}',
                              key: const ValueKey<String>('cart-savings'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ] else
                          Text(
                            hasSelection
                                ? 'Mixed currencies'
                                : 'Select items to checkout',
                            key: hasSelection
                                ? const ValueKey<String>('cart-mixed-currency')
                                : null,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  FilledButton.icon(
                    key: const ValueKey<String>('cart-checkout-button'),
                    onPressed: hasSelection ? () => _checkout(context) : null,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Checkout'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
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

/// Thin sync indicator pinned to the top of the checkout bar. It lives in a
/// fixed-height slot (so it never reflows the bar) and only reveals the
/// progress line once a save has been pending past [_revealDelay] — fast
/// optimistic saves complete first and never flash the indicator.
class _CartSyncStrip extends StatefulWidget {
  const _CartSyncStrip({required this.isMutating});

  final bool isMutating;

  @override
  State<_CartSyncStrip> createState() => _CartSyncStripState();
}

class _CartSyncStripState extends State<_CartSyncStrip> {
  static const _revealDelay = Duration(milliseconds: 320);

  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_CartSyncStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMutating != widget.isMutating) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    if (widget.isMutating) {
      _timer = Timer(_revealDelay, () {
        if (mounted) {
          setState(() => _visible = true);
        }
      });
    } else if (_visible) {
      _visible = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 3,
      child: _visible
          ? LinearProgressIndicator(
              key: const ValueKey<String>('cart-sync-progress'),
              minHeight: 3,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Wraps a cart item in a swipe-to-remove gesture with an undo affordance.
class _DismissibleCartItem extends StatelessWidget {
  const _DismissibleCartItem({
    required this.item,
    required this.itemIndex,
  });

  final CartItem item;
  final int itemIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey<String>('cart-dismiss-${item.productId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(LuminRadii.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: theme.colorScheme.onError),
            const SizedBox(width: 8),
            Text(
              'Remove',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _removeCartItemWithUndo(context, item, itemIndex),
      child: _CartItemTile(
        item: item,
        itemIndex: itemIndex,
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.itemIndex,
  });

  final CartItem item;
  final int itemIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: ValueKey<String>('cart-item-${item.productId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(LuminRadii.md),
        boxShadow: LuminShadows.card(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.isSelected,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  context.read<CartCubit>().toggleSelection(
                    item.productId,
                    value ?? false,
                  );
                },
              ),
              const SizedBox(width: 4),
              _CartItemThumbnail(
                productId: item.productId,
                productName: item.productName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${formatMoney(item.amountCents, item.currency)} each',
                      key: ValueKey<String>('cart-price-${item.productId}'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey<String>('cart-remove-${item.productId}'),
                tooltip: 'Remove ${item.productId} from cart',
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.error,
                onPressed: () =>
                    _removeCartItemWithUndo(context, item, itemIndex),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (item.selectedColors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in item.selectedColors.entries)
                  _CartColorChip(
                    key: ValueKey<String>(
                      'cart-color-${item.productId}-${color.key}-${color.value}',
                    ),
                    name: color.key,
                    value: color.value,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Quantity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.70,
                  ),
                  borderRadius: BorderRadius.circular(LuminRadii.pill),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Decrease ${item.productId} quantity',
                      onPressed: item.quantity > 1
                          ? () {
                              HapticFeedback.selectionClick();
                              context.read<CartCubit>().decrement(
                                item.productId,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: AnimatedCounter(
                          key: ValueKey<String>('cart-qty-${item.productId}'),
                          count: item.quantity,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase ${item.productId} quantity',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.read<CartCubit>().increment(item.productId);
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Leading description-image thumbnail for a cart line. The cart only knows a
/// product id, so the URL is built from the API base; products without a
/// description image fall back to a 3D icon.
class _CartItemThumbnail extends StatelessWidget {
  const _CartItemThumbnail({required this.productId, required this.productName});

  final String productId;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final endpoints = context.read<ProductImageEndpoints>();

    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuminRadii.md),
        child: ProductThumbnailImage(
          uri: endpoints.descriptionImage(productId),
          productName: productName,
          // Products without a description image (e.g. Skadis Desk Mount, Pet
          // Tag) still ship a 360 sprite, so lead with its first frame before
          // dropping to the 3D icon — matching the catalog cards.
          fallback: CatalogSpriteFrame(
            uri: endpoints.sprite(productId),
            productName: productName,
          ),
        ),
      ),
    );
  }
}

class _CartColorChip extends StatelessWidget {
  const _CartColorChip({
    required super.key,
    required this.name,
    required this.value,
  });

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _parseHexColor(value);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.52,
        ),
        borderRadius: BorderRadius.circular(LuminRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color ?? theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(width: 8),
            Text('${_friendlyMeshName(name)}: ${finishNameForHex(value)}'),
          ],
        ),
      ),
    );
  }

  Color? _parseHexColor(String raw) {
    final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    if (normalized.length != 6) {
      return null;
    }
    final value = int.tryParse(normalized, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
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
