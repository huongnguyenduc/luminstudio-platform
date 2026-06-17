import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:lumin_studio_mobile/shared/format/money.dart';
import 'package:lumin_studio_mobile/shared/widgets/animated_counter.dart';
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
      child: ListView.separated(
        key: const PageStorageKey<String>('cart-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CartSummary(state: state);
          }

          final itemIndex = index - 1;
          final item = state.items[itemIndex];
          return _DismissibleCartItem(
            item: item,
            itemIndex: itemIndex,
            isMutating: state.isMutating,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemCount: state.items.length + 1,
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = state.selectedTotals;

    return Container(
      key: const ValueKey<String>('cart-summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: context.gradients.hero,
        borderRadius: BorderRadius.circular(LuminRadii.lg),
        boxShadow: LuminShadows.glow(theme.colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(LuminRadii.sm),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.shopping_bag, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cart summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${state.totalQuantity} in cart, ${state.selectedQuantity} selected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totals != null) ...[
            const SizedBox(height: 18),
            Text(
              'Selected total',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Subtotal ${formatMoney(totals.subtotalCents, totals.currency)}',
              key: const ValueKey<String>('cart-subtotal'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (totals.savingsCents > 0) ...[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(LuminRadii.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    'Savings ${formatMoney(totals.savingsCents, totals.currency)}',
                    key: const ValueKey<String>('cart-savings'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ] else if (state.selectedQuantity > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Totals unavailable for mixed currencies',
              key: const ValueKey<String>('cart-mixed-currency'),
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
          if (state.isMutating) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(LuminRadii.pill),
              child: LinearProgressIndicator(
                key: const ValueKey<String>('cart-sync-progress'),
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Syncing cart',
              key: const ValueKey<String>('cart-syncing-label'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps a cart item in a swipe-to-remove gesture with an undo affordance.
class _DismissibleCartItem extends StatelessWidget {
  const _DismissibleCartItem({
    required this.item,
    required this.itemIndex,
    required this.isMutating,
  });

  final CartItem item;
  final int itemIndex;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey<String>('cart-dismiss-${item.productId}'),
      direction: isMutating
          ? DismissDirection.none
          : DismissDirection.endToStart,
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
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        final removed = item;
        final removedIndex = itemIndex;
        final cubit = context.read<CartCubit>();
        cubit.removeProduct(removed.productId);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${removed.productName} removed'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => cubit.restoreItem(removed, removedIndex),
              ),
            ),
          );
      },
      child: _CartItemTile(item: item, isMutating: isMutating),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item, required this.isMutating});

  final CartItem item;
  final bool isMutating;

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
                onChanged: isMutating
                    ? null
                    : (value) {
                        HapticFeedback.selectionClick();
                        context.read<CartCubit>().toggleSelection(
                          item.productId,
                          value ?? false,
                        );
                      },
              ),
              const SizedBox(width: 8),
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
                      onPressed: item.quantity > 1 && !isMutating
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
                      onPressed: isMutating
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              context.read<CartCubit>().increment(
                                item.productId,
                              );
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
            Text('${_friendlyMeshName(name)}: $value'),
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
