import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_catalog_products.dart';

enum CatalogStatus { initial, loading, ready, empty, failure }

class CatalogState {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.products = const [],
    this.total = 0,
    this.message,
  });

  final CatalogStatus status;
  final List<CatalogProduct> products;
  final int total;
  final String? message;

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogProduct>? products,
    int? total,
    String? message,
  }) {
    return CatalogState(
      status: status ?? this.status,
      products: products ?? this.products,
      total: total ?? this.total,
      message: message,
    );
  }
}

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._loadCatalogProducts) : super(const CatalogState());

  final LoadCatalogProducts _loadCatalogProducts;

  Future<void> loadProducts() async {
    emit(state.copyWith(status: CatalogStatus.loading, message: null));

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
}
