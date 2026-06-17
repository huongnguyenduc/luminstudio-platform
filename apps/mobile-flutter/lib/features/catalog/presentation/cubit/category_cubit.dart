import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_catalog_categories.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_category_products.dart';

enum CategoryStatus { initial, loading, ready, empty, failure }

enum CategoryProductsStatus { idle, loading, ready, empty, failure }

const defaultCategoryPageLimit = 20;

class CategoryState {
  const CategoryState({
    this.status = CategoryStatus.initial,
    this.productsStatus = CategoryProductsStatus.idle,
    this.categories = const [],
    this.products = const [],
    this.total = 0,
    this.sort = CategoryProductSort.newest,
    this.pageLimit = defaultCategoryPageLimit,
    this.isLoadingMore = false,
    this.selectedCategory,
    this.message,
    this.productsMessage,
    this.loadMoreMessage,
  });

  final CategoryStatus status;
  final CategoryProductsStatus productsStatus;
  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;
  final int total;
  final CategoryProductSort sort;
  final int pageLimit;
  final bool isLoadingMore;
  final CatalogCategory? selectedCategory;
  final String? message;
  final String? productsMessage;
  final String? loadMoreMessage;

  bool get canLoadMore => products.length < total;
  int get nextOffset => products.length;

  CategoryState copyWith({
    CategoryStatus? status,
    CategoryProductsStatus? productsStatus,
    List<CatalogCategory>? categories,
    List<CatalogProduct>? products,
    int? total,
    CategoryProductSort? sort,
    int? pageLimit,
    bool? isLoadingMore,
    CatalogCategory? selectedCategory,
    bool clearSelectedCategory = false,
    String? message,
    String? productsMessage,
    String? loadMoreMessage,
  }) {
    return CategoryState(
      status: status ?? this.status,
      productsStatus: productsStatus ?? this.productsStatus,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      total: total ?? this.total,
      sort: sort ?? this.sort,
      pageLimit: pageLimit ?? this.pageLimit,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedCategory: clearSelectedCategory
          ? null
          : selectedCategory ?? this.selectedCategory,
      message: message,
      productsMessage: productsMessage,
      loadMoreMessage: loadMoreMessage,
    );
  }
}

class CategoryCubit extends Cubit<CategoryState> {
  CategoryCubit(this._loadCatalogCategories, this._loadCategoryProducts)
    : super(const CategoryState());

  final LoadCatalogCategories _loadCatalogCategories;
  final LoadCategoryProducts _loadCategoryProducts;

  Future<void> loadCategories() async {
    emit(
      const CategoryState(
        status: CategoryStatus.loading,
        productsStatus: CategoryProductsStatus.idle,
      ),
    );

    try {
      final categories = await _loadCatalogCategories();
      if (categories.isEmpty) {
        emit(const CategoryState(status: CategoryStatus.empty));
        return;
      }

      final selected = categories.first;
      emit(
        CategoryState(
          status: CategoryStatus.ready,
          productsStatus: CategoryProductsStatus.loading,
          categories: categories,
          selectedCategory: selected,
        ),
      );
      await _loadProducts(selected.slug, CategoryProductSort.newest);
    } catch (_) {
      emit(
        const CategoryState(
          status: CategoryStatus.failure,
          message: 'Categories are unavailable',
        ),
      );
    }
  }

  Future<void> selectCategory(CatalogCategory category) async {
    if (state.selectedCategory?.slug == category.slug &&
        state.productsStatus != CategoryProductsStatus.failure) {
      return;
    }

    emit(
      state.copyWith(
        status: CategoryStatus.ready,
        productsStatus: CategoryProductsStatus.loading,
        selectedCategory: category,
        products: const [],
        total: 0,
        isLoadingMore: false,
        productsMessage: null,
        loadMoreMessage: null,
      ),
    );
    await _loadProducts(category.slug, state.sort);
  }

  Future<void> changeSort(CategoryProductSort sort) async {
    final selected = state.selectedCategory;
    if (selected == null) {
      return;
    }
    if (state.sort == sort &&
        state.productsStatus != CategoryProductsStatus.failure) {
      return;
    }

    emit(
      state.copyWith(
        productsStatus: CategoryProductsStatus.loading,
        sort: sort,
        products: const [],
        total: 0,
        isLoadingMore: false,
        productsMessage: null,
        loadMoreMessage: null,
      ),
    );
    await _loadProducts(selected.slug, sort);
  }

  Future<void> retryProducts() async {
    final selected = state.selectedCategory;
    if (selected == null) {
      await loadCategories();
      return;
    }
    emit(
      state.copyWith(
        productsStatus: CategoryProductsStatus.loading,
        productsMessage: null,
        loadMoreMessage: null,
      ),
    );
    await _loadProducts(selected.slug, state.sort);
  }

  Future<void> loadMoreProducts() async {
    final selected = state.selectedCategory;
    if (selected == null ||
        state.productsStatus != CategoryProductsStatus.ready ||
        state.isLoadingMore ||
        !state.canLoadMore) {
      return;
    }

    final categorySlug = selected.slug;
    final sort = state.sort;
    final offset = state.nextOffset;
    emit(
      state.copyWith(
        isLoadingMore: true,
        productsMessage: null,
        loadMoreMessage: null,
      ),
    );

    try {
      final page = await _loadCategoryProducts(
        categorySlug,
        sort: sort,
        limit: state.pageLimit,
        offset: offset,
      );
      if (state.selectedCategory?.slug != categorySlug ||
          state.sort != sort ||
          state.nextOffset != offset ||
          state.productsStatus != CategoryProductsStatus.ready) {
        return;
      }
      emit(
        state.copyWith(
          products: [...state.products, ...page.items],
          total: page.total,
          pageLimit: page.limit,
          isLoadingMore: false,
          productsMessage: null,
          loadMoreMessage: null,
        ),
      );
    } catch (_) {
      if (state.selectedCategory?.slug != categorySlug ||
          state.sort != sort ||
          state.nextOffset != offset ||
          state.productsStatus != CategoryProductsStatus.ready) {
        return;
      }
      emit(
        state.copyWith(
          isLoadingMore: false,
          productsMessage: null,
          loadMoreMessage: 'More category products are unavailable',
        ),
      );
    }
  }

  Future<void> _loadProducts(
    String categorySlug,
    CategoryProductSort sort,
  ) async {
    try {
      final page = await _loadCategoryProducts(
        categorySlug,
        sort: sort,
        limit: defaultCategoryPageLimit,
      );
      if (state.selectedCategory?.slug != categorySlug || state.sort != sort) {
        return;
      }
      emit(
        state.copyWith(
          productsStatus: page.items.isEmpty
              ? CategoryProductsStatus.empty
              : CategoryProductsStatus.ready,
          products: page.items,
          total: page.total,
          pageLimit: page.limit,
          isLoadingMore: false,
          productsMessage: null,
          loadMoreMessage: null,
        ),
      );
    } catch (_) {
      if (state.selectedCategory?.slug != categorySlug || state.sort != sort) {
        return;
      }
      emit(
        state.copyWith(
          productsStatus: CategoryProductsStatus.failure,
          products: const [],
          total: 0,
          isLoadingMore: false,
          productsMessage: 'Category products are unavailable',
          loadMoreMessage: null,
        ),
      );
    }
  }
}
