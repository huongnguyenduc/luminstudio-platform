import 'dart:convert';
import 'dart:io';

import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';

class CatalogApiClient {
  CatalogApiClient({required Uri baseUri, HttpClient? httpClient})
    : _baseUri = baseUri,
      _httpClient = httpClient ?? HttpClient();

  final Uri _baseUri;
  final HttpClient _httpClient;

  Future<CatalogProductsPage> listProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    return _fetchCatalogPage(
      routePath: '/catalog/products',
      queryParameters: {'limit': limit.toString(), 'offset': offset.toString()},
    );
  }

  Future<CatalogProductsPage> searchProducts(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    return _fetchCatalogPage(
      routePath: '/catalog/search',
      queryParameters: {
        'q': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
  }

  Future<CatalogProductsPage> _fetchCatalogPage({
    required String routePath,
    required Map<String, String> queryParameters,
  }) async {
    final uri = _baseUri.replace(
      path: _joinPath(_baseUri.path, routePath),
      queryParameters: queryParameters,
    );
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await utf8.decodeStream(response);

    if (response.statusCode != HttpStatus.ok) {
      throw CatalogApiException(
        'Catalog API returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const CatalogApiException('Catalog API returned an invalid body');
    }
    return CatalogProductsDto.fromJson(
      decoded,
    ).toDomain(spritePreviewUriFor: _catalogSpriteUri);
  }

  Uri _catalogSpriteUri(String productId) {
    return _baseUri.replace(
      path: _joinPath(
        _baseUri.path,
        '/catalog/products/${Uri.encodeComponent(productId)}/sprite',
      ),
      queryParameters: null,
    );
  }

  String _joinPath(String basePath, String routePath) {
    final trimmedBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    return '$trimmedBase$routePath';
  }
}

class CatalogApiException implements Exception {
  const CatalogApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CatalogProductsDto {
  const CatalogProductsDto({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    this.query,
  });

  final List<CatalogProductDto> items;
  final int total;
  final int limit;
  final int offset;
  final String? query;

  factory CatalogProductsDto.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    if (items is! List<Object?>) {
      throw const CatalogApiException('Catalog items must be an array');
    }

    return CatalogProductsDto(
      items: [
        for (final item in items)
          CatalogProductDto.fromJson(_expectMap(item, 'catalog item')),
      ],
      total: _expectInt(json['total'], 'total'),
      limit: _expectInt(json['limit'], 'limit'),
      offset: _expectInt(json['offset'], 'offset'),
      query: _expectOptionalString(json['query'], 'query'),
    );
  }

  CatalogProductsPage toDomain({
    Uri Function(String productId)? spritePreviewUriFor,
  }) {
    return CatalogProductsPage(
      items: [
        for (final item in items)
          item.toDomain(spritePreviewUriFor: spritePreviewUriFor),
      ],
      total: total,
      limit: limit,
      offset: offset,
    );
  }
}

class CatalogProductDto {
  const CatalogProductDto({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.processingStatus,
    required this.updatedAt,
    this.spriteAsset,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String processingStatus;
  final DateTime updatedAt;
  final CatalogObjectRefDto? spriteAsset;

  factory CatalogProductDto.fromJson(Map<String, Object?> json) {
    final spriteAsset = json['spriteAsset'];

    return CatalogProductDto(
      id: _expectString(json['id'], 'id'),
      name: _expectString(json['name'], 'name'),
      slug: _expectString(json['slug'], 'slug'),
      description: _expectString(json['description'], 'description'),
      processingStatus: _expectString(
        json['processingStatus'],
        'processingStatus',
      ),
      updatedAt: DateTime.parse(_expectString(json['updatedAt'], 'updatedAt')),
      spriteAsset: spriteAsset == null
          ? null
          : CatalogObjectRefDto.fromJson(
              _expectMap(spriteAsset, 'spriteAsset'),
            ),
    );
  }

  CatalogProduct toDomain({
    Uri Function(String productId)? spritePreviewUriFor,
  }) {
    return CatalogProduct(
      id: id,
      name: name,
      slug: slug,
      description: description,
      processingStatus: processingStatus,
      updatedAt: updatedAt,
      spriteAsset: spriteAsset?.toDomain(),
      spritePreviewUri: spriteAsset == null
          ? null
          : spritePreviewUriFor?.call(id),
    );
  }
}

class CatalogObjectRefDto {
  const CatalogObjectRefDto({
    required this.bucket,
    required this.key,
    this.contentType,
    this.sizeBytes,
  });

  final String bucket;
  final String key;
  final String? contentType;
  final int? sizeBytes;

  factory CatalogObjectRefDto.fromJson(Map<String, Object?> json) {
    return CatalogObjectRefDto(
      bucket: _expectString(json['bucket'], 'bucket'),
      key: _expectString(json['key'], 'key'),
      contentType: _expectOptionalString(json['contentType'], 'contentType'),
      sizeBytes: _expectOptionalInt(json['sizeBytes'], 'sizeBytes'),
    );
  }

  CatalogObjectRef toDomain() {
    return CatalogObjectRef(
      bucket: bucket,
      key: key,
      contentType: contentType,
      sizeBytes: sizeBytes,
    );
  }
}

Map<String, Object?> _expectMap(Object? value, String name) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw CatalogApiException('$name must be an object');
}

String _expectString(Object? value, String name) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw CatalogApiException('$name must be a non-empty string');
}

int _expectInt(Object? value, String name) {
  if (value is int) {
    return value;
  }
  throw CatalogApiException('$name must be an integer');
}

String? _expectOptionalString(Object? value, String name) {
  if (value == null) {
    return null;
  }
  return _expectString(value, name);
}

int? _expectOptionalInt(Object? value, String name) {
  if (value == null) {
    return null;
  }
  return _expectInt(value, name);
}
