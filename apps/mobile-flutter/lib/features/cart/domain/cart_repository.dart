import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';

abstract interface class CartRepository {
  Future<List<CartItem>> loadCart();

  Future<void> saveCart(List<CartItem> items);
}

abstract interface class CartIdStore {
  Future<String?> loadCartId();

  Future<void> saveCartId(String? cartId);
}
