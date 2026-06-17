import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';

class CartApiClient {
  CartApiClient({required Uri baseUri, http.Client? httpClient})
    : _baseUri = baseUri,
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Future<CartRecordDto> createCart(List<CartItem> items) async {
    final response = await _httpClient.post(
      _cartUri(),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode(_upsertBody(items)),
    );
    return _decodeRecord(response, expectedStatus: 201);
  }

  Future<CartRecordDto> getCart(String cartId) async {
    final response = await _httpClient.get(
      _cartUri(cartId),
      headers: const {'accept': 'application/json'},
    );
    return _decodeRecord(response, expectedStatus: 200);
  }

  Future<CartRecordDto> updateCart(String cartId, List<CartItem> items) async {
    final response = await _httpClient.put(
      _cartUri(cartId),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode(_upsertBody(items)),
    );
    return _decodeRecord(response, expectedStatus: 200);
  }

  CartRecordDto _decodeRecord(
    http.Response response, {
    required int expectedStatus,
  }) {
    if (response.statusCode != expectedStatus) {
      throw CartApiException(
        'Cart API returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw const CartApiException('Cart API returned an invalid body');
    }
    return CartRecordDto.fromJson(decoded);
  }

  Uri _cartUri([String? cartId]) {
    final routePath = cartId == null
        ? '/cart'
        : '/cart/${Uri.encodeComponent(cartId)}';
    return _baseUri.replace(
      path: _joinPath(_baseUri.path, routePath),
      queryParameters: null,
    );
  }

  Map<String, Object?> _upsertBody(List<CartItem> items) {
    return {
      'items': [
        for (final item in items)
          {
            'productId': item.productId,
            'selectedColors': item.selectedColors,
            'quantity': item.quantity,
            'selected': item.isSelected,
          },
      ],
    };
  }

  String _joinPath(String basePath, String routePath) {
    final trimmedBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    return '$trimmedBase$routePath';
  }
}

class CartApiException implements Exception {
  const CartApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CartRecordDto {
  const CartRecordDto({
    required this.id,
    required this.items,
    required this.totals,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final List<CartItemSnapshotDto> items;
  final CartTotalsDto totals;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CartRecordDto.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    if (items is! List<Object?>) {
      throw const CartApiException('cart.items must be an array');
    }

    return CartRecordDto(
      id: _expectString(json['id'], 'cart.id'),
      items: [
        for (final item in items)
          CartItemSnapshotDto.fromJson(_expectMap(item, 'cart item')),
      ],
      totals: CartTotalsDto.fromJson(_expectMap(json['totals'], 'totals')),
      createdAt: DateTime.parse(_expectString(json['createdAt'], 'createdAt')),
      updatedAt: DateTime.parse(_expectString(json['updatedAt'], 'updatedAt')),
    );
  }

  List<CartItem> toDomainItems() {
    return [for (final item in items) item.toDomain()];
  }
}

class CartItemSnapshotDto {
  const CartItemSnapshotDto({
    required this.productId,
    required this.productName,
    required this.price,
    required this.selectedColors,
    required this.quantity,
    required this.selected,
    required this.productUpdatedAt,
    required this.productProcessingStatus,
  });

  final String productId;
  final String productName;
  final CartPriceDto price;
  final Map<String, String> selectedColors;
  final int quantity;
  final bool selected;
  final DateTime productUpdatedAt;
  final String productProcessingStatus;

  factory CartItemSnapshotDto.fromJson(Map<String, Object?> json) {
    return CartItemSnapshotDto(
      productId: _expectString(json['productId'], 'productId'),
      productName: _expectString(json['productName'], 'productName'),
      price: CartPriceDto.fromJson(_expectMap(json['price'], 'price')),
      selectedColors: _parseStringMap(json['selectedColors']),
      quantity: _expectInt(json['quantity'], 'quantity'),
      selected: _expectBool(json['selected'], 'selected'),
      productUpdatedAt: DateTime.parse(
        _expectString(json['productUpdatedAt'], 'productUpdatedAt'),
      ),
      productProcessingStatus: _expectString(
        json['productProcessingStatus'],
        'productProcessingStatus',
      ),
    );
  }

  CartItem toDomain() {
    return CartItem(
      productId: productId,
      productName: productName,
      amountCents: price.amountCents,
      currency: price.currency,
      compareAtAmountCents: price.compareAtAmountCents,
      selectedColors: selectedColors,
      quantity: quantity,
      isSelected: selected,
    );
  }
}

class CartPriceDto {
  const CartPriceDto({
    required this.amountCents,
    required this.currency,
    this.compareAtAmountCents,
  });

  final int amountCents;
  final String currency;
  final int? compareAtAmountCents;

  factory CartPriceDto.fromJson(Map<String, Object?> json) {
    return CartPriceDto(
      amountCents: _expectInt(json['amountCents'], 'price.amountCents'),
      currency: _expectString(json['currency'], 'price.currency'),
      compareAtAmountCents: _expectOptionalInt(
        json['compareAtAmountCents'],
        'price.compareAtAmountCents',
      ),
    );
  }
}

class CartTotalsDto {
  const CartTotalsDto({
    required this.selectedItemCount,
    required this.selectedQuantity,
    required this.selectedAmountCents,
    required this.selectedSavingsCents,
    required this.mixedCurrency,
    this.currency,
    this.selectedCompareAtAmountCents,
  });

  final int selectedItemCount;
  final int selectedQuantity;
  final String? currency;
  final int selectedAmountCents;
  final int? selectedCompareAtAmountCents;
  final int selectedSavingsCents;
  final bool mixedCurrency;

  factory CartTotalsDto.fromJson(Map<String, Object?> json) {
    return CartTotalsDto(
      selectedItemCount: _expectInt(
        json['selectedItemCount'],
        'selectedItemCount',
      ),
      selectedQuantity: _expectInt(
        json['selectedQuantity'],
        'selectedQuantity',
      ),
      currency: _expectOptionalString(json['currency'], 'currency'),
      selectedAmountCents: _expectInt(
        json['selectedAmountCents'],
        'selectedAmountCents',
      ),
      selectedCompareAtAmountCents: _expectOptionalInt(
        json['selectedCompareAtAmountCents'],
        'selectedCompareAtAmountCents',
      ),
      selectedSavingsCents: _expectInt(
        json['selectedSavingsCents'],
        'selectedSavingsCents',
      ),
      mixedCurrency: _expectBool(json['mixedCurrency'], 'mixedCurrency'),
    );
  }
}

Map<String, Object?> _expectMap(Object? value, String name) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw CartApiException('$name must be an object');
}

String _expectString(Object? value, String name) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw CartApiException('$name must be a non-empty string');
}

String? _expectOptionalString(Object? value, String name) {
  if (value == null) {
    return null;
  }
  return _expectString(value, name);
}

int _expectInt(Object? value, String name) {
  if (value is int) {
    return value;
  }
  throw CartApiException('$name must be an integer');
}

int? _expectOptionalInt(Object? value, String name) {
  if (value == null) {
    return null;
  }
  return _expectInt(value, name);
}

bool _expectBool(Object? value, String name) {
  if (value is bool) {
    return value;
  }
  throw CartApiException('$name must be a boolean');
}

Map<String, String> _parseStringMap(Object? value) {
  if (value == null) {
    return const {};
  }
  final raw = _expectMap(value, 'selectedColors');
  return {
    for (final entry in raw.entries)
      entry.key: _expectString(entry.value, 'selectedColors.${entry.key}'),
  };
}
