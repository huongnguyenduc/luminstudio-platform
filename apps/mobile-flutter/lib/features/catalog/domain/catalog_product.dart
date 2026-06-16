class CatalogObjectRef {
  const CatalogObjectRef({
    required this.bucket,
    required this.key,
    this.contentType,
    this.sizeBytes,
  });

  final String bucket;
  final String key;
  final String? contentType;
  final int? sizeBytes;
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.processingStatus,
    required this.updatedAt,
    this.spriteAsset,
    this.spritePreviewUri,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String processingStatus;
  final DateTime updatedAt;
  final CatalogObjectRef? spriteAsset;
  final Uri? spritePreviewUri;

  bool get hasPreview => spriteAsset != null;

  CatalogProduct copyWith({Uri? spritePreviewUri}) {
    return CatalogProduct(
      id: id,
      name: name,
      slug: slug,
      description: description,
      processingStatus: processingStatus,
      updatedAt: updatedAt,
      spriteAsset: spriteAsset,
      spritePreviewUri: spritePreviewUri ?? this.spritePreviewUri,
    );
  }
}

enum ProductModelTier {
  low('low'),
  high('high');

  const ProductModelTier(this.wireName);

  final String wireName;

  static ProductModelTier parse(String value) {
    return switch (value) {
      'low' => ProductModelTier.low,
      'high' => ProductModelTier.high,
      _ => throw ArgumentError.value(value, 'value', 'unsupported model tier'),
    };
  }
}

class CatalogInformationSection {
  const CatalogInformationSection({required this.title, required this.body});

  final String title;
  final String body;
}

class CatalogMeshColorOptions {
  const CatalogMeshColorOptions({
    required this.meshId,
    required this.defaultColor,
    required this.allowedColors,
  });

  final String meshId;
  final String defaultColor;
  final List<String> allowedColors;
}

class CatalogProductDetail {
  const CatalogProductDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.informationSections,
    required this.meshColorConfig,
    required this.processingStatus,
    required this.modelTier,
    required this.updatedAt,
    this.modelAsset,
    this.modelUri,
    this.spriteAsset,
    this.spriteUri,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final List<CatalogInformationSection> informationSections;
  final List<CatalogMeshColorOptions> meshColorConfig;
  final String processingStatus;
  final ProductModelTier modelTier;
  final CatalogObjectRef? modelAsset;
  final Uri? modelUri;
  final CatalogObjectRef? spriteAsset;
  final Uri? spriteUri;
  final DateTime updatedAt;
}

class CatalogProductsPage {
  const CatalogProductsPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<CatalogProduct> items;
  final int total;
  final int limit;
  final int offset;
}
