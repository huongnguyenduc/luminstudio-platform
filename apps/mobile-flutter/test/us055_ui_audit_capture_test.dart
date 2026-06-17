import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_studio_mobile/app/app.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('captures US-055 Home audit screenshot', (
    WidgetTester tester,
  ) async {
    await _pumpAuditApp(tester);

    expect(find.text('Arc chair'), findsOneWidget);
    expect(find.text('Line lamp'), findsOneWidget);
    expect(find.text('360 preview ready'), findsWidgets);

    await _capture(tester, 'us055-home.png');
  });

  testWidgets('captures US-055 Category audit screenshot', (
    WidgetTester tester,
  ) async {
    await _pumpAuditApp(tester);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    expect(find.text('Chairs'), findsWidgets);
    expect(find.text('Arc chair'), findsOneWidget);
    expect(find.text('Sort products'), findsOneWidget);

    await _capture(tester, 'us055-category.png');
  });

  testWidgets('captures US-055 Product Detail top audit screenshot', (
    WidgetTester tester,
  ) async {
    await _pumpAuditApp(tester);

    await tester.tap(find.text('Arc chair'));
    await tester.pumpAndSettle();

    expect(find.text('HIGH model'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('audit-model-viewer-prod_arc')),
      findsOneWidget,
    );
    expect(find.text('Add to cart'), findsOneWidget);
    expect(find.text('Selected finish'), findsNothing);
    expect(find.text('Customize color'), findsOneWidget);

    await _capture(tester, 'us055-detail-top.png');
  });

  testWidgets('captures US-055 Product Detail customization audit screenshot', (
    WidgetTester tester,
  ) async {
    await _pumpAuditApp(tester);

    await tester.tap(find.text('Arc chair'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey<String>('product-detail-scroll')),
      const Offset(0, -430),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customize color'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Body Chalk ceramic'), findsOneWidget);
    expect(find.text('Product information'), findsOneWidget);

    await _capture(tester, 'us055-detail-customization.png');
  });

  testWidgets('captures US-055 Cart audit screenshot', (
    WidgetTester tester,
  ) async {
    await _pumpAuditApp(tester);

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Cart summary'), findsOneWidget);
    expect(find.text('Arc chair'), findsOneWidget);
    expect(find.text('Body: #0F172A'), findsOneWidget);

    await _capture(tester, 'us055-cart.png');
  });
}

Future<void> _pumpAuditApp(WidgetTester tester) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => binding.setSurfaceSize(null));

  await tester.pumpWidget(
    LuminStudioApp(
      catalogRepository: _AuditCatalogRepository(),
      cartRepository: _AuditCartRepository(),
      deviceTierResolver: const FixedDeviceTierResolver(ProductModelTier.high),
      productModelViewerBuilder: _auditProductModelViewerBuilder,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String fileName) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../../reports/ui-ux-review/$fileName'),
  );
}

