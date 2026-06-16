import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';

class CatalogApiClient {
  CatalogApiClient({required Uri baseUri, http.Client? httpClient})
    : _baseUri = baseUri,
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Future<List<CatalogCategory>> listCategories() async {
    final uri = _baseUri.replace(
      path: _joinPath(_baseUri.path, '/catalog/categories'),
      queryParameters: null,
    );
    final response = await _httpClient.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw CatalogApiException(
        'Catalog categories API returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw const CatalogApiException(
        'Catalog categories API returned an invalid body',
      );
    }
    return CategoryListDto.fromJson(decoded).toDomain();
  }

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

  Future<CatalogProductsPage> listCategoryProducts(
    String categorySlug, {
    CategoryProductSort sort = CategoryProductSort.newest,
    int limit = 20,
    int offset = 0,
  }) async {
    return _fetchCatalogPage(
      routePath:
          '/catalog/categories/${Uri.encodeComponent(categorySlug)}/products',
      queryParameters: {
        'sort': sort.wireName,
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
  }

  Future<CatalogProductDetail> getProductDetail(
    String productId, {
    required ProductModelTier tier,
  }) async {
    final uri = _baseUri.replace(
      path: _joinPath(
        _baseUri.path,
        '/catalog/products/${Uri.encodeComponent(productId)}',
      ),
      queryParameters: {'tier': tier.wireName},
    );
    final response = await _httpClient.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw CatalogApiException(
        'Catalog detail API returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw const CatalogApiException(
        'Catalog detail API returned an invalid body',
      );
    }
    return ProductDetailDto.fromJson(
      decoded,
    ).toDomain(routeUriFor: _catalogRouteUri);
  }

  Future<CatalogProductsPage> _fetchCatalogPage({
    required String routePath,
    required Map<String, String> queryParameters,
  }) async {
    final uri = _baseUri.replace(
      path: _joinPath(_baseUri.path, routePath),
      queryParameters: queryParameters,
    );
    final response = await _httpClient.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw CatalogApiException(
        'Catalog API returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
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

  Uri _catalogRouteUri(String routePath) {
    final parsed = Uri.parse(routePath);
    return _baseUri.replace(
      path: _joinPath(_baseUri.path, parsed.path),
      queryParameters: parsed.queryParameters.isEmpty
          ? null
          : parsed.queryParameters,
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
    this.categorySlug,
    this.sort,
  });

  final List<CatalogProductDto> items;
  final int total;
  final int limit;
  final int offset;
  final String? query;
  final String? categorySlug;
  final CategoryProductSort? sort;

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
      categorySlug: _expectOptionalString(json['categorySlug'], 'categorySlug'),
      sort: _parseOptionalCategorySort(json['sort']),
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
      categorySlug: categorySlug,
      sort: sort,
    );
  }
}

class CatalogProductDto {
  const CatalogProductDto({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.price,
    required this.categories,
    required this.processingStatus,
    required this.updatedAt,
    this.spriteAsset,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final CatalogPriceDto price;
  final List<CatalogCategoryDto> categories;
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
      price: CatalogPriceDto.fromJson(_expectMap(json['price'], 'price')),
      categories: _parseCategories(json['categories']),
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
      price: price.toDomain(),
      categories: [for (final category in categories) category.toDomain()],
      processingStatus: processingStatus,
      updatedAt: updatedAt,
      spriteAsset: spriteAsset?.toDomain(),
      spritePreviewUri: spriteAsset == null
          ? null
          : spritePreviewUriFor?.call(id),
    );
  }
}

class CategoryListDto {
  const CategoryListDto({required this.categories});

  final List<CatalogCategoryDto> categories;

  factory CategoryListDto.fromJson(Map<String, Object?> json) {
    final categories = json['categories'];
    if (categories is! List<Object?>) {
      throw const CatalogApiException('categories must be an array');
    }
    return CategoryListDto(
      categories: [
        for (final category in categories)
          CatalogCategoryDto.fromJson(_expectMap(category, 'category')),
      ],
    );
  }

  List<CatalogCategory> toDomain() {
    return [for (final category in categories) category.toDomain()];
  }
}

class CatalogCategoryDto {
  const CatalogCategoryDto({required this.slug, required this.name});

  final String slug;
  final String name;

  factory CatalogCategoryDto.fromJson(Map<String, Object?> json) {
    return CatalogCategoryDto(
      slug: _expectString(json['slug'], 'category.slug'),
      name: _expectString(json['name'], 'category.name'),
    );
  }

  CatalogCategory toDomain() {
    return CatalogCategory(slug: slug, name: name);
  }
}

class CatalogPriceDto {
  const CatalogPriceDto({
    required this.amountCents,
    required this.currency,
    this.compareAtAmountCents,
  });

  final int amountCents;
  final String currency;
  final int? compareAtAmountCents;

  factory CatalogPriceDto.fromJson(Map<String, Object?> json) {
    return CatalogPriceDto(
      amountCents: _expectInt(json['amountCents'], 'price.amountCents'),
      currency: _expectString(json['currency'], 'price.currency'),
      compareAtAmountCents: _expectOptionalInt(
        json['compareAtAmountCents'],
        'price.compareAtAmountCents',
      ),
    );
  }

