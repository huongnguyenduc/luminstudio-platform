import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';

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
    return const Center(
      child: SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
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
      child: ListView(
        key: const PageStorageKey<String>('cart-scroll'),
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
            child: Text('Cart is empty', style: theme.textTheme.titleMedium),
          ),
        ],
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CartSummary(state: state);
          }

          final item = state.items[index - 1];
          return _CartItemTile(item: item, isMutating: state.isMutating);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shopping_bag, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cart summary', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${state.totalQuantity} in cart, ${state.selectedQuantity} selected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totals != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Selected total',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  'Subtotal ${_formatMoney(totals.subtotalCents, totals.currency)}',
                  key: const ValueKey<String>('cart-subtotal'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (totals.savingsCents > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Savings ${_formatMoney(totals.savingsCents, totals.currency)}',
                key: const ValueKey<String>('cart-savings'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ] else if (state.selectedQuantity > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Totals unavailable for mixed currencies',
              key: const ValueKey<String>('cart-mixed-currency'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (state.isMutating) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              key: ValueKey<String>('cart-sync-progress'),
              minHeight: 3,
            ),
            const SizedBox(height: 8),
            Text(
              'Syncing cart',
              key: const ValueKey<String>('cart-syncing-label'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
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
        borderRadius: BorderRadius.circular(12),
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
                      '${_formatMoney(item.amountCents, item.currency)} each',
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
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Decrease ${item.productId} quantity',
                      onPressed: item.quantity > 1 && !isMutating
                          ? () {
                              context.read<CartCubit>().decrement(
                                item.productId,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          key: ValueKey<String>('cart-qty-${item.productId}'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase ${item.productId} quantity',
                      onPressed: isMutating
                          ? null
                          : () {
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

String _formatMoney(int cents, String currency) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$currency $whole.$fraction';
}
