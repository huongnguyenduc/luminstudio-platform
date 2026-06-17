import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/app/theme/theme_mode_cubit.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cart_view.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/category_products_view.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/catalog_products_view.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:lumin_studio_mobile/shared/widgets/cart_badge_icon.dart';

class CustomerShellPage extends StatefulWidget {
  const CustomerShellPage({super.key});

  @override
  State<CustomerShellPage> createState() => _CustomerShellPageState();
}

class _CustomerShellPageState extends State<CustomerShellPage> {
  late final Map<CustomerTab, GlobalKey<NavigatorState>> _navigatorKeys;

  @override
  void initState() {
    super.initState();
    _navigatorKeys = {
      for (final tab in CustomerTab.values) tab: GlobalKey<NavigatorState>(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShellCubit, ShellState>(
      builder: (context, state) {
        final selectedIndex = CustomerTab.values.indexOf(state.selectedTab);

        return Scaffold(
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: selectedIndex,
              children: [
                for (final tab in CustomerTab.values)
                  _TabNavigator(
                    key: PageStorageKey<String>('${tab.name}-navigator'),
                    navigatorKey: _navigatorKeys[tab]!,
                    tab: tab,
                  ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              context.read<ShellCubit>().selectTab(CustomerTab.values[index]);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Category',
              ),
              const NavigationDestination(
                icon: _CartNavIcon(icon: Icons.shopping_bag_outlined),
                selectedIcon: _CartNavIcon(icon: Icons.shopping_bag),
                label: 'Cart',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cart bottom-nav icon that subscribes to the cart count itself, so quantity
/// changes only rebuild the badge — not the whole shell (which would otherwise
/// rebuild the active tab and replay list entrance animations).
class _CartNavIcon extends StatelessWidget {
  const _CartNavIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartCubit, int>(
      (cubit) => cubit.state.totalQuantity,
    );
    return CartBadgeIcon(icon: icon, count: count);
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navigatorKey,
    required this.tab,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final CustomerTab tab;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _TabRootPage(tab: tab),
        );
      },
    );
  }
}

class _TabRootPage extends StatelessWidget {
  const _TabRootPage({required this.tab});

  final CustomerTab tab;

  @override
  Widget build(BuildContext context) {
    final title = switch (tab) {
      CustomerTab.home => 'Lumin Studio',
      CustomerTab.category => 'Category',
      CustomerTab.cart => 'Cart',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [_ThemeToggleButton()],
      ),
      body: _TabList(tab: tab),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () {
        context.read<ThemeModeCubit>().toggle(Theme.of(context).brightness);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.6, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey<bool>(isDark),
        ),
      ),
    );
  }
}

class _TabList extends StatelessWidget {
  const _TabList({required this.tab});

  final CustomerTab tab;

  @override
  Widget build(BuildContext context) {
    if (tab == CustomerTab.home) {
      return const CatalogProductsView(
        scrollKey: PageStorageKey<String>('home-scroll'),
      );
    }

    if (tab == CustomerTab.cart) {
      return const CartView();
    }

    return const CategoryProductsView(
      scrollKey: PageStorageKey<String>('category-scroll'),
    );
  }
}
