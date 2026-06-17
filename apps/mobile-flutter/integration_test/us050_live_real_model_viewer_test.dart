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

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('US-050 opens and gestures the real live model viewer', (
    tester,
  ) async {
    expect(apiBaseUrl, isNotEmpty);
    expect(productId, isNotEmpty);
    expect(productName, isNotEmpty);

    await tester.pumpWidget(
      const LuminStudioApp(
        deviceTierResolver: FixedDeviceTierResolver(ProductModelTier.high),
      ),
    );

    await _pumpUntilVisible(tester, find.byType(SearchBar));
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

    final modelViewer = find.byKey(ValueKey<String>('model-viewer-$productId'));
    await _scrollUntilVisible(tester, modelViewer);
    expect(modelViewer, findsOneWidget);

    final center = tester.getCenter(modelViewer);
    await tester.dragFrom(center, const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 300));

    final firstPointer = await tester.startGesture(
      center + const Offset(-24, 0),
    );
    final secondPointer = await tester.startGesture(
      center + const Offset(24, 0),
    );
    await firstPointer.moveBy(const Offset(-28, 0));
    await secondPointer.moveBy(const Offset(28, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await firstPointer.up();
    await secondPointer.up();
    await tester.pumpAndSettle();
  });
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
}
