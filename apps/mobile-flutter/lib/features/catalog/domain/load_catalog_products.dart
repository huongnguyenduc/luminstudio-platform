import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';

class LoadCatalogProducts {
  const LoadCatalogProducts(this._repository);

  final CatalogRepository _repository;

  Future<CatalogProductsPage> call({int limit = 20, int offset = 0}) {
    return _repository.listProducts(limit: limit, offset: offset);
  }
}
