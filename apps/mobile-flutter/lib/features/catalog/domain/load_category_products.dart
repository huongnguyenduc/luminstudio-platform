import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';

class LoadCategoryProducts {
  const LoadCategoryProducts(this._repository);

  final CatalogRepository _repository;

  Future<CatalogProductsPage> call(
    String categorySlug, {
    CategoryProductSort sort = CategoryProductSort.newest,
    int limit = 20,
    int offset = 0,
  }) {
    return _repository.listCategoryProducts(
      categorySlug,
      sort: sort,
      limit: limit,
      offset: offset,
    );
  }
}
