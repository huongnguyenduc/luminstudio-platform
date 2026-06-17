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
    Map<String, String> selectedColors, {
    int quantity = 1,
  }) async {
    final added = quantity < 1 ? 1 : quantity;
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
            quantity: added,
            isSelected: true,
          ),
        ];
      }

      return [
        for (var index = 0; index < items.length; index += 1)
          if (index == existingIndex)
            items[index].copyWith(quantity: items[index].quantity + added)
          else
            items[index],
      ];
    }, successMessage: 'Added to cart');
  }

  /// Quick-adds a catalog list product (no finish customization) to the cart.
  Future<void> addCatalogProduct(
    CatalogProduct product, {
    int quantity = 1,
  }) async {
    final added = quantity < 1 ? 1 : quantity;
    await _mutate((items) {
      final existingIndex = items.indexWhere(
        (item) =>
            item.productId == product.id && item.selectedColors.isEmpty,
      );
      if (existingIndex == -1) {
        return [
          ...items,
          CartItem(
            productId: product.id,
            productName: product.name,
            amountCents: product.price.amountCents,
            currency: product.price.currency,
            compareAtAmountCents: product.price.compareAtAmountCents,
            selectedColors: const <String, String>{},
            quantity: added,
            isSelected: true,
          ),
        ];
      }
      return [
        for (var index = 0; index < items.length; index += 1)
          if (index == existingIndex)
            items[index].copyWith(quantity: items[index].quantity + added)
          else
            items[index],
      ];
    }, successMessage: 'Added to cart');
  }

  /// Removes the item with [productId] from the cart.
  Future<void> removeProduct(String productId) async {
    await _mutate(
      (items) => [
        for (final item in items)
          if (item.productId != productId) item,
      ],
    );
  }

  /// Re-inserts a previously removed [item] at [index] (used for undo).
  Future<void> restoreItem(CartItem item, int index) async {
    await _mutate((items) {
      if (items.any((existing) => existing.productId == item.productId)) {
        return items;
      }
      final clampedIndex = index < 0
          ? 0
          : index > items.length
          ? items.length
          : index;
      return [
        ...items.sublist(0, clampedIndex),
        item,
        ...items.sublist(clampedIndex),
      ];
    });
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

  // Tracks whether a background save loop is currently draining, plus the
  // latest cart snapshot still waiting to be persisted. Coalescing saves this
  // way keeps every quantity/selection control interactive (no disabling on
  // each tap) while guaranteeing only one in-flight request at a time, so
  // rapid taps never race the backend or thrash the sync indicator.
  bool _isSaving = false;
  List<CartItem>? _pendingSave;
  String? _pendingMessage;

  Future<void> _mutate(
    List<CartItem> Function(List<CartItem> items) mutate, {
    String? successMessage,
  }) async {
    final updatedItems = mutate(state.items);

    // Optimistically apply the change so the UI (including swipe-to-remove)
    // updates immediately, then persist in the background.
    emit(
      state.copyWith(
        status: CartStatus.ready,
        items: updatedItems,
        isMutating: true,
        message: null,
      ),
    );

    _pendingSave = updatedItems;
    _pendingMessage = successMessage;

    // A drain loop is already running; it will pick up the snapshot above on
    // its next iteration instead of starting a second concurrent save.
    if (_isSaving) {
      return;
    }
    _isSaving = true;

    try {
      while (_pendingSave != null) {
        final snapshot = _pendingSave!;
        _pendingSave = null;
        await _cartRepository.saveCart(snapshot);
      }
      _isSaving = false;
      emit(
        state.copyWith(
          status: CartStatus.ready,
          isMutating: false,
          message: _pendingMessage,
        ),
      );
    } catch (_) {
      _isSaving = false;
      _pendingSave = null;
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
