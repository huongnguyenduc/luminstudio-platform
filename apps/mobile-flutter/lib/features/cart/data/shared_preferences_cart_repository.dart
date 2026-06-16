import 'dart:convert';

import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesCartRepository implements CartRepository, CartIdStore {
  SharedPreferencesCartRepository(this._preferences);

  static const String _storageKey = 'lumin.cart.v1';
  static const String _cartIdStorageKey = 'lumin.cart.id.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<CartItem>> loadCart() async {
    final encoded = await _preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return const <CartItem>[];
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! List<Object?>) {
      return const <CartItem>[];
    }

    return [
      for (final item in decoded)
        if (_parseCartItem(item) case final parsed?) parsed,
    ];
  }

  @override
  Future<void> saveCart(List<CartItem> items) async {
    final encoded = jsonEncode([
      for (final item in items)
        <String, Object?>{
          'product_id': item.productId,
          'product_name': item.productName,
          'amount_cents': item.amountCents,
          'currency': item.currency,
          'compare_at_amount_cents': item.compareAtAmountCents,
          'selected_colors': item.selectedColors,
          'qty': item.quantity,
          'selected': item.isSelected,
        },
    ]);
    await _preferences.setString(_storageKey, encoded);
  }

  @override
  Future<String?> loadCartId() async {
    final cartId = await _preferences.getString(_cartIdStorageKey);
    return cartId == null || cartId.isEmpty ? null : cartId;
  }

  @override
  Future<void> saveCartId(String? cartId) async {
    if (cartId == null || cartId.isEmpty) {
      await _preferences.remove(_cartIdStorageKey);
      return;
    }
    await _preferences.setString(_cartIdStorageKey, cartId);
  }

  CartItem? _parseCartItem(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final productId = value['product_id'];
    final productName = value['product_name'];
    final amountCents = value['amount_cents'];
    final currency = value['currency'];
    final compareAtAmountCents = value['compare_at_amount_cents'];
    final quantity = value['qty'];
    final selectedColors = value['selected_colors'];
    final selected = value['selected'];
    if (productId is! String || productId.isEmpty) {
      return null;
    }
    if (productName is! String || productName.isEmpty) {
      return null;
    }
    if (amountCents is! int || amountCents < 1) {
      return null;
    }
    if (currency is! String || currency.isEmpty) {
      return null;
    }
    if (compareAtAmountCents != null &&
        (compareAtAmountCents is! int || compareAtAmountCents <= amountCents)) {
      return null;
    }
    if (quantity is! int || quantity < 1) {
      return null;
    }
    if (selectedColors is! Map<String, Object?>) {
      return null;
    }

    return CartItem(
      productId: productId,
      productName: productName,
      amountCents: amountCents,
      currency: currency,
      compareAtAmountCents: compareAtAmountCents is int
          ? compareAtAmountCents
          : null,
      selectedColors: {
        for (final entry in selectedColors.entries)
          if (entry.value is String) entry.key: entry.value! as String,
      },
      quantity: quantity,
      isSelected: selected is bool ? selected : true,
    );
  }
}
