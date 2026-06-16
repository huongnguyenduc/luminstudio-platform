import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/get_catalog_product_detail.dart';

enum ProductDetailStatus { initial, loading, ready, failure }

class ProductDetailState {
  const ProductDetailState({
    required this.productId,
    required this.tier,
    this.status = ProductDetailStatus.initial,
    this.detail,
    this.message,
  });

  final String productId;
  final ProductModelTier tier;
  final ProductDetailStatus status;
  final CatalogProductDetail? detail;
  final String? message;

  ProductDetailState copyWith({
    ProductDetailStatus? status,
    CatalogProductDetail? detail,
    String? message,
  }) {
    return ProductDetailState(
      productId: productId,
      tier: tier,
      status: status ?? this.status,
      detail: detail ?? this.detail,
      message: message,
    );
  }
}

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit({
    required String productId,
    required GetCatalogProductDetail getCatalogProductDetail,
    required DeviceTierResolver deviceTierResolver,
  }) : _getCatalogProductDetail = getCatalogProductDetail,
       super(
         ProductDetailState(
           productId: productId,
           tier: deviceTierResolver.resolve(),
         ),
       );

  final GetCatalogProductDetail _getCatalogProductDetail;

  Future<void> load() async {
    emit(state.copyWith(status: ProductDetailStatus.loading, message: null));

    try {
      final detail = await _getCatalogProductDetail(
        state.productId,
        tier: state.tier,
      );
      emit(
        state.copyWith(
          status: ProductDetailStatus.ready,
          detail: detail,
          message: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ProductDetailStatus.failure,
          message: 'Product detail is unavailable',
        ),
      );
    }
  }
}
