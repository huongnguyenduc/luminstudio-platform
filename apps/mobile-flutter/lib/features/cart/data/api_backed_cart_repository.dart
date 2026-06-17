import 'package:lumin_studio_mobile/features/cart/data/cart_api_client.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';

class ApiBackedCartRepository implements CartRepository {
  const ApiBackedCartRepository({
    required CartApiClient client,
    required CartRepository localRepository,
    required CartIdStore cartIdStore,
  }) : _client = client,
       _localRepository = localRepository,
       _cartIdStore = cartIdStore;

  final CartApiClient _client;
  final CartRepository _localRepository;
  final CartIdStore _cartIdStore;

  @override
  Future<List<CartItem>> loadCart() async {
    final cartId = await _cartIdStore.loadCartId();
    if (cartId == null) {
      return _localRepository.loadCart();
    }

    try {
      final record = await _client.getCart(cartId);
      final items = record.toDomainItems();
      await _localRepository.saveCart(items);
      return items;
    } on CartApiException catch (error) {
      if (error.statusCode == 404) {
        await _cartIdStore.saveCartId(null);
      }
      return _localRepository.loadCart();
    }
  }

  @override
  Future<void> saveCart(List<CartItem> items) async {
    final cartId = await _cartIdStore.loadCartId();
    final record = cartId == null
        ? await _client.createCart(items)
        : await _updateOrCreate(cartId, items);
    await _cartIdStore.saveCartId(record.id);
    await _localRepository.saveCart(record.toDomainItems());
  }

  Future<CartRecordDto> _updateOrCreate(
    String cartId,
    List<CartItem> items,
  ) async {
    try {
      return await _client.updateCart(cartId, items);
    } on CartApiException catch (error) {
      if (error.statusCode == 404) {
        await _cartIdStore.saveCartId(null);
        return _client.createCart(items);
      }
      rethrow;
    }
  }
}
