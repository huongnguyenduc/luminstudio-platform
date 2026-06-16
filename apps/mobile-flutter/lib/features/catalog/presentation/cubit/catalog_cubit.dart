import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_catalog_products.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/search_catalog_products.dart';

enum CatalogStatus { initial, loading, ready, empty, failure }

class CatalogState {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.products = const [],
    this.total = 0,
    this.query = '',
    this.message,
  });

  final CatalogStatus status;
  final List<CatalogProduct> products;
  final int total;
  final String query;
  final String? message;

  bool get isSearching => query.isNotEmpty;

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogProduct>? products,
    int? total,
    String? query,
    String? message,
  }) {
    return CatalogState(
      status: status ?? this.status,
      products: products ?? this.products,
      total: total ?? this.total,
      query: query ?? this.query,
      message: message,
    );
  }
}

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._loadCatalogProducts, this._searchCatalogProducts)
    : super(const CatalogState());

  final LoadCatalogProducts _loadCatalogProducts;
  final SearchCatalogProducts _searchCatalogProducts;

  Future<void> loadProducts() async {
    emit(
      state.copyWith(status: CatalogStatus.loading, query: '', message: null),
    );

    try {
      final page = await _loadCatalogProducts();
      emit(
        CatalogState(
          status: page.items.isEmpty
              ? CatalogStatus.empty
              : CatalogStatus.ready,
          products: page.items,
          total: page.total,
        ),
      );
    } catch (_) {
      emit(
        const CatalogState(
          status: CatalogStatus.failure,
          message: 'Catalog is unavailable',
        ),
      );
    }
  }

  Future<void> searchProducts(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      await loadProducts();
      return;
    }

    emit(
      state.copyWith(
        status: CatalogStatus.loading,
        query: query,
        message: null,
      ),
    );

    try {
      final page = await _searchCatalogProducts(query);
      emit(
        CatalogState(
          status: page.items.isEmpty
              ? CatalogStatus.empty
              : CatalogStatus.ready,
          products: page.items,
          total: page.total,
          query: query,
        ),
      );
    } catch (_) {
      emit(
        CatalogState(
          status: CatalogStatus.failure,
          query: query,
          message: 'Search is unavailable',
        ),
      );
    }
  }

  Future<void> clearSearch() async {
    await loadProducts();
  }
}
