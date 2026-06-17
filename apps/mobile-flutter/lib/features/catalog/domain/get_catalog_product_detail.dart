import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';

class GetCatalogProductDetail {
  const GetCatalogProductDetail(this._repository);

  final CatalogRepository _repository;

  Future<CatalogProductDetail> call(
    String productId, {
    required ProductModelTier tier,
  }) {
    return _repository.getProductDetail(productId, tier: tier);
  }
}
