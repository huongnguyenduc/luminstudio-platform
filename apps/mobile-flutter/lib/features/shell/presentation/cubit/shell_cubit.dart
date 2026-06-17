import 'package:flutter_bloc/flutter_bloc.dart';

enum CustomerTab {
  home(label: 'Home'),
  category(label: 'Category'),
  cart(label: 'Cart');

  const CustomerTab({required this.label});

  final String label;
}

class ShellState {
  const ShellState({this.selectedTab = CustomerTab.home});

  final CustomerTab selectedTab;

  ShellState copyWith({CustomerTab? selectedTab}) {
    return ShellState(selectedTab: selectedTab ?? this.selectedTab);
  }
}

class ShellCubit extends Cubit<ShellState> {
  ShellCubit() : super(const ShellState());

  void selectTab(CustomerTab tab) {
    if (tab == state.selectedTab) {
      return;
    }

    emit(state.copyWith(selectedTab: tab));
  }
}
