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
          return _CartItemTile(item: item);
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

    return Container(
      key: const ValueKey<String>('cart-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_bag, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${state.totalQuantity} in cart, ${state.selectedQuantity} selected',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: ValueKey<String>('cart-item-${item.productId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: item.isSelected,
                onChanged: (value) {
                  context.read<CartCubit>().toggleSelection(
                    item.productId,
                    value ?? false,
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Product ${item.productId}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in item.selectedColors.entries)
                Chip(
                  key: ValueKey<String>(
                    'cart-color-${item.productId}-${color.key}-${color.value}',
                  ),
                  label: Text('${color.key}: ${color.value}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Decrease ${item.productId} quantity',
                onPressed: item.quantity > 1
                    ? () {
                        context.read<CartCubit>().decrement(item.productId);
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 56,
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
                onPressed: () {
                  context.read<CartCubit>().increment(item.productId);
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
