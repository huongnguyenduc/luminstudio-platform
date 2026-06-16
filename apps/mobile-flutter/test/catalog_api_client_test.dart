import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_studio_mobile/features/catalog/data/catalog_api_client.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';

void main() {
  test('CatalogProductsDto parses the v1 catalog response shape', () {
    final decoded =
        jsonDecode('''
{
  "items": [
    {
      "id": "prod_123",
      "name": "Ceramic Pendant",
      "slug": "ceramic-pendant",
      "description": "A customer-safe catalog description.",
      "processingStatus": "completed",
      "spriteAsset": {
        "bucket": "lumin-360-sprites",
        "key": "products/prod_123/prod_123_360_sprite.jpg",
        "contentType": "image/jpeg",
        "sizeBytes": 2048
      },
      "updatedAt": "2026-06-16T05:30:00Z"
    }
  ],
      "total": 1,
      "limit": 20,
      "offset": 0,
      "query": "pendant"
}
''')
            as Map<String, Object?>;

    final page = CatalogProductsDto.fromJson(decoded).toDomain(
      spritePreviewUriFor: (productId) =>
          Uri.parse('http://api.test/catalog/products/$productId/sprite'),
    );

    expect(page.total, 1);
    expect(page.items.single.name, 'Ceramic Pendant');
    expect(page.items.single.hasPreview, isTrue);
    expect(page.items.single.spriteAsset?.bucket, 'lumin-360-sprites');
    expect(
      page.items.single.spritePreviewUri,
      Uri.parse('http://api.test/catalog/products/prod_123/sprite'),
    );
  });

  test('CatalogProductsDto accepts catalog search response query metadata', () {
    final page = CatalogProductsDto.fromJson({
      'items': <Object?>[],
      'total': 0,
      'limit': 20,
      'offset': 0,
      'query': 'chair',
    }).toDomain();

    expect(page.items, isEmpty);
    expect(page.total, 0);
  });

  test('CatalogProductsDto rejects malformed catalog responses', () {
    expect(
      () => CatalogProductsDto.fromJson({
        'items': 'not-an-array',
        'total': 0,
        'limit': 20,
        'offset': 0,
      }),
      throwsA(isA<CatalogApiException>()),
    );
  });

  test('ProductDetailDto parses the v1 product detail response shape', () {
    final decoded =
        jsonDecode('''
{
  "id": "prod_12345678",
  "name": "Ceramic Pendant",
  "slug": "ceramic-pendant",
  "description": "A configurable pendant.",
  "informationSections": [
    {"title": "Materials", "body": "Glazed ceramic and brass."}
  ],
  "meshColorConfig": {
    "mesh_body": {
      "default": "#FFFFFF",
      "allowed": ["#FFFFFF", "#0F172A"]
    }
  },
  "processingStatus": "completed",
  "modelTier": "high",
  "modelAsset": {
    "bucket": "lumin-source-glb",
    "key": "products/prod_12345678/source.glb",
    "contentType": "model/gltf-binary",
    "sizeBytes": 4096
  },
  "modelUrl": "/catalog/products/prod_12345678/model?tier=high",
  "spriteAsset": {
    "bucket": "lumin-360-sprites",
    "key": "products/prod_12345678/prod_12345678_360_sprite.jpg",
    "contentType": "image/jpeg",
    "sizeBytes": 2048
  },
  "spriteUrl": "/catalog/products/prod_12345678/sprite",
  "updatedAt": "2026-06-16T05:30:00Z"
}
''')
            as Map<String, Object?>;

    final detail = ProductDetailDto.fromJson(decoded).toDomain(
      routeUriFor: (routePath) => Uri.parse('http://api.test$routePath'),
    );

    expect(detail.id, 'prod_12345678');
    expect(detail.modelTier, ProductModelTier.high);
    expect(detail.informationSections.single.title, 'Materials');
    expect(detail.meshColorConfig.single.meshId, 'mesh_body');
    expect(detail.meshColorConfig.single.defaultColor, '#FFFFFF');
    expect(detail.modelAsset?.bucket, 'lumin-source-glb');
    expect(
      detail.modelUri,
      Uri.parse(
        'http://api.test/catalog/products/prod_12345678/model?tier=high',
      ),
    );
    expect(
      detail.spriteUri,
      Uri.parse('http://api.test/catalog/products/prod_12345678/sprite'),
    );
  });

  test('ProductDetailDto rejects malformed product detail responses', () {
    expect(
      () => ProductDetailDto.fromJson({
        'id': 'prod_12345678',
        'name': 'Ceramic Pendant',
        'slug': 'ceramic-pendant',
        'description': 'A configurable pendant.',
        'informationSections': 'not-an-array',
        'processingStatus': 'completed',
        'modelTier': 'low',
        'updatedAt': '2026-06-16T05:30:00Z',
      }),
      throwsA(isA<CatalogApiException>()),
    );
  });
}
