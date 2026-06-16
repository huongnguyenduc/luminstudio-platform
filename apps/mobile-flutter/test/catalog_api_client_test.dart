import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_studio_mobile/features/catalog/data/catalog_api_client.dart';

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
  "offset": 0
}
''')
            as Map<String, Object?>;

    final page = CatalogProductsDto.fromJson(decoded).toDomain();

    expect(page.total, 1);
    expect(page.items.single.name, 'Ceramic Pendant');
    expect(page.items.single.hasPreview, isTrue);
    expect(page.items.single.spriteAsset?.bucket, 'lumin-360-sprites');
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
}
