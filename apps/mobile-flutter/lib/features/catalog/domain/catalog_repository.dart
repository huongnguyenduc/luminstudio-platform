import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';

abstract interface class CatalogRepository {
  Future<CatalogProductsPage> listProducts({int limit = 20, int offset = 0});

  Future<CatalogProductsPage> searchProducts(
    String query, {
    int limit = 20,
    int offset = 0,
  });
}
