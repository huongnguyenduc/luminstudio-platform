import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumin_studio_mobile/features/cart/data/api_backed_cart_repository.dart';
import 'package:lumin_studio_mobile/features/cart/data/cart_api_client.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';

void main() {
  test('CartApiClient posts the v1 cart upsert shape', () async {
    late http.Request capturedRequest;
    final client = CartApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(_cartRecordJson(id: 'cart_12345678')),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final record = await client.createCart(const [
      CartItem(
        productId: 'prod_1',
        productName: 'Product 1',
        amountCents: 12900,
        currency: 'USD',
        compareAtAmountCents: 15900,
        selectedColors: {'mesh_body': '#0F172A'},
        quantity: 2,
        isSelected: true,
      ),
    ]);

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url, Uri.parse('http://api.test/cart'));
    expect(capturedRequest.headers['content-type'], 'application/json');
    expect(jsonDecode(capturedRequest.body), {
      'items': [
        {
          'productId': 'prod_1',
          'selectedColors': {'mesh_body': '#0F172A'},
          'quantity': 2,
          'selected': true,
        },
      ],
    });
    expect(record.id, 'cart_12345678');
    expect(record.toDomainItems().single.productName, 'Product 1');
    expect(record.totals.selectedAmountCents, 25800);
  });

  test('CartApiClient updates and reads existing backend carts', () async {
    final requests = <String>[];
    final client = CartApiClient(
      baseUri: Uri.parse('http://api.test/base'),
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        return http.Response(
          jsonEncode(_cartRecordJson(id: 'cart_existing')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.getCart('cart_existing');
    await client.updateCart('cart_existing', const []);

    expect(requests, [
      'GET http://api.test/base/cart/cart_existing',
      'PUT http://api.test/base/cart/cart_existing',
    ]);
  });

  test(
    'ApiBackedCartRepository syncs backend records and local cache',
    () async {
      final idStore = _MemoryCartIdStore();
      final local = _MemoryCartRepository();
      final requests = <String>[];
      final client = CartApiClient(
        baseUri: Uri.parse('http://api.test'),
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url}');
          return http.Response(
            jsonEncode(_cartRecordJson(id: 'cart_synced')),
            request.method == 'POST' ? 201 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repository = ApiBackedCartRepository(
        client: client,
        localRepository: local,
        cartIdStore: idStore,
      );

      await repository.saveCart(const [
        CartItem(
          productId: 'prod_1',
          productName: 'Local Product',
          amountCents: 9900,
          currency: 'USD',
          selectedColors: {'mesh_body': '#FFFFFF'},
          quantity: 1,
          isSelected: true,
        ),
      ]);
      final loaded = await repository.loadCart();

      expect(idStore.cartId, 'cart_synced');
      expect(local.items.single.productName, 'Product 1');
      expect(loaded.single.amountCents, 12900);
      expect(requests, [
        'POST http://api.test/cart',
        'GET http://api.test/cart/cart_synced',
      ]);
    },
  );

  test(
    'ApiBackedCartRepository falls back to local cache when load fails',
    () async {
      final idStore = _MemoryCartIdStore('cart_missing');
      final local = _MemoryCartRepository(
        items: const [
          CartItem(
            productId: 'prod_1',
            productName: 'Cached Product',
            amountCents: 9900,
            currency: 'USD',
            selectedColors: {'mesh_body': '#FFFFFF'},
            quantity: 1,
            isSelected: true,
          ),
        ],
      );
      final repository = ApiBackedCartRepository(
        client: CartApiClient(
          baseUri: Uri.parse('http://api.test'),
          httpClient: MockClient(
            (_) async => http.Response('{"error":"missing"}', 404),
          ),
        ),
        localRepository: local,
        cartIdStore: idStore,
      );

      final loaded = await repository.loadCart();

      expect(idStore.cartId, isNull);
      expect(loaded.single.productName, 'Cached Product');
    },
  );
}

Map<String, Object?> _cartRecordJson({required String id}) {
  return {
    'id': id,
    'items': [
      {
        'productId': 'prod_1',
        'productName': 'Product 1',
        'price': {
          'amountCents': 12900,
          'currency': 'USD',
          'compareAtAmountCents': 15900,
        },
        'categories': [
          {'slug': 'lighting', 'name': 'Lighting'},
        ],
        'selectedColors': {'mesh_body': '#0F172A'},
        'quantity': 2,
        'selected': true,
        'productUpdatedAt': '2026-06-16T05:30:00Z',
        'productProcessingStatus': 'completed',
      },
    ],
    'totals': {
      'selectedItemCount': 1,
      'selectedQuantity': 2,
      'currency': 'USD',
      'selectedAmountCents': 25800,
      'selectedCompareAtAmountCents': 31800,
      'selectedSavingsCents': 6000,
      'mixedCurrency': false,
    },
    'createdAt': '2026-06-16T05:30:00Z',
    'updatedAt': '2026-06-16T05:31:00Z',
  };
}

class _MemoryCartRepository implements CartRepository {
  _MemoryCartRepository({List<CartItem> items = const <CartItem>[]})
    : items = List<CartItem>.of(items);

  List<CartItem> items;

  @override
  Future<List<CartItem>> loadCart() async {
    return List<CartItem>.of(items);
  }

  @override
  Future<void> saveCart(List<CartItem> items) async {
    this.items = List<CartItem>.of(items);
  }
}

class _MemoryCartIdStore implements CartIdStore {
  _MemoryCartIdStore([this.cartId]);

  String? cartId;

  @override
  Future<String?> loadCartId() async {
    return cartId;
  }

  @override
  Future<void> saveCartId(String? cartId) async {
    this.cartId = cartId;
  }
}
