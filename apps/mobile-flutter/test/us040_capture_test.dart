import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_studio_mobile/app/app.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('captures US-040 cart local persistence screenshot', (
    WidgetTester tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      LuminStudioApp(
        catalogRepository: const _EmptyCatalogRepository(),
        cartRepository: _SeededCartRepository(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Cart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Subtotal USD 258.00'), findsOneWidget);
    expect(find.text('mesh_body: #0F172A'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../reports/us-040/cart-local-persistence.png'),
    );
  });
}

class _SeededCartRepository implements CartRepository {
  @override
  Future<List<CartItem>> loadCart() async {
    return const [
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
    ];
  }

  @override
  Future<void> saveCart(List<CartItem> items) async {}
}

class _EmptyCatalogRepository implements CatalogRepository {
  const _EmptyCatalogRepository();

  @override
  Future<List<CatalogCategory>> listCategories() async {
    return const [];
  }

  @override
  Future<CatalogProductsPage> listProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    return const CatalogProductsPage(items: [], total: 0, limit: 20, offset: 0);
  }

  @override
  Future<CatalogProductsPage> searchProducts(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    return const CatalogProductsPage(items: [], total: 0, limit: 20, offset: 0);
  }

  @override
  Future<CatalogProductsPage> listCategoryProducts(
    String categorySlug, {
    CategoryProductSort sort = CategoryProductSort.newest,
    int limit = 20,
    int offset = 0,
  }) async {
    return const CatalogProductsPage(items: [], total: 0, limit: 20, offset: 0);
  }

  @override
  Future<CatalogProductDetail> getProductDetail(
    String productId, {
    required ProductModelTier tier,
  }) async {
    throw StateError('product detail is not used by the cart capture');
  }
}
