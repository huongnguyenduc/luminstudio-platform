import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumin_studio_mobile/app/app.dart';
import 'package:lumin_studio_mobile/features/cart/data/cart_api_client.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const apiBaseUrl = String.fromEnvironment('LUMIN_API_BASE_URL');
  const productId = String.fromEnvironment('LUMIN_US053_PRODUCT_ID');
  const productName = String.fromEnvironment('LUMIN_US053_PRODUCT_NAME');
  const meshId = String.fromEnvironment('LUMIN_US053_MESH_ID');
  const meshColor = String.fromEnvironment('LUMIN_US053_MESH_COLOR');
  const cartIdKey = 'lumin.cart.id.v1';
  const cartSnapshotKey = 'lumin.cart.v1';

  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await SharedPreferencesAsync().clear(
      allowList: <String>{cartIdKey, cartSnapshotKey},
    );
  });

  testWidgets('US-053 syncs Flutter cart with live backend cart snapshot', (
    tester,
  ) async {
    expect(apiBaseUrl, isNotEmpty);
    expect(productId, isNotEmpty);
    expect(productName, isNotEmpty);
    expect(meshId, isNotEmpty);
    expect(meshColor, isNotEmpty);

    final preferences = SharedPreferencesAsync();
    final cartClient = CartApiClient(baseUri: Uri.parse(apiBaseUrl));

    await tester.pumpWidget(const _LiveCartApp());

    await tester.enterText(find.byType(SearchBar), productName);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpUntilVisible(tester, find.text(productName));

    final productCard = find.byKey(
      ValueKey<String>('catalog-product-visibility-$productId'),
    );
    await _pumpUntilVisible(tester, productCard);
    await tester.tap(productCard);
    await _pumpUntilVisible(
      tester,
      find.byKey(ValueKey<String>('product-model-panel-$productId')),
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

    final cartId = await _waitForSavedCartId(preferences, cartIdKey);
    final createdCart = await _waitForServerQuantity(
      cartClient,
      cartId,
      productId,
      1,
    );
    final createdItem = createdCart.items.single;
    expect(createdItem.productId, productId);
    expect(createdItem.productName, productName);
    expect(createdItem.selectedColors[meshId], meshColor);
    expect(createdItem.selected, isTrue);
    expect(createdCart.totals.selectedQuantity, 1);
    expect(createdCart.totals.selectedAmountCents, greaterThan(0));

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cart'));
    await _pumpUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('cart-summary')),
    );

    await tester.tap(find.byTooltip('Increase $productId quantity'));
    final updatedCart = await _waitForServerQuantity(
      cartClient,
      cartId,
      productId,
      2,
    );
    expect(updatedCart.totals.selectedQuantity, 2);

    final serverHydratedItem = updatedCart.toDomainItems().single.copyWith(
      quantity: 3,
    );
    await cartClient.updateCart(cartId, [serverHydratedItem]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const _LiveCartApp());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cart'));
    await _pumpUntilVisible(
      tester,
      find.byKey(ValueKey<String>('cart-qty-$productId')),
    );
    await _pumpUntilText(tester, '3');
  });
}

class _LiveCartApp extends StatelessWidget {
  const _LiveCartApp();

  @override
  Widget build(BuildContext context) {
    return LuminStudioApp(
      deviceTierResolver: const FixedDeviceTierResolver(ProductModelTier.high),
      productModelViewerBuilder: _smokeModelViewer,
    );
  }
}

Widget _smokeModelViewer(BuildContext context, CatalogProductDetail detail) {
  return Semantics(
    label: 'US-053 live model viewer for ${detail.name}',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'US-053 model viewer ${detail.modelTier.wireName}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

Future<String> _waitForSavedCartId(
  SharedPreferencesAsync preferences,
  String key, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final cartId = await preferences.getString(key);
    if (cartId != null && cartId.isNotEmpty) {
      return cartId;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for saved backend cart id');
}

Future<CartRecordDto> _waitForServerQuantity(
  CartApiClient client,
  String cartId,
  String productId,
  int quantity, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  CartRecordDto? lastRecord;
  while (DateTime.now().isBefore(end)) {
    lastRecord = await client.getCart(cartId);
    final matches = lastRecord.items.where(
      (item) => item.productId == productId && item.quantity == quantity,
    );
    if (matches.isNotEmpty) {
      return lastRecord;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure(
    'Timed out waiting for server quantity $quantity in ${lastRecord?.id}',
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

Future<void> _pumpUntilText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final finder = find.text(text);
  final end = tester.binding.clock.fromNowBy(timeout);
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for text $text');
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.descendant(
    of: find.byKey(const PageStorageKey<String>('product-detail-scroll')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: scrollable,
    maxScrolls: 20,
  );
  await tester.pumpAndSettle();

  final safeBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio - 180;
  for (var attempt = 0; attempt < 8; attempt += 1) {
    final center = tester.getCenter(finder);
    if (center.dy < safeBottom) {
      return;
    }
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
  }
}
