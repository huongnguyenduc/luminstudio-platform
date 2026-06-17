import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/app/theme/app_theme.dart';
import 'package:lumin_studio_mobile/app/theme/theme_mode_cubit.dart';
import 'package:lumin_studio_mobile/features/cart/data/api_backed_cart_repository.dart';
import 'package:lumin_studio_mobile/features/cart/data/cart_api_client.dart';
import 'package:lumin_studio_mobile/features/cart/data/shared_preferences_cart_repository.dart';
import 'package:lumin_studio_mobile/features/cart/domain/cart_repository.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/data/catalog_api_client.dart';
import 'package:lumin_studio_mobile/features/catalog/data/http_catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_catalog_categories.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_catalog_products.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_category_products.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/search_catalog_products.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/category_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_model_viewer.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/shell_page.dart';
import 'package:lumin_studio_mobile/shared/api/product_image_endpoints.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LuminStudioApp extends StatelessWidget {
  const LuminStudioApp({
    super.key,
    this.catalogRepository,
    this.cartRepository,
    this.deviceTierResolver = const DefaultDeviceTierResolver(),
    this.productModelViewerBuilder = defaultProductModelViewerBuilder,
  });

  final CatalogRepository? catalogRepository;
  final CartRepository? cartRepository;
  final DeviceTierResolver deviceTierResolver;
  final ProductModelViewerBuilder productModelViewerBuilder;

  @override
  Widget build(BuildContext context) {
    final apiBaseUri = Uri.parse(
      const String.fromEnvironment(
        'LUMIN_API_BASE_URL',
        defaultValue: 'http://localhost:8080',
      ),
    );
    final catalog =
        catalogRepository ??
        HttpCatalogRepository(CatalogApiClient(baseUri: apiBaseUri));
    final cart = cartRepository ?? _defaultCartRepository(apiBaseUri);

    return MultiBlocProvider(
      providers: [
        RepositoryProvider<CatalogRepository>.value(value: catalog),
        RepositoryProvider<CartRepository>.value(value: cart),
        RepositoryProvider<ProductImageEndpoints>.value(
          value: ProductImageEndpoints(apiBaseUri),
        ),
        RepositoryProvider<DeviceTierResolver>.value(value: deviceTierResolver),
        RepositoryProvider<ProductModelViewerBuilder>.value(
          value: productModelViewerBuilder,
        ),
        BlocProvider(create: (_) => ThemeModeCubit()),
        BlocProvider(create: (_) => ShellCubit()),
        BlocProvider(create: (_) => CartCubit(cart)..load()),
        BlocProvider(
          create: (_) => CatalogCubit(
            LoadCatalogProducts(catalog),
            SearchCatalogProducts(catalog),
          )..loadProducts(),
        ),
        BlocProvider(
          create: (_) => CategoryCubit(
            LoadCatalogCategories(catalog),
            LoadCategoryProducts(catalog),
          )..loadCategories(),
        ),
      ],
      child: BlocBuilder<ThemeModeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'Lumin Studio',
            debugShowCheckedModeBanner: false,
            theme: buildLuminTheme(Brightness.light),
            darkTheme: buildLuminTheme(Brightness.dark),
            themeMode: themeMode,
            home: const CustomerShellPage(),
          );
        },
      ),
    );
  }

  CartRepository _defaultCartRepository(Uri apiBaseUri) {
    final localCart = SharedPreferencesCartRepository(SharedPreferencesAsync());
    return ApiBackedCartRepository(
      client: CartApiClient(baseUri: apiBaseUri),
      localRepository: localCart,
      cartIdStore: localCart,
    );
  }
}