Widget _auditProductModelViewerBuilder(
  BuildContext context,
  CatalogProductDetail detail,
) {
  return Semantics(
    label: 'Audit 3D viewer placeholder for ${detail.name}',
    child: Container(
      key: ValueKey<String>('audit-model-viewer-${detail.id}'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.view_in_ar,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Interactive 3D viewer',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    ),
  );
}

class _AuditCartRepository implements CartRepository {
  List<CartItem> _items = const [
    CartItem(
      productId: 'prod_arc',
      productName: 'Arc chair',
      amountCents: 12900,
      currency: 'USD',
      compareAtAmountCents: 15900,
      selectedColors: {'mesh_body': '#0F172A'},
      quantity: 1,
      isSelected: true,
    ),
  ];

  @override
  Future<List<CartItem>> loadCart() async {
    return List<CartItem>.of(_items);
  }

  @override
  Future<void> saveCart(List<CartItem> items) async {
    _items = List<CartItem>.of(items);
  }
}

class _AuditCatalogRepository implements CatalogRepository {
  static const _chairs = CatalogCategory(slug: 'chairs', name: 'Chairs');
  static const _lighting = CatalogCategory(slug: 'lighting', name: 'Lighting');
  static const _objects = CatalogCategory(slug: 'objects', name: 'Objects');
  static const _categories = [_chairs, _lighting, _objects];

  @override
  Future<List<CatalogCategory>> listCategories() async {
    return _categories;
  }

  @override
  Future<CatalogProductsPage> listProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    return CatalogProductsPage(
      items: _products,
      total: _products.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<CatalogProductsPage> searchProducts(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final normalized = query.toLowerCase();
    final matches = _products
        .where((product) => product.name.toLowerCase().contains(normalized))
        .toList();
    return CatalogProductsPage(
      items: matches,
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<CatalogProductsPage> listCategoryProducts(
    String categorySlug, {
    CategoryProductSort sort = CategoryProductSort.newest,
    int limit = 20,
    int offset = 0,
  }) async {
    final matches = _products
        .where(
          (product) => product.categories.any(
            (category) => category.slug == categorySlug,
          ),
        )
        .toList();
    return CatalogProductsPage(
      items: matches,
      total: matches.length,
      limit: limit,
      offset: offset,
      categorySlug: categorySlug,
      sort: sort,
    );
  }

  @override
  Future<CatalogProductDetail> getProductDetail(
    String productId, {
    required ProductModelTier tier,
  }) async {
    final product = _products.firstWhere((item) => item.id == productId);
    return CatalogProductDetail(
      id: product.id,
      name: product.name,
      slug: product.slug,
      description: product.description,
      price: product.price,
      categories: product.categories,
      informationSections: const [
        CatalogInformationSection(
          title: 'Materials',
          body: 'Molded oak shell with brushed steel supports.',
        ),
        CatalogInformationSection(
          title: 'Care',
          body: 'Wipe clean with a damp cloth before daily use.',
        ),
      ],
      meshColorConfig: const [
        CatalogMeshColorOptions(
          meshId: 'mesh_body',
          defaultColor: '#FFFFFF',
          allowedColors: ['#FFFFFF', '#0F172A', '#C8A46A'],
          colorLabels: {
            '#FFFFFF': 'Chalk ceramic',
            '#0F172A': 'Deep navy',
            '#C8A46A': 'Aged brass',
          },
        ),
      ],
      processingStatus: product.processingStatus,
      modelTier: tier,
      modelAsset: CatalogObjectRef(
        bucket: tier == ProductModelTier.high
            ? 'lumin-source-glb'
            : 'lumin-optimized-glb',
        key: 'products/$productId/model.glb',
        contentType: 'model/gltf-binary',
      ),
      modelUri: Uri.parse(
        'http://api.test/catalog/products/$productId/model?tier=${tier.wireName}',
      ),
      spriteAsset: product.spriteAsset,
      spriteUri: Uri.parse(
        'http://api.test/catalog/products/$productId/sprite',
      ),
      updatedAt: product.updatedAt,
    );
  }

  static final _products = [
    CatalogProduct(
      id: 'prod_arc',
      name: 'Arc chair',
      slug: 'arc-chair',
      description: 'A compact lounge chair with a configurable finish.',
      price: const CatalogPrice(
        amountCents: 12900,
        currency: 'USD',
        compareAtAmountCents: 15900,
      ),
      categories: const [_chairs],
      processingStatus: 'completed',
      updatedAt: DateTime.utc(2026, 6, 16, 12),
      spriteAsset: const CatalogObjectRef(
        bucket: 'lumin-360-sprites',
        key: 'products/prod_arc/prod_arc_360_sprite.jpg',
        contentType: 'image/jpeg',
      ),
      spritePreviewUri: Uri.parse(
        'http://api.test/catalog/products/prod_arc/sprite',
      ),
    ),
    CatalogProduct(
      id: 'prod_line',
      name: 'Line lamp',
      slug: 'line-lamp',
      description: 'A slim task lamp for small desks and nightstands.',
      price: const CatalogPrice(amountCents: 8900, currency: 'USD'),
      categories: const [_lighting],
      processingStatus: 'completed',
      updatedAt: DateTime.utc(2026, 6, 16, 11),
      spriteAsset: const CatalogObjectRef(
        bucket: 'lumin-360-sprites',
        key: 'products/prod_line/prod_line_360_sprite.jpg',
        contentType: 'image/jpeg',
      ),
      spritePreviewUri: Uri.parse(
        'http://api.test/catalog/products/prod_line/sprite',
      ),
    ),
    CatalogProduct(
      id: 'prod_dock',
      name: 'Dock tray',
      slug: 'dock-tray',
      description: 'A low-profile tray for entry tables and shelves.',
      price: const CatalogPrice(amountCents: 5400, currency: 'USD'),
      categories: const [_objects],
      processingStatus: 'queued',
      updatedAt: DateTime.utc(2026, 6, 16, 10),
    ),
  ];
}
