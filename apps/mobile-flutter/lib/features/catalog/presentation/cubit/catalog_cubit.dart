import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_catalog_products.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/search_catalog_products.dart';

enum CatalogStatus { initial, loading, ready, empty, failure }

const defaultCatalogPageLimit = 20;

class CatalogState {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.products = const [],
    this.total = 0,
    this.query = '',
    this.pageLimit = defaultCatalogPageLimit,
    this.isLoadingMore = false,
    this.message,
    this.loadMoreMessage,
  });

  final CatalogStatus status;
  final List<CatalogProduct> products;
  final int total;
  final String query;
  final int pageLimit;
  final bool isLoadingMore;
  final String? message;
  final String? loadMoreMessage;

  bool get isSearching => query.isNotEmpty;
  bool get canLoadMore => products.length < total;
  int get nextOffset => products.length;

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogProduct>? products,
    int? total,
    String? query,
    int? pageLimit,
    bool? isLoadingMore,
    String? message,
    String? loadMoreMessage,
  }) {
    return CatalogState(
      status: status ?? this.status,
      products: products ?? this.products,
      total: total ?? this.total,
      query: query ?? this.query,
      pageLimit: pageLimit ?? this.pageLimit,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      message: message,
      loadMoreMessage: loadMoreMessage,
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
      final page = await _loadCatalogProducts(limit: defaultCatalogPageLimit);
      emit(
        CatalogState(
          status: page.items.isEmpty
              ? CatalogStatus.empty
              : CatalogStatus.ready,
          products: page.items,
          total: page.total,
          pageLimit: page.limit,
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
      final page = await _searchCatalogProducts(
        query,
        limit: defaultCatalogPageLimit,
      );
      emit(
        CatalogState(
          status: page.items.isEmpty
              ? CatalogStatus.empty
              : CatalogStatus.ready,
          products: page.items,
          total: page.total,
          query: query,
          pageLimit: page.limit,
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

  Future<void> loadMoreProducts() async {
    if (state.status != CatalogStatus.ready ||
        state.isLoadingMore ||
        !state.canLoadMore) {
      return;
    }

    final offset = state.nextOffset;
    final query = state.query;
    emit(
      state.copyWith(isLoadingMore: true, loadMoreMessage: null, message: null),
    );

    try {
      final page = query.isEmpty
          ? await _loadCatalogProducts(limit: state.pageLimit, offset: offset)
          : await _searchCatalogProducts(
              query,
              limit: state.pageLimit,
              offset: offset,
            );
      if (state.query != query ||
          state.nextOffset != offset ||
          state.status != CatalogStatus.ready) {
        return;
      }
      emit(
        state.copyWith(
          products: [...state.products, ...page.items],
          total: page.total,
          pageLimit: page.limit,
          isLoadingMore: false,
          message: null,
          loadMoreMessage: null,
        ),
      );
    } catch (_) {
      if (state.query != query ||
          state.nextOffset != offset ||
          state.status != CatalogStatus.ready) {
        return;
      }
      emit(
        state.copyWith(
          isLoadingMore: false,
          message: null,
          loadMoreMessage: query.isEmpty
              ? 'More catalog products are unavailable'
              : 'More search results are unavailable',
        ),
      );
    }
  }
}
