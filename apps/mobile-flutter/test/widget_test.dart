import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_studio_mobile/app/app.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';

void main() {
  test('ShellCubit changes selected tab', () {
    final cubit = ShellCubit();
    addTearDown(cubit.close);

    expect(cubit.state.selectedTab, CustomerTab.home);

    cubit.selectTab(CustomerTab.category);

    expect(cubit.state.selectedTab, CustomerTab.category);
  });

  testWidgets('customer shell exposes the three bottom navigation tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LuminStudioApp(catalogRepository: _FakeCatalogRepository.empty()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('No catalog products yet'), findsOneWidget);
  });

  testWidgets('customer shell switches tabs without losing scroll state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LuminStudioApp(
        catalogRepository: _FakeCatalogRepository.withProducts(16),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const PageStorageKey<String>('home-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    expect(find.text('Product 6'), findsOneWidget);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.text('No categories yet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Product 6'), findsOneWidget);
  });

  testWidgets('each tab keeps its nested navigation state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LuminStudioApp(catalogRepository: _FakeCatalogRepository.empty()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Home detail'));
    await tester.pumpAndSettle();
    expect(find.text('Home state retained'), findsOneWidget);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.text('No categories yet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home state retained'), findsOneWidget);
  });

  testWidgets('home tab renders catalog products from the API repository', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LuminStudioApp(catalogRepository: _FakeCatalogRepository.withProducts(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 2'), findsOneWidget);
    expect(find.text('360 preview ready'), findsOneWidget);
  });

  testWidgets('home tab exposes a retry state when catalog loading fails', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.failure();
    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Catalog is unavailable'), findsOneWidget);

    repository.page = _catalogPage(1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Product 1'), findsOneWidget);
  });
}

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this.page, {this.shouldFail = false});

  _FakeCatalogRepository.empty() : this(_catalogPage(0));

  _FakeCatalogRepository.withProducts(int count) : this(_catalogPage(count));

  _FakeCatalogRepository.failure() : this(_catalogPage(0), shouldFail: true);

  CatalogProductsPage page;
  bool shouldFail;

  @override
  Future<CatalogProductsPage> listProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    if (shouldFail) {
      shouldFail = false;
      throw StateError('catalog unavailable');
    }
    return page;
  }
}

CatalogProductsPage _catalogPage(int count) {
  return CatalogProductsPage(
    items: [
      for (var index = 1; index <= count; index += 1)
        CatalogProduct(
          id: 'prod_$index',
          name: 'Product $index',
          slug: 'product-$index',
          description: 'Customer-safe description for product $index',
          processingStatus: index.isEven ? 'completed' : 'queued',
          updatedAt: DateTime.utc(2026, 6, 16, 12, index),
          spriteAsset: index.isEven
              ? const CatalogObjectRef(
                  bucket: 'lumin-360-sprites',
                  key: 'products/prod_2/prod_2_360_sprite.jpg',
                )
              : null,
        ),
    ],
    total: count,
    limit: 20,
    offset: 0,
  );
}
