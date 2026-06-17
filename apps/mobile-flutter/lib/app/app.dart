import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

const _studioInk = Color(0xFF121916);
const _studioJade = Color(0xFF087463);
const _studioMist = Color(0xFFF4F7F2);
const _studioSurface = Color(0xFFFEFFFC);
const _studioBrass = Color(0xFFB9853A);

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
        RepositoryProvider<DeviceTierResolver>.value(value: deviceTierResolver),
        RepositoryProvider<ProductModelViewerBuilder>.value(
          value: productModelViewerBuilder,
        ),
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
      child: MaterialApp(
        title: 'Lumin Studio',
        debugShowCheckedModeBanner: false,
        theme: _luminTheme(),
        home: const CustomerShellPage(),
      ),
    );
  }

  ThemeData _luminTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _studioJade,
      brightness: Brightness.light,
      surface: _studioSurface,
      primary: _studioJade,
      secondary: _studioBrass,
      onSurface: _studioInk,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _studioMist,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _studioMist,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: const TextStyle(
          color: _studioInk,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: _studioInk,
        displayColor: _studioInk,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _studioSurface,
        indicatorColor: const Color(0xFFD8EFE8),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? _studioInk
                : const Color(0xFF59645F),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0,
          );
        }),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll<double>(0),
        backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surface),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: colorScheme.outlineVariant),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: const Color(0xFFD8EFE8),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(
          color: _studioInk,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
