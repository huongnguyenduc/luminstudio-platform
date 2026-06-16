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

  testWidgets('home tab searches catalog products through the API repository', (
    WidgetTester tester,
  ) async {
    final repository = _FakeCatalogRepository.withProducts(3);
    repository.searchPage = _catalogPage(1, namePrefix: 'Pendant');

    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
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

    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
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
    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
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

    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
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

    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
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

    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
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

    await tester.pumpWidget(LuminStudioApp(catalogRepository: repository));
    await tester.pumpAndSettle();

    await _loadMoreThroughHome(tester);

    expect(find.text('More catalog products are unavailable'), findsOneWidget);
    expect(find.text('Product 1'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.listOffsets, containsAll(<int>[0, 2]));
    expect(find.text('Product 4'), findsOneWidget);
  });
}

Future<void> _loadMoreThroughHome(WidgetTester tester) async {
  await _scrollHomeDown(tester);

  if (tester.any(find.text('Load more'))) {
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollHomeDown(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const PageStorageKey<String>('home-scroll')),
    const Offset(0, -420),
  );
  await tester.pumpAndSettle();
}

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this.page, {this.shouldFail = false});

  _FakeCatalogRepository.empty() : this(_catalogPage(0));

  _FakeCatalogRepository.withProducts(int count) : this(_catalogPage(count));

  _FakeCatalogRepository.pagedProducts(int count, {int pageSize = 20})
    : page = _catalogPageSlice(count: count),
      pagedTotal = count,
      pagedPageSize = pageSize,
      shouldFail = false;

  _FakeCatalogRepository.failure() : this(_catalogPage(0), shouldFail: true);

  CatalogProductsPage page;
  CatalogProductsPage searchPage = _catalogPage(0);
  int? pagedTotal;
  int pagedPageSize = 20;
  int? searchTotal;
  int searchPageSize = 20;
  String searchNamePrefix = 'Search Hit';
  bool shouldFail;
  bool shouldFailSearch = false;
  bool shouldFailNextPage = false;
  String? lastSearchQuery;
  final List<int> listOffsets = [];
  final List<int> searchOffsets = [];

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
}

CatalogProductsPage _catalogPage(int count, {String namePrefix = 'Product'}) {
  return _catalogPageSlice(count: count, namePrefix: namePrefix);
}

CatalogProductsPage _catalogPageSlice({
  required int count,
  int limit = 20,
  int offset = 0,
  String namePrefix = 'Product',
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
    limit: limit,
    offset: offset,
  );
}
