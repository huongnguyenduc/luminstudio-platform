import 'dart:convert';

import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesCartRepository implements CartRepository {
  SharedPreferencesCartRepository(this._preferences);

  static const String _storageKey = 'lumin.cart.v1';

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
          'selected_colors': item.selectedColors,
          'qty': item.quantity,
          'selected': item.isSelected,
        },
    ]);
    await _preferences.setString(_storageKey, encoded);
  }

  CartItem? _parseCartItem(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final productId = value['product_id'];
    final quantity = value['qty'];
    final selectedColors = value['selected_colors'];
    final selected = value['selected'];
    if (productId is! String || productId.isEmpty) {
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
      selectedColors: {
        for (final entry in selectedColors.entries)
          if (entry.value is String) entry.key: entry.value! as String,
      },
      quantity: quantity,
      isSelected: selected is bool ? selected : true,
    );
  }
}