  CatalogPrice toDomain() {
    return CatalogPrice(
      amountCents: amountCents,
      currency: currency,
      compareAtAmountCents: compareAtAmountCents,
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

class ProductDetailDto {
  const ProductDetailDto({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.price,
    required this.categories,
    required this.informationSections,
    required this.meshColorConfig,
    required this.processingStatus,
    required this.modelTier,
    required this.updatedAt,
    this.modelAsset,
    this.modelUrl,
    this.spriteAsset,
    this.spriteUrl,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final CatalogPriceDto price;
  final List<CatalogCategoryDto> categories;
  final List<CatalogInformationSectionDto> informationSections;
  final List<CatalogMeshColorOptionsDto> meshColorConfig;
  final String processingStatus;
  final ProductModelTier modelTier;
  final CatalogObjectRefDto? modelAsset;
  final String? modelUrl;
  final CatalogObjectRefDto? spriteAsset;
  final String? spriteUrl;
  final DateTime updatedAt;

  factory ProductDetailDto.fromJson(Map<String, Object?> json) {
    final sections = json['informationSections'];
    if (sections is! List<Object?>) {
      throw const CatalogApiException('informationSections must be an array');
    }

    return ProductDetailDto(
      id: _expectString(json['id'], 'id'),
      name: _expectString(json['name'], 'name'),
      slug: _expectString(json['slug'], 'slug'),
      description: _expectString(json['description'], 'description'),
      price: CatalogPriceDto.fromJson(_expectMap(json['price'], 'price')),
      categories: _parseCategories(json['categories']),
      informationSections: [
        for (final section in sections)
          CatalogInformationSectionDto.fromJson(
            _expectMap(section, 'information section'),
          ),
      ],
      meshColorConfig: _parseMeshColorConfig(json['meshColorConfig']),
      processingStatus: _expectString(
        json['processingStatus'],
        'processingStatus',
      ),
      modelTier: ProductModelTier.parse(
        _expectString(json['modelTier'], 'modelTier'),
      ),
      modelAsset: json['modelAsset'] == null
          ? null
          : CatalogObjectRefDto.fromJson(
              _expectMap(json['modelAsset'], 'modelAsset'),
            ),
      modelUrl: _expectOptionalString(json['modelUrl'], 'modelUrl'),
      spriteAsset: json['spriteAsset'] == null
          ? null
          : CatalogObjectRefDto.fromJson(
              _expectMap(json['spriteAsset'], 'spriteAsset'),
            ),
      spriteUrl: _expectOptionalString(json['spriteUrl'], 'spriteUrl'),
      updatedAt: DateTime.parse(_expectString(json['updatedAt'], 'updatedAt')),
    );
  }

  CatalogProductDetail toDomain({Uri Function(String routePath)? routeUriFor}) {
    return CatalogProductDetail(
      id: id,
      name: name,
      slug: slug,
      description: description,
      price: price.toDomain(),
      categories: [for (final category in categories) category.toDomain()],
      informationSections: [
        for (final section in informationSections) section.toDomain(),
      ],
      meshColorConfig: [
        for (final options in meshColorConfig) options.toDomain(),
      ],
      processingStatus: processingStatus,
      modelTier: modelTier,
      modelAsset: modelAsset?.toDomain(),
      modelUri: modelUrl == null ? null : routeUriFor?.call(modelUrl!),
      spriteAsset: spriteAsset?.toDomain(),
      spriteUri: spriteUrl == null ? null : routeUriFor?.call(spriteUrl!),
      updatedAt: updatedAt,
    );
  }
}

class CatalogInformationSectionDto {
  const CatalogInformationSectionDto({required this.title, required this.body});

  final String title;
  final String body;

  factory CatalogInformationSectionDto.fromJson(Map<String, Object?> json) {
    return CatalogInformationSectionDto(
      title: _expectString(json['title'], 'title'),
      body: _expectString(json['body'], 'body'),
    );
  }

  CatalogInformationSection toDomain() {
    return CatalogInformationSection(title: title, body: body);
  }
}

class CatalogMeshColorOptionsDto {
  const CatalogMeshColorOptionsDto({
    required this.meshId,
    required this.defaultColor,
    required this.allowedColors,
  });

  final String meshId;
  final String defaultColor;
  final List<String> allowedColors;

  factory CatalogMeshColorOptionsDto.fromJson(
    String meshId,
    Map<String, Object?> json,
  ) {
    final allowed = json['allowed'];
    if (allowed is! List<Object?>) {
      throw CatalogApiException(
        'meshColorConfig.$meshId.allowed must be an array',
      );
    }

    return CatalogMeshColorOptionsDto(
      meshId: meshId,
      defaultColor: _expectString(
        json['default'],
        'meshColorConfig.$meshId.default',
      ),
      allowedColors: [
        for (final color in allowed)
          _expectString(color, 'meshColorConfig.$meshId.allowed color'),
      ],
    );
  }

  CatalogMeshColorOptions toDomain() {
    return CatalogMeshColorOptions(
      meshId: meshId,
      defaultColor: defaultColor,
      allowedColors: allowedColors,
    );
  }
}

List<CatalogMeshColorOptionsDto> _parseMeshColorConfig(Object? value) {
  if (value == null) {
    return const [];
  }
  final config = _expectMap(value, 'meshColorConfig');
  return [
    for (final entry in config.entries)
      CatalogMeshColorOptionsDto.fromJson(
        entry.key,
        _expectMap(entry.value, 'meshColorConfig.${entry.key}'),
      ),
  ];
}

List<CatalogCategoryDto> _parseCategories(Object? value) {
  if (value == null) {
    return const [];
  }
  final categories = value;
  if (categories is! List<Object?>) {
    throw const CatalogApiException('categories must be an array');
  }
  return [
    for (final category in categories)
      CatalogCategoryDto.fromJson(_expectMap(category, 'category')),
  ];
}

CategoryProductSort? _parseOptionalCategorySort(Object? value) {
  final sort = _expectOptionalString(value, 'sort');
  return sort == null ? null : CategoryProductSort.parse(sort);
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
