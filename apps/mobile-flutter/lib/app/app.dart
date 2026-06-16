import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/catalog/data/catalog_api_client.dart';
import 'package:lumin_studio_mobile/features/catalog/data/http_catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/device_tier.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/load_catalog_products.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/search_catalog_products.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/shell_page.dart';

class LuminStudioApp extends StatelessWidget {
  const LuminStudioApp({
    super.key,
    this.catalogRepository,
    this.deviceTierResolver = const DefaultDeviceTierResolver(),
  });

  final CatalogRepository? catalogRepository;
  final DeviceTierResolver deviceTierResolver;

  @override
  Widget build(BuildContext context) {
    final repository =
        catalogRepository ??
        HttpCatalogRepository(
          CatalogApiClient(
            baseUri: Uri.parse(
              const String.fromEnvironment(
                'LUMIN_API_BASE_URL',
                defaultValue: 'http://localhost:8080',
              ),
            ),
          ),
        );

    return MultiBlocProvider(
      providers: [
        RepositoryProvider<CatalogRepository>.value(value: repository),
        RepositoryProvider<DeviceTierResolver>.value(value: deviceTierResolver),
        BlocProvider(create: (_) => ShellCubit()),
        BlocProvider(
          create: (_) => CatalogCubit(
            LoadCatalogProducts(repository),
            SearchCatalogProducts(repository),
          )..loadProducts(),
        ),
      ],
      child: MaterialApp(
        title: 'Lumin Studio',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF33665B),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const CustomerShellPage(),
      ),
    );
  }
}
