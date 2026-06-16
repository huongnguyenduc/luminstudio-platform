import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumin_studio_mobile/app/app.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const apiBaseUrl = String.fromEnvironment('LUMIN_API_BASE_URL');
  const productId = String.fromEnvironment('LUMIN_US050_PRODUCT_ID');
  const productName = String.fromEnvironment('LUMIN_US050_PRODUCT_NAME');
  const categoryName = String.fromEnvironment('LUMIN_US050_CATEGORY_NAME');
  const meshId = String.fromEnvironment('LUMIN_US050_MESH_ID');
  const meshColor = String.fromEnvironment('LUMIN_US050_MESH_COLOR');

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('US-050 drives live customer commerce flow on simulator', (
    tester,
  ) async {
    expect(apiBaseUrl, isNotEmpty);
    expect(productId, isNotEmpty);
    expect(productName, isNotEmpty);
    expect(categoryName, isNotEmpty);
    expect(meshId, isNotEmpty);
    expect(meshColor, isNotEmpty);

    await tester.pumpWidget(
      LuminStudioApp(
        deviceTierResolver: const FixedDeviceTierResolver(
          ProductModelTier.high,
        ),
        productModelViewerBuilder: _smokeModelViewer,
      ),
    );

    await _pumpUntilVisible(tester, find.text(productName));
    expect(find.text('360 preview ready'), findsWidgets);

    await tester.enterText(find.byType(SearchBar), productName);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpUntilVisible(tester, find.text(productName));

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text(categoryName));
    await _pumpUntilVisible(tester, find.text(productName));

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    final homeProductCard = find.byKey(
      ValueKey<String>('catalog-product-visibility-$productId'),
    );
    await _pumpUntilVisible(tester, homeProductCard);
    await tester.tap(homeProductCard);
    await _pumpUntilVisible(tester, find.text('Model tier: high'));

    expect(
      find.byKey(ValueKey<String>('product-model-panel-$productId')),
      findsOneWidget,
    );
    expect(find.text('US-050 model viewer high'), findsOneWidget);
    expect(
      find.textContaining('/catalog/products/$productId/model'),
      findsOneWidget,
    );

    final swatch = find.byKey(
      ValueKey<String>('mesh-color-$meshId-$meshColor'),
    );
    await _scrollUntilVisible(tester, swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();

    final addToCart = find.byKey(
      const ValueKey<String>('add-selected-product-to-cart'),
    );
    await _scrollUntilVisible(tester, addToCart);
    await tester.tap(addToCart);
    await tester.pump(const Duration(seconds: 1));

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cart'));
    await tester.pump(const Duration(seconds: 1));
    await _pumpUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('cart-summary')),
    );
    expect(find.text(productName), findsOneWidget);
    expect(find.textContaining('Subtotal'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('cart-color-$productId-$meshId-$meshColor')),
      findsOneWidget,
    );
  });
}

Widget _smokeModelViewer(BuildContext context, CatalogProductDetail detail) {
  return Semantics(
    label: 'US-050 live model viewer for ${detail.name}',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'US-050 model viewer ${detail.modelTier.wireName}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = tester.binding.clock.fromNowBy(timeout);
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    return;
  }
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.descendant(
      of: find.byKey(const PageStorageKey<String>('product-detail-scroll')),
      matching: find.byType(Scrollable),
    ),
    maxScrolls: 20,
  );
  await tester.pumpAndSettle();
}
