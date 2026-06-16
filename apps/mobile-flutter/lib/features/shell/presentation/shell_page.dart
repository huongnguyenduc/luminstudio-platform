import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';

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
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: 'Category',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Cart',
              ),
            ],
          ),
        );
      },
    );
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
        actions: [
          IconButton(
            tooltip: '${tab.label} detail',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _TabDetailPage(tab: tab),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: _TabList(tab: tab),
    );
  }
}

class _TabList extends StatelessWidget {
  const _TabList({required this.tab});

  final CustomerTab tab;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${tab.label} tab content',
      child: ListView.separated(
        key: PageStorageKey<String>('${tab.name}-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _EmptyState(tab: tab);
          }

          return _ShellPlaceholderRow(tab: tab, index: index);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: 18,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});

  final CustomerTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (tab) {
      CustomerTab.home => 'No featured products yet',
      CustomerTab.category => 'No categories yet',
      CustomerTab.cart => 'Cart is empty',
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 168),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
  }
}

class _ShellPlaceholderRow extends StatelessWidget {
  const _ShellPlaceholderRow({required this.tab, required this.index});

  final CustomerTab tab;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(_iconFor(tab), color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${tab.label} slot $index',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(CustomerTab tab) {
    return switch (tab) {
      CustomerTab.home => Icons.view_in_ar_outlined,
      CustomerTab.category => Icons.grid_view_outlined,
      CustomerTab.cart => Icons.receipt_long_outlined,
    };
  }
}

class _TabDetailPage extends StatelessWidget {
  const _TabDetailPage({required this.tab});

  final CustomerTab tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${tab.label} detail')),
      body: Center(
        child: Text(
          '${tab.label} state retained',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
