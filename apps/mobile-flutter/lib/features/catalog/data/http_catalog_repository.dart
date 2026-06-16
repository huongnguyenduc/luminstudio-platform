import 'package:lumin_studio_mobile/features/catalog/data/catalog_api_client.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';

class HttpCatalogRepository implements CatalogRepository {
  const HttpCatalogRepository(this._client);

  final CatalogApiClient _client;

  @override
  Future<CatalogProductsPage> listProducts({int limit = 20, int offset = 0}) {
    return _client.listProducts(limit: limit, offset: offset);
  }
}
