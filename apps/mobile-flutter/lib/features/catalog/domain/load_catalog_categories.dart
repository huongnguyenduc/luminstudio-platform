import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';

class LoadCatalogCategories {
  const LoadCatalogCategories(this._repository);

  final CatalogRepository _repository;

  Future<List<CatalogCategory>> call() {
    return _repository.listCategories();
  }
}
