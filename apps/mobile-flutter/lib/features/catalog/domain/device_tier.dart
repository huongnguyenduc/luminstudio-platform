import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';

abstract interface class DeviceTierResolver {
  ProductModelTier resolve();
}

class FixedDeviceTierResolver implements DeviceTierResolver {
  const FixedDeviceTierResolver(this._tier);

  final ProductModelTier _tier;

  @override
  ProductModelTier resolve() => _tier;
}

class DefaultDeviceTierResolver implements DeviceTierResolver {
  const DefaultDeviceTierResolver();

  static const double _highTierShortestSide = 1080;

  @override
  ProductModelTier resolve() {
    if (kIsWeb) {
      return ProductModelTier.low;
    }

    final platform = Platform.operatingSystem;
    final display = PlatformDispatcher.instance.views.isEmpty
        ? null
        : PlatformDispatcher.instance.views.first.display;
    final shortestSide = display == null
        ? 0
        : display.size.shortestSide / display.devicePixelRatio;

    if ((platform == 'ios' || platform == 'macos') &&
        shortestSide >= _highTierShortestSide) {
      return ProductModelTier.high;
    }

    return ProductModelTier.low;
  }
}
