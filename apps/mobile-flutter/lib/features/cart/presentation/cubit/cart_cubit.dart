import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';

enum CartStatus { initial, loading, ready, failure }

class CartTotals {
  const CartTotals({
    required this.currency,
    required this.subtotalCents,
    required this.savingsCents,
  });

  final String currency;
  final int subtotalCents;
  final int savingsCents;
}

class CartState {
  const CartState({
    this.status = CartStatus.initial,
    this.items = const <CartItem>[],
    this.isMutating = false,
    this.message,
  });

  final CartStatus status;
  final List<CartItem> items;
  final bool isMutating;
  final String? message;

  int get totalQuantity =>
      items.fold<int>(0, (total, item) => total + item.quantity);

  int get selectedQuantity => items
      .where((item) => item.isSelected)
      .fold<int>(0, (total, item) => total + item.quantity);

  CartTotals? get selectedTotals {
    final selectedItems = items.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) {
      return null;
    }
    final currency = selectedItems.first.currency;
    if (selectedItems.any((item) => item.currency != currency)) {
      return null;
    }
    return CartTotals(
      currency: currency,
      subtotalCents: selectedItems.fold<int>(
        0,
        (total, item) => total + item.lineSubtotalCents,
      ),
      savingsCents: selectedItems.fold<int>(
        0,
        (total, item) => total + item.lineSavingsCents,
      ),
    );
  }

  CartState copyWith({
    CartStatus? status,
    List<CartItem>? items,
    bool? isMutating,
    String? message,
  }) {
    return CartState(
      status: status ?? this.status,
      items: items ?? this.items,
      isMutating: isMutating ?? this.isMutating,
      message: message,
    );
  }
}

class CartCubit extends Cubit<CartState> {
  CartCubit(this._cartRepository) : super(const CartState());

  final CartRepository _cartRepository;

  Future<void> load() async {
    emit(state.copyWith(status: CartStatus.loading, message: null));

    try {
      final items = await _cartRepository.loadCart();
      emit(
        state.copyWith(status: CartStatus.ready, items: items, message: null),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: CartStatus.failure,
          message: 'Cart is unavailable',
        ),
      );
    }
  }

  Future<void> addProduct(
    CatalogProductDetail detail,
    Map<String, String> selectedColors,
  ) async {
    await _mutate((items) {
      final existingIndex = items.indexWhere(
        (item) =>
            item.productId == detail.id &&
            _sameSelectedColors(item.selectedColors, selectedColors),
      );
      if (existingIndex == -1) {
        return [
          ...items,
          CartItem(
            productId: detail.id,
            productName: detail.name,
            amountCents: detail.price.amountCents,
            currency: detail.price.currency,
            compareAtAmountCents: detail.price.compareAtAmountCents,
            selectedColors: Map<String, String>.unmodifiable(selectedColors),
            quantity: 1,
            isSelected: true,
          ),
        ];
      }

      return [
        for (var index = 0; index < items.length; index += 1)
          if (index == existingIndex)
            items[index].copyWith(quantity: items[index].quantity + 1)
          else
            items[index],
      ];
    }, successMessage: 'Added to cart');
  }

  Future<void> increment(String productId) async {
    await _mutate(
      (items) => [
        for (final item in items)
          if (item.productId == productId)
            item.copyWith(quantity: item.quantity + 1)
          else
            item,
      ],
    );
  }

  Future<void> decrement(String productId) async {
    await _mutate(
      (items) => [
        for (final item in items)
          if (item.productId == productId)
            if (item.quantity > 1)
              item.copyWith(quantity: item.quantity - 1)
            else
              item
          else
            item,
      ],
    );
  }

  Future<void> toggleSelection(String productId, bool isSelected) async {
    await _mutate(
      (items) => [
        for (final item in items)
          if (item.productId == productId)
            item.copyWith(isSelected: isSelected)
          else
            item,
      ],
    );
  }

  Future<void> _mutate(
    List<CartItem> Function(List<CartItem> items) mutate, {
    String? successMessage,
  }) async {
    emit(state.copyWith(isMutating: true, message: null));

    try {
      final updatedItems = mutate(state.items);
      await _cartRepository.saveCart(updatedItems);
      emit(
        state.copyWith(
          status: CartStatus.ready,
          items: updatedItems,
          isMutating: false,
          message: successMessage,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: CartStatus.failure,
          isMutating: false,
          message: 'Cart is unavailable',
        ),
      );
    }
  }

  bool _sameSelectedColors(
    Map<String, String> left,
    Map<String, String> right,
  ) {
    if (left.length != right.length) {
      return false;
    }

    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}
