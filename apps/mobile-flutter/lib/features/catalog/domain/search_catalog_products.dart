import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';

class SearchCatalogProducts {
  const SearchCatalogProducts(this._repository);

  final CatalogRepository _repository;

  Future<CatalogProductsPage> call(
    String query, {
    int limit = 20,
    int offset = 0,
  }) {
    return _repository.searchProducts(query, limit: limit, offset: offset);
  }
}
