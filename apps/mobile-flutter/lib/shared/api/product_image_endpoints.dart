/// Builds catalog product image URLs from the configured API base.
///
/// Some surfaces (the cart) only know a product id and need to show the
/// product's description image without first fetching its markdown. This
/// resolver mirrors the backend route `GET /catalog/products/{id}/image`; the
/// image widget falls back gracefully when a product ships no image.
class ProductImageEndpoints {
  const ProductImageEndpoints(this.baseUri);

  final Uri baseUri;

  Uri descriptionImage(String productId) =>
      _productPath(productId, 'image');

  /// Mirrors `GET /catalog/products/{id}/sprite` (the 360° sprite sheet). Every
  /// processed product ships a sprite even when it has no description image, so
  /// the cart uses its first frame as a graceful image fallback.
  Uri sprite(String productId) => _productPath(productId, 'sprite');

  Uri _productPath(String productId, String segment) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(
      path:
          '$basePath/catalog/products/${Uri.encodeComponent(productId)}/$segment',
      queryParameters: null,
    );
  }
}
