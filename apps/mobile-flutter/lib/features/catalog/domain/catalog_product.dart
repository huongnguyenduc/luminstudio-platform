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

class CatalogPrice {
  const CatalogPrice({
    required this.amountCents,
    required this.currency,
    this.compareAtAmountCents,
  });

  final int amountCents;
  final String currency;
  final int? compareAtAmountCents;

  int get savingsCents {
    final compareAt = compareAtAmountCents;
    if (compareAt == null || compareAt <= amountCents) {
      return 0;
    }
    return compareAt - amountCents;
  }
}

class CatalogCategory {
  const CatalogCategory({required this.slug, required this.name});

  final String slug;
  final String name;
}

enum CategoryProductSort {
  newest('newest', 'Newest'),
  priceAsc('price_asc', 'Price low to high'),
  priceDesc('price_desc', 'Price high to low'),
  nameAsc('name_asc', 'Name A to Z');

  const CategoryProductSort(this.wireName, this.label);

  final String wireName;
  final String label;

  static CategoryProductSort parse(String value) {
    return switch (value) {
      'newest' => CategoryProductSort.newest,
      'price_asc' => CategoryProductSort.priceAsc,
      'price_desc' => CategoryProductSort.priceDesc,
      'name_asc' => CategoryProductSort.nameAsc,
      _ => throw ArgumentError.value(
        value,
        'value',
        'unsupported category sort',
      ),
    };
  }
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.price,
    this.categories = const [],
    required this.processingStatus,
    required this.updatedAt,
    this.spriteAsset,
    this.spritePreviewUri,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final CatalogPrice price;
  final List<CatalogCategory> categories;
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
      price: price,
      categories: categories,
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
    required this.price,
    this.categories = const [],
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
  final CatalogPrice price;
  final List<CatalogCategory> categories;
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
    this.categorySlug,
    this.sort,
  });

  final List<CatalogProduct> items;
  final int total;
  final int limit;
  final int offset;
  final String? categorySlug;
  final CategoryProductSort? sort;
}
