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
