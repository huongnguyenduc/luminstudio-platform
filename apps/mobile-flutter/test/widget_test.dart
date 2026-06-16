import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_studio_mobile/app/app.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_item.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/category_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_model_viewer.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

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
      _testApp(catalogRepository: _FakeCatalogRepository.empty()),
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
      _testApp(catalogRepository: _FakeCatalogRepository.withProducts(16)),
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
      _testApp(catalogRepository: _FakeCatalogRepository.empty()),
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

  testWidgets('category tab loads categories and first category products', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withCategories();

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    expect(find.text('Lighting'), findsWidgets);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Lighting Product 1'), findsOneWidget);
    expect(repository.lastCategorySlug, 'lighting');
    expect(repository.categoryOffsets, contains(0));
  });

  testWidgets('category tab changes product sort through the API repository', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withCategories();

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price high to low').last);
    await tester.pumpAndSettle();

    expect(repository.lastCategorySlug, 'lighting');
    expect(repository.categorySorts, contains(CategoryProductSort.priceDesc));
  });

  testWidgets('category tab paginates products and retries inline failures', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withCategories(
      productCount: 5,
      pageSize: 2,
    )..shouldFailNextCategoryPage = true;

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    await _loadMoreThroughCategory(tester);

    expect(find.text('More category products are unavailable'), findsOneWidget);
    expect(find.text('Lighting Product 1'), findsOneWidget);

    await _loadMoreThroughCategory(tester);
    await _loadMoreThroughCategory(tester);

    expect(repository.categoryOffsets, containsAll(<int>[0, 2, 4]));
    expect(find.text('Lighting Product 5'), findsOneWidget);
    await _scrollCategoryDown(tester);
    expect(find.text('All category products loaded'), findsOneWidget);
  });

  testWidgets('home tab renders catalog products from the API repository', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(catalogRepository: _FakeCatalogRepository.withProducts(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 2'), findsOneWidget);
    expect(find.text('360 preview ready'), findsOneWidget);
  });

  testWidgets('home tab searches catalog products through the API repository', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(3);
    repository.searchPage = _catalogPage(1, namePrefix: 'Pendant');

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'pendant');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.lastSearchQuery, 'pendant');
    expect(find.text('Pendant 1'), findsOneWidget);
    expect(find.text('Product 2'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Product 2'), findsOneWidget);
  });

  testWidgets('home tab renders empty search results', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(2);
    repository.searchPage = _catalogPage(0);

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'missing');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('No matching products'), findsOneWidget);
  });

  testWidgets('home tab exposes a retry state when catalog loading fails', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.failure();
    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Catalog is unavailable'), findsOneWidget);

    repository.page = _catalogPage(1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('home tab retries failed catalog searches', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(2);
    repository.shouldFailSearch = true;
    repository.searchPage = _catalogPage(1, namePrefix: 'Search Hit');

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'hit');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Search is unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Search Hit 1'), findsOneWidget);
  });

  testWidgets('home tab loads additional catalog pages near the list end', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.pagedProducts(5, pageSize: 2);

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 5'), findsNothing);

    await _loadMoreThroughHome(tester);
    await _loadMoreThroughHome(tester);

    expect(repository.listOffsets, containsAll(<int>[0, 2, 4]));
    expect(find.text('Product 5'), findsOneWidget);
    await _scrollHomeDown(tester);
    expect(find.text('All products loaded'), findsOneWidget);
  });

  testWidgets('home tab paginates search results without clearing the query', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.pagedProducts(2)
      ..searchTotal = 5
      ..searchPageSize = 2
      ..searchNamePrefix = 'Pendant';

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'pendant');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await _loadMoreThroughHome(tester);
    await _loadMoreThroughHome(tester);

    expect(repository.lastSearchQuery, 'pendant');
    expect(repository.searchOffsets, containsAll(<int>[0, 2, 4]));
    expect(find.text('Pendant 5'), findsOneWidget);
    await _scrollHomeDown(tester);
    expect(find.text('All search results loaded'), findsOneWidget);
  });

  testWidgets('home tab retries failed incremental catalog loads', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.pagedProducts(5, pageSize: 2)
      ..shouldFailNextPage = true;

    await tester.pumpWidget(_testApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    await _loadMoreThroughHome(tester);

    expect(find.text('More catalog products are unavailable'), findsOneWidget);
    expect(find.text('Product 1'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.listOffsets, containsAll(<int>[0, 2]));
    expect(find.text('Product 3'), findsOneWidget);
  });

  testWidgets('home tab activates a visible idle 360 sprite preview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(catalogRepository: _FakeCatalogRepository.previewProduct()),
    );
    await tester.pumpAndSettle();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey<String>('preview-prod_2')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url ==
                'http://api.test/catalog/products/prod_2/sprite',
      ),
      findsOneWidget,
    );
  });

  testWidgets('home tab cancels pending preview activation while scrolling', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(catalogRepository: _FakeCatalogRepository.withProducts(8)),
    );
    await tester.pumpAndSettle();

    VisibilityDetectorController.instance.notifyNow();
    await tester.pump(const Duration(seconds: 1));

    await tester.drag(
      find.byKey(const PageStorageKey<String>('home-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(
      find.bySemanticsLabel('360 preview active for Product 2'),
      findsNothing,
    );
  });

  testWidgets('home tab opens product detail with the resolved model tier', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(2);

    await tester.pumpWidget(
      _testApp(
        catalogRepository: repository,
        deviceTierResolver: const FixedDeviceTierResolver(
          ProductModelTier.high,
        ),
        productModelViewerBuilder: _fakeProductModelViewerBuilder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Product 1'));
    await tester.pumpAndSettle();

    expect(repository.lastDetailProductId, 'prod_1');
    expect(repository.lastDetailTier, ProductModelTier.high);
    expect(
      find.byKey(const ValueKey<String>('fake-model-viewer-prod_1')),
      findsOneWidget,
    );
    expect(find.text('Model tier: high'), findsOneWidget);
    expect(find.text('Selected finish'), findsOneWidget);
    await tester.drag(
      find.byKey(const PageStorageKey<String>('product-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    expect(find.text('Materials'), findsOneWidget);
    expect(find.text('Glazed ceramic and brass.'), findsOneWidget);
    expect(find.textContaining('/catalog/products/prod_1/model'), findsNothing);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('product detail renders the injected interactive model viewer', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(1);

    await tester.pumpWidget(
      _testApp(
        catalogRepository: repository,
        deviceTierResolver: const FixedDeviceTierResolver(ProductModelTier.low),
        productModelViewerBuilder: _fakeProductModelViewerBuilder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Product 1'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('fake-model-viewer-prod_1')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Model viewer: http://api.test/catalog/products/prod_1/model?tier=low',
      ),
      findsOneWidget,
    );
  });

  testWidgets('product detail lets customers select configured mesh colors', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(1);

    await tester.pumpWidget(
      _testApp(
        catalogRepository: repository,
        deviceTierResolver: const FixedDeviceTierResolver(ProductModelTier.low),
        productModelViewerBuilder: _fakeProductModelViewerBuilder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Product 1'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey<String>('product-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selected finish'), findsOneWidget);
    expect(find.text('Body #FFFFFF'), findsOneWidget);
    expect(
      find.bySemanticsLabel('mesh_body color #FFFFFF default selected'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('mesh-color-mesh_body-#0F172A')),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('mesh_body color #0F172A selected'),
      findsOneWidget,
    );
    expect(find.text('Body #0F172A'), findsOneWidget);
    expect(
      find.bySemanticsLabel('mesh_body color #FFFFFF default selected'),
      findsNothing,
    );
  });

  testWidgets(
    'product detail adds the selected configuration to the local cart',
    (WidgetTester tester) async {
      final cartRepository = _FakeCartRepository();

      await tester.pumpWidget(
        _testApp(
          catalogRepository: _FakeCatalogRepository.withProducts(1),
          cartRepository: cartRepository,
          deviceTierResolver: const FixedDeviceTierResolver(
            ProductModelTier.low,
          ),
          productModelViewerBuilder: _fakeProductModelViewerBuilder,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Product 1'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const PageStorageKey<String>('product-detail-scroll')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('mesh-color-mesh_body-#0F172A')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Body #0F172A'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('add-selected-product-to-cart')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Added to cart'), findsOneWidget);
      expect(cartRepository.items.single.productId, 'prod_1');
      expect(
        cartRepository.items.single.selectedColors['mesh_body'],
        '#0F172A',
      );
      expect(cartRepository.items.single.quantity, 1);
      expect(cartRepository.items.single.isSelected, isTrue);
      expect(cartRepository.items.single.amountCents, 12900);
      expect(cartRepository.items.single.compareAtAmountCents, 15900);

      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();

      expect(find.text('1 in cart, 1 selected'), findsOneWidget);
      expect(find.text('Subtotal USD 129.00'), findsOneWidget);
      expect(find.text('Savings USD 30.00'), findsOneWidget);
      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('Body: #0F172A'), findsOneWidget);
    },
  );

  testWidgets('cart tab updates quantity and selection state', (
    WidgetTester tester,
  ) async {
    final cartRepository = _FakeCartRepository(
      items: const [
        CartItem(
          productId: 'prod_1',
          productName: 'Product 1',
          amountCents: 12900,
          currency: 'USD',
          compareAtAmountCents: 15900,
          selectedColors: {'mesh_body': '#0F172A'},
          quantity: 1,
          isSelected: true,
        ),
      ],
    );

    await tester.pumpWidget(
      _testApp(
        catalogRepository: _FakeCatalogRepository.empty(),
        cartRepository: cartRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('1 in cart, 1 selected'), findsOneWidget);
    expect(find.text('Subtotal USD 129.00'), findsOneWidget);
    expect(find.text('Savings USD 30.00'), findsOneWidget);
    expect(find.text('Body: #0F172A'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase prod_1 quantity'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('cart-qty-prod_1')),
      findsOneWidget,
    );
    expect(cartRepository.items.single.quantity, 2);
    expect(find.text('2 in cart, 2 selected'), findsOneWidget);
    expect(find.text('Subtotal USD 258.00'), findsOneWidget);
    expect(find.text('Savings USD 60.00'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(cartRepository.items.single.isSelected, isFalse);
    expect(find.text('2 in cart, 0 selected'), findsOneWidget);
    expect(find.text('Subtotal USD 258.00'), findsNothing);
  });

  testWidgets('cart tab shows backend sync state during mutations', (
    WidgetTester tester,
  ) async {
    final cartRepository = _SlowCartRepository(
      items: const [
        CartItem(
          productId: 'prod_1',
          productName: 'Product 1',
          amountCents: 12900,
          currency: 'USD',
          compareAtAmountCents: 15900,
          selectedColors: {'mesh_body': '#0F172A'},
          quantity: 1,
          isSelected: true,
        ),
      ],
    );

    await tester.pumpWidget(
      _testApp(
        catalogRepository: _FakeCatalogRepository.empty(),
        cartRepository: cartRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase prod_1 quantity'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('cart-sync-progress')),
      findsOneWidget,
    );
    expect(find.text('Syncing cart'), findsOneWidget);

    cartRepository.completeSave();
    await tester.pumpAndSettle();

    expect(find.text('Syncing cart'), findsNothing);
    expect(cartRepository.items.single.quantity, 2);
  });

  testWidgets(
    'product detail renders unavailable model state without a model route',
    (WidgetTester tester) async {
      final repository = _FakeCatalogRepository.withProducts(1)
        ..detailWithoutModelRoute = true;

      await tester.pumpWidget(
        _testApp(
          catalogRepository: repository,
          deviceTierResolver: const FixedDeviceTierResolver(
            ProductModelTier.low,
          ),
          productModelViewerBuilder: _fakeProductModelViewerBuilder,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Product 1'));
      await tester.pumpAndSettle();

      expect(find.text('3D model unavailable'), findsOneWidget);
    },
  );

  testWidgets('product detail exposes failure and retry states', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(1)
      ..shouldFailDetail = true;

    await tester.pumpWidget(
      _testApp(
        catalogRepository: repository,
        deviceTierResolver: const FixedDeviceTierResolver(ProductModelTier.low),
        productModelViewerBuilder: _fakeProductModelViewerBuilder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Product 1'));
    await tester.pumpAndSettle();

    expect(find.text('Product detail is unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Model tier: low'), findsOneWidget);
  });

  testWidgets('home tab retains product detail route when switching tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        catalogRepository: _FakeCatalogRepository.withProducts(2),
        deviceTierResolver: const FixedDeviceTierResolver(ProductModelTier.low),
        productModelViewerBuilder: _fakeProductModelViewerBuilder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Product 1'));
    await tester.pumpAndSettle();
    expect(find.text('Model tier: low'), findsOneWidget);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.text('No categories yet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Model tier: low'), findsOneWidget);
  });
}

Widget _testApp({
  required CatalogRepository catalogRepository,
  CartRepository? cartRepository,
  DeviceTierResolver deviceTierResolver = const DefaultDeviceTierResolver(),
  ProductModelViewerBuilder productModelViewerBuilder =
      defaultProductModelViewerBuilder,
}) {
  return LuminStudioApp(
    catalogRepository: catalogRepository,
    cartRepository: cartRepository ?? _FakeCartRepository(),
    deviceTierResolver: deviceTierResolver,
    productModelViewerBuilder: productModelViewerBuilder,
  );
}

Widget _fakeProductModelViewerBuilder(
  BuildContext context,
  CatalogProductDetail detail,
) {
  final modelUri = detail.modelUri;
  if (modelUri == null) {
    return const Center(child: Text('3D model unavailable'));
  }

  return Semantics(
    label: 'Interactive 3D viewer for ${detail.name}',
    child: Container(
      key: ValueKey<String>('fake-model-viewer-${detail.id}'),
      alignment: Alignment.center,
      child: Text('Model viewer: $modelUri'),
    ),
  );
}

Future<void> _loadMoreThroughHome(WidgetTester tester) async {
  await _scrollHomeDown(tester);

  if (tester.any(find.text('Load more'))) {
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
  }
}

Future<void> _loadMoreThroughCategory(WidgetTester tester) async {
  tester
      .element(find.byKey(const PageStorageKey<String>('category-scroll')))
      .read<CategoryCubit>()
      .loadMoreProducts();
  await tester.pumpAndSettle();
}

Future<void> _scrollHomeDown(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const PageStorageKey<String>('home-scroll')),
    const Offset(0, -420),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollCategoryDown(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const PageStorageKey<String>('category-scroll')),
    const Offset(0, -620),
  );
  await tester.pumpAndSettle();
}

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this.page, {this.shouldFail = false});

  _FakeCatalogRepository.empty() : this(_catalogPage(0));

  _FakeCatalogRepository.withProducts(int count) : this(_catalogPage(count));

  _FakeCatalogRepository.previewProduct() : this(_catalogPreviewPage());

  _FakeCatalogRepository.withCategories({
    int productCount = 3,
    int pageSize = 20,
  }) : page = _catalogPage(0),
       categories = const [
         CatalogCategory(slug: 'lighting', name: 'Lighting'),
         CatalogCategory(slug: 'tables', name: 'Tables'),
       ],
       categoryTotal = productCount,
       categoryPageSize = pageSize,
       shouldFail = false;

  _FakeCatalogRepository.pagedProducts(int count, {int pageSize = 20})
    : page = _catalogPageSlice(count: count),
      pagedTotal = count,
      pagedPageSize = pageSize,
      shouldFail = false;

  _FakeCatalogRepository.failure() : this(_catalogPage(0), shouldFail: true);

  CatalogProductsPage page;
  CatalogProductsPage searchPage = _catalogPage(0);
  List<CatalogCategory> categories = const [];
  int? pagedTotal;
  int pagedPageSize = 20;
  int? searchTotal;
  int searchPageSize = 20;
  String searchNamePrefix = 'Search Hit';
  int? categoryTotal;
  int categoryPageSize = 20;
  bool shouldFail;
  bool shouldFailSearch = false;
  bool shouldFailNextPage = false;
  bool shouldFailCategories = false;
  bool shouldFailCategoryProducts = false;
  bool shouldFailNextCategoryPage = false;
  bool shouldFailDetail = false;
  bool detailWithoutModelRoute = false;
  String? lastSearchQuery;
  String? lastCategorySlug;
  String? lastDetailProductId;
  ProductModelTier? lastDetailTier;
  final List<int> listOffsets = [];
  final List<int> searchOffsets = [];
  final List<int> categoryOffsets = [];
  final List<CategoryProductSort> categorySorts = [];

  @override
  Future<List<CatalogCategory>> listCategories() async {
    if (shouldFailCategories) {
      shouldFailCategories = false;
      throw StateError('categories unavailable');
    }
    return List<CatalogCategory>.of(categories);
  }

  @override
  Future<CatalogProductsPage> listProducts({
    int limit = 20,
    int offset = 0,
  }) async {
    listOffsets.add(offset);
    if (shouldFail) {
      shouldFail = false;
      throw StateError('catalog unavailable');
    }
    if (shouldFailNextPage && offset > 0) {
      shouldFailNextPage = false;
      throw StateError('next catalog page unavailable');
    }
    final total = pagedTotal;
    if (total != null) {
      return _catalogPageSlice(
        count: total,
        limit: pagedPageSize,
        offset: offset,
      );
    }
    return page;
  }

  @override
  Future<CatalogProductsPage> searchProducts(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    lastSearchQuery = query;
    searchOffsets.add(offset);
    if (shouldFailSearch) {
      shouldFailSearch = false;
      throw StateError('search unavailable');
    }
    final total = searchTotal;
    if (total != null) {
      return _catalogPageSlice(
        count: total,
        limit: searchPageSize,
        offset: offset,
        namePrefix: searchNamePrefix,
      );
    }
    return searchPage;
  }

  @override
  Future<CatalogProductsPage> listCategoryProducts(
    String categorySlug, {
    CategoryProductSort sort = CategoryProductSort.newest,
    int limit = 20,
    int offset = 0,
  }) async {
    lastCategorySlug = categorySlug;
    categoryOffsets.add(offset);
    categorySorts.add(sort);
    if (shouldFailCategoryProducts) {
      shouldFailCategoryProducts = false;
      throw StateError('category products unavailable');
    }
    if (shouldFailNextCategoryPage && offset > 0) {
      shouldFailNextCategoryPage = false;
      throw StateError('next category page unavailable');
    }
    return _catalogPageSlice(
      count: categoryTotal ?? 0,
      limit: categoryPageSize,
      offset: offset,
      namePrefix: '${_categoryName(categorySlug)} Product',
      category: _findCategory(categorySlug),
      categorySlug: categorySlug,
      sort: sort,
    );
  }

  @override
  Future<CatalogProductDetail> getProductDetail(
    String productId, {
    required ProductModelTier tier,
  }) async {
    lastDetailProductId = productId;
    lastDetailTier = tier;
    if (shouldFailDetail) {
      shouldFailDetail = false;
      throw StateError('detail unavailable');
    }
    return _catalogProductDetail(
      productId,
      tier,
      includeModelRoute: !detailWithoutModelRoute,
    );
  }

  CatalogCategory? _findCategory(String slug) {
    for (final category in categories) {
      if (category.slug == slug) {
        return category;
      }
    }
    return null;
  }
}

String _categoryName(String slug) {
  return switch (slug) {
    'lighting' => 'Lighting',
    'tables' => 'Tables',
    _ => slug,
  };
}

class _FakeCartRepository implements CartRepository {
  _FakeCartRepository({List<CartItem> items = const <CartItem>[]})
    : items = List<CartItem>.of(items);

  List<CartItem> items;

  @override
  Future<List<CartItem>> loadCart() async {
    return List<CartItem>.of(items);
  }

  @override
  Future<void> saveCart(List<CartItem> items) async {
    this.items = List<CartItem>.of(items);
  }
}

class _SlowCartRepository extends _FakeCartRepository {
  _SlowCartRepository({super.items});

  Completer<void>? _pendingSave;

  @override
  Future<void> saveCart(List<CartItem> items) async {
    this.items = List<CartItem>.of(items);
    _pendingSave = Completer<void>();
    return _pendingSave!.future;
  }

  void completeSave() {
    _pendingSave?.complete();
    _pendingSave = null;
  }
}

CatalogProductDetail _catalogProductDetail(
  String productId,
  ProductModelTier tier, {
  bool includeModelRoute = true,
}) {
  return CatalogProductDetail(
    id: productId,
    name: 'Product ${productId.split('_').last}',
    slug: 'product-${productId.split('_').last}',
    description: 'Customer-safe detail for $productId',
    price: const CatalogPrice(
      amountCents: 12900,
      currency: 'USD',
      compareAtAmountCents: 15900,
    ),
    informationSections: const [
      CatalogInformationSection(
        title: 'Materials',
        body: 'Glazed ceramic and brass.',
      ),
    ],
    meshColorConfig: const [
      CatalogMeshColorOptions(
        meshId: 'mesh_body',
        defaultColor: '#FFFFFF',
        allowedColors: ['#FFFFFF', '#0F172A'],
      ),
    ],
    processingStatus: 'completed',
    modelTier: tier,
    modelAsset: CatalogObjectRef(
      bucket: tier == ProductModelTier.high
          ? 'lumin-source-glb'
          : 'lumin-optimized-glb',
      key: 'products/$productId/model.glb',
      contentType: 'model/gltf-binary',
    ),
    modelUri: includeModelRoute
        ? Uri.parse(
            'http://api.test/catalog/products/$productId/model?tier=${tier.wireName}',
          )
        : null,
    spriteAsset: const CatalogObjectRef(
      bucket: 'lumin-360-sprites',
      key: 'products/prod_1/prod_1_360_sprite.jpg',
      contentType: 'image/jpeg',
    ),
    spriteUri: Uri.parse('http://api.test/catalog/products/$productId/sprite'),
    updatedAt: DateTime.utc(2026, 6, 16, 12),
  );
}

CatalogProductsPage _catalogPage(int count, {String namePrefix = 'Product'}) {
  return _catalogPageSlice(count: count, namePrefix: namePrefix);
}

CatalogProductsPage _catalogPreviewPage() {
  return CatalogProductsPage(
    items: [
      CatalogProduct(
        id: 'prod_2',
        name: 'Product 2',
        slug: 'product-2',
        description: 'Customer-safe description for Product 2',
        price: const CatalogPrice(amountCents: 12900, currency: 'USD'),
        processingStatus: 'completed',
        updatedAt: DateTime.utc(2026, 6, 16, 12, 2),
        spriteAsset: const CatalogObjectRef(
          bucket: 'lumin-360-sprites',
          key: 'products/prod_2/prod_2_360_sprite.jpg',
        ),
        spritePreviewUri: Uri.parse(
          'http://api.test/catalog/products/prod_2/sprite',
        ),
      ),
    ],
    total: 1,
    limit: 20,
    offset: 0,
  );
}

CatalogProductsPage _catalogPageSlice({
  required int count,
  int limit = 20,
  int offset = 0,
  String namePrefix = 'Product',
  CatalogCategory? category,
  String? categorySlug,
  CategoryProductSort? sort,
}) {
  final end = (offset + limit) > count ? count : offset + limit;

  return CatalogProductsPage(
    items: [
      for (var index = offset + 1; index <= end; index += 1)
        CatalogProduct(
          id: 'prod_$index',
          name: '$namePrefix $index',
          slug: '${namePrefix.toLowerCase().replaceAll(' ', '-')}-$index',
          description: 'Customer-safe description for $namePrefix $index',
          price: const CatalogPrice(amountCents: 12900, currency: 'USD'),
          categories: category == null ? const [] : [category],
          processingStatus: index.isEven ? 'completed' : 'queued',
          updatedAt: DateTime.utc(2026, 6, 16, 12, index),
          spriteAsset: index.isEven
              ? const CatalogObjectRef(
                  bucket: 'lumin-360-sprites',
                  key: 'products/prod_2/prod_2_360_sprite.jpg',
                )
              : null,
          spritePreviewUri: index.isEven
              ? Uri.parse('http://api.test/catalog/products/prod_$index/sprite')
              : null,
        ),
    ],
    total: count,
    limit: limit,
    offset: offset,
    categorySlug: categorySlug,
    sort: sort,
  );
}
